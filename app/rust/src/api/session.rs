use std::fmt;
use std::path::PathBuf;
use std::sync::LazyLock;

use matrix_sdk::authentication::matrix::MatrixSession;
use matrix_sdk::ruma::api::error::ErrorKind;
use matrix_sdk::store::RoomLoadSettings;
use matrix_sdk::{Client, ClientBuildError, SessionMeta, SessionTokens};
use tokio::sync::RwLock;

static CLIENT: LazyLock<RwLock<Option<Client>>> = LazyLock::new(|| RwLock::new(None));

#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("invalid homeserver")]
    InvalidHomeserver,
    #[error("network")]
    Network,
    #[error("invalid credentials")]
    InvalidCredentials,
    #[error("rate limited")]
    RateLimited,
    #[error("session expired")]
    SessionExpired,
    #[error("storage")]
    Storage,
    #[error("not logged in")]
    NotLoggedIn,
    #[error("unknown")]
    Unknown,
}

pub struct SessionData {
    pub homeserver_url: String,
    pub user_id: String,
    pub device_id: String,
    pub access_token: String,
    pub refresh_token: Option<String>,
}

impl fmt::Debug for SessionData {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("SessionData")
            .field("homeserver_url", &self.homeserver_url)
            .field("user_id", &self.user_id)
            .field("device_id", &self.device_id)
            .field("access_token", &"<redacted>")
            .field("refresh_token", &"<redacted>")
            .finish()
    }
}

async fn build_client(
    homeserver_url: &str,
    data_dir: &str,
    passphrase: &str,
) -> Result<Client, AuthError> {
    Client::builder()
        .homeserver_url(homeserver_url)
        .sqlite_store(PathBuf::from(data_dir), Some(passphrase))
        .build()
        .await
        .map_err(map_build_error)
}

fn map_build_error(error: ClientBuildError) -> AuthError {
    match error {
        ClientBuildError::InvalidServerName
        | ClientBuildError::Url(_)
        | ClientBuildError::AutoDiscovery(_) => AuthError::InvalidHomeserver,
        ClientBuildError::Http(_) => AuthError::Network,
        ClientBuildError::SqliteStore(_) => AuthError::Storage,
        _ => AuthError::Unknown,
    }
}

fn map_error_kind(kind: Option<&ErrorKind>) -> AuthError {
    match kind {
        Some(ErrorKind::Forbidden | ErrorKind::Unauthorized) => AuthError::InvalidCredentials,
        Some(ErrorKind::UnknownToken { .. }) => AuthError::SessionExpired,
        Some(ErrorKind::LimitExceeded { .. }) => AuthError::RateLimited,
        Some(_) => AuthError::Unknown,
        None => AuthError::Network,
    }
}

fn to_session_data(client: &Client, session: MatrixSession) -> SessionData {
    SessionData {
        homeserver_url: client.homeserver().to_string(),
        user_id: session.meta.user_id.to_string(),
        device_id: session.meta.device_id.to_string(),
        access_token: session.tokens.access_token,
        refresh_token: session.tokens.refresh_token,
    }
}

pub async fn login(
    homeserver_url: String,
    username: String,
    password: String,
    data_dir: String,
    passphrase: String,
) -> Result<SessionData, AuthError> {
    let client = build_client(&homeserver_url, &data_dir, &passphrase).await?;
    client
        .matrix_auth()
        .login_username(&username, &password)
        .initial_device_display_name("Insight Desktop")
        .send()
        .await
        .map_err(|e| map_error_kind(e.client_api_error_kind()))?;
    let session = client.matrix_auth().session().ok_or(AuthError::Unknown)?;
    let data = to_session_data(&client, session);
    *CLIENT.write().await = Some(client);
    Ok(data)
}

pub async fn restore_session(
    session: SessionData,
    data_dir: String,
    passphrase: String,
) -> Result<(), AuthError> {
    let client = build_client(&session.homeserver_url, &data_dir, &passphrase).await?;
    let matrix_session = MatrixSession {
        meta: SessionMeta {
            user_id: session
                .user_id
                .try_into()
                .map_err(|_| AuthError::SessionExpired)?,
            device_id: session.device_id.into(),
        },
        tokens: SessionTokens {
            access_token: session.access_token,
            refresh_token: session.refresh_token,
        },
    };
    client
        .matrix_auth()
        .restore_session(matrix_session, RoomLoadSettings::default())
        .await
        .map_err(|e| match e.client_api_error_kind() {
            Some(ErrorKind::UnknownToken { .. }) => AuthError::SessionExpired,
            None => AuthError::Network,
            Some(_) => AuthError::Unknown,
        })?;
    *CLIENT.write().await = Some(client);
    Ok(())
}

pub async fn logout() -> Result<(), AuthError> {
    let client = CLIENT.write().await.take().ok_or(AuthError::NotLoggedIn)?;
    client
        .matrix_auth()
        .logout()
        .await
        .map_err(|e| map_error_kind(e.client_api_error_kind()))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn debug_do_session_data_oculta_tokens() {
        let data = SessionData {
            homeserver_url: "https://matrix.example.org".into(),
            user_id: "@ana:example.org".into(),
            device_id: "DEVICE".into(),
            access_token: "segredo-access".into(),
            refresh_token: Some("segredo-refresh".into()),
        };
        let texto = format!("{data:?}");
        assert!(!texto.contains("segredo-access"));
        assert!(!texto.contains("segredo-refresh"));
        assert!(texto.contains("<redacted>"));
    }

    #[test]
    fn erro_de_credencial_vira_invalid_credentials() {
        assert!(matches!(
            map_error_kind(Some(&ErrorKind::Forbidden)),
            AuthError::InvalidCredentials
        ));
    }

    #[test]
    fn token_desconhecido_vira_session_expired() {
        let kind = ErrorKind::UnknownToken(Default::default());
        assert!(matches!(
            map_error_kind(Some(&kind)),
            AuthError::SessionExpired
        ));
    }

    #[test]
    fn sem_resposta_do_servidor_vira_network() {
        assert!(matches!(map_error_kind(None), AuthError::Network));
    }

    #[tokio::test]
    async fn logout_sem_login_retorna_not_logged_in() {
        assert!(matches!(logout().await, Err(AuthError::NotLoggedIn)));
    }
}
