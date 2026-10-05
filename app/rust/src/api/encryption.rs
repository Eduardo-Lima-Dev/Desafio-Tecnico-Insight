use flutter_rust_bridge::frb;
use futures_util::StreamExt;
use matrix_sdk::encryption::recovery::{RecoveryError, RecoveryState};
use matrix_sdk::encryption::secret_storage::SecretStorageError;

use crate::frb_generated::StreamSink;
use crate::{client_holder, sync_holder};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RecoveryStatus {
    Unknown,
    Enabled,
    Disabled,
    Incomplete,
}

#[derive(Debug, thiserror::Error)]
pub enum EncryptionError {
    #[error("not logged in")]
    NotLoggedIn,
    #[error("invalid recovery key")]
    InvalidKey,
    #[error("backup already exists")]
    BackupExists,
    #[error("network")]
    Network,
    #[error("encryption failed")]
    Failed,
}

pub async fn watch_recovery_status(
    sink: StreamSink<RecoveryStatus>,
) -> Result<(), EncryptionError> {
    watch_recovery_status_with(|status| sink.add(status).is_ok()).await
}

#[frb(ignore)]
pub async fn watch_recovery_status_with<F>(mut emit: F) -> Result<(), EncryptionError>
where
    F: FnMut(RecoveryStatus) -> bool,
{
    let client = client_holder::get()
        .await
        .ok_or(EncryptionError::NotLoggedIn)?;
    let mut stop = sync_holder::stop_signal();
    let recovery = client.encryption().recovery();
    let mut states = recovery.state_stream();
    if !emit(map_state(recovery.state())) {
        return Ok(());
    }
    loop {
        tokio::select! {
            next = states.next() => match next {
                Some(state) => {
                    if !emit(map_state(state)) {
                        break;
                    }
                }
                None => break,
            },
            _ = stop.changed() => break,
        }
    }
    Ok(())
}

pub async fn recover_keys(recovery_key: String) -> Result<(), EncryptionError> {
    let client = client_holder::get()
        .await
        .ok_or(EncryptionError::NotLoggedIn)?;
    client
        .encryption()
        .recovery()
        .recover(recovery_key.trim())
        .await
        .map_err(map_recovery_error)
}

pub async fn enable_recovery() -> Result<String, EncryptionError> {
    let client = client_holder::get()
        .await
        .ok_or(EncryptionError::NotLoggedIn)?;
    client
        .encryption()
        .recovery()
        .enable()
        .await
        .map_err(map_recovery_error)
}

fn map_state(state: RecoveryState) -> RecoveryStatus {
    match state {
        RecoveryState::Enabled => RecoveryStatus::Enabled,
        RecoveryState::Disabled => RecoveryStatus::Disabled,
        RecoveryState::Incomplete => RecoveryStatus::Incomplete,
        RecoveryState::Unknown => RecoveryStatus::Unknown,
    }
}

fn map_recovery_error(error: RecoveryError) -> EncryptionError {
    match error {
        RecoveryError::BackupExistsOnServer => EncryptionError::BackupExists,
        RecoveryError::SecretStorage(SecretStorageError::SecretStorageKey(_)) => {
            EncryptionError::InvalidKey
        }
        RecoveryError::Sdk(error)
        | RecoveryError::SecretStorage(SecretStorageError::Sdk(error))
            if error.as_client_api_error().is_none() && error.client_api_error_kind().is_none() =>
        {
            EncryptionError::Network
        }
        _ => EncryptionError::Failed,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn estados_do_sdk_viram_status() {
        assert_eq!(map_state(RecoveryState::Enabled), RecoveryStatus::Enabled);
        assert_eq!(map_state(RecoveryState::Disabled), RecoveryStatus::Disabled);
        assert_eq!(
            map_state(RecoveryState::Incomplete),
            RecoveryStatus::Incomplete
        );
        assert_eq!(map_state(RecoveryState::Unknown), RecoveryStatus::Unknown);
    }

    #[test]
    fn backup_existente_vira_backup_exists() {
        assert!(matches!(
            map_recovery_error(RecoveryError::BackupExistsOnServer),
            EncryptionError::BackupExists
        ));
    }

    #[tokio::test]
    async fn recuperar_sem_login_retorna_not_logged_in() {
        assert!(matches!(
            recover_keys("chave".into()).await,
            Err(EncryptionError::NotLoggedIn)
        ));
    }

    #[tokio::test]
    async fn ativar_sem_login_retorna_not_logged_in() {
        assert!(matches!(
            enable_recovery().await,
            Err(EncryptionError::NotLoggedIn)
        ));
    }
}

#[cfg(test)]
mod integration_tests {
    use std::path::PathBuf;
    use std::time::Duration;

    use matrix_sdk::config::SyncSettings;
    use matrix_sdk::ruma::events::room::message::RoomMessageEventContent;
    use matrix_sdk::ruma::UserId;
    use matrix_sdk::Client;
    use tokio::time::{sleep, timeout};

    use super::*;
    use crate::api::chat::{open_room, watch_messages_with, MessageKind};
    use crate::api::conversations::{accept_invite, watch_invites_with};
    use crate::api::rooms::{start_sync, stop_sync, watch_rooms_with};
    use crate::api::session::login;
    use crate::client_holder;

    fn server() -> String {
        std::env::var("SYNAPSE_URL").unwrap_or_else(|_| "http://localhost:8008".to_owned())
    }

    fn data_dir(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!("enc-{name}-{}", std::process::id()))
    }

    async fn direct_client(user: &str, name: &str) -> Client {
        let client = Client::builder()
            .homeserver_url(server())
            .sqlite_store(data_dir(name), None)
            .build()
            .await
            .unwrap();
        client
            .matrix_auth()
            .login_username(user, "senha123")
            .send()
            .await
            .unwrap();
        client.sync_once(SyncSettings::default()).await.unwrap();
        client
    }

    async fn leave_and_forget(room: &matrix_sdk::Room) {
        let _ = room.leave().await;
        let _ = room.forget().await;
    }

    async fn find_text(room_id: &str, text: &str) -> bool {
        let mut found = false;
        let _ = timeout(
            Duration::from_secs(60),
            watch_messages_with(room_id.to_owned(), |messages| {
                found = messages
                    .iter()
                    .any(|message| message.kind == MessageKind::Text && message.text == text);
                !found
            }),
        )
        .await;
        found
    }

    async fn open_when_joined(room_id: &str) {
        for _ in 0..60 {
            if open_room(room_id.to_owned()).await.is_ok() {
                return;
            }
            sleep(Duration::from_secs(1)).await;
        }
        panic!("a sala não apareceu para o app");
    }

    #[tokio::test]
    #[ignore = "exige o homeserver local em execução (docker compose up -d); cria uma sala de teste"]
    async fn decifra_a_mensagem_nova_de_uma_sala_criptografada() {
        login(
            server(),
            "bob".into(),
            "senha123".into(),
            data_dir("bob").to_string_lossy().to_string(),
            "pass".into(),
        )
        .await
        .unwrap();

        start_sync().await.unwrap();
        let _ = timeout(
            Duration::from_secs(60),
            watch_rooms_with(|rooms| rooms.is_empty()),
        )
        .await;

        let alice = direct_client("alice", "alice-a").await;
        let bob_id = UserId::parse("@bob:localhost").unwrap();
        let room = alice.create_dm(&bob_id).await.unwrap();
        alice.sync_once(SyncSettings::default()).await.unwrap();
        assert!(room.latest_encryption_state().await.unwrap().is_encrypted());
        let text = format!("segredo {}", std::process::id());
        room.send(RoomMessageEventContent::text_plain(&text))
            .await
            .unwrap();

        let mut invite = None;
        let _ = timeout(
            Duration::from_secs(60),
            watch_invites_with(|invites| {
                invite = invites
                    .iter()
                    .find(|item| item.room_id == room.room_id().as_str())
                    .map(|item| item.room_id.clone());
                invite.is_none()
            }),
        )
        .await;
        let room_id = invite.expect("o convite não chegou");
        accept_invite(room_id.clone()).await.unwrap();
        open_when_joined(&room_id).await;

        let found = find_text(&room_id, &text).await;
        stop_sync().await;
        if let Some(own) = client_holder::get()
            .await
            .and_then(|client| client.get_room(room.room_id()))
        {
            leave_and_forget(&own).await;
        }
        leave_and_forget(&room).await;
        assert!(found);
    }

    #[tokio::test]
    #[ignore = "exige o homeserver local em execução (docker compose up -d); ativa a recuperação da conta alice"]
    async fn recupera_o_historico_com_a_chave_de_recuperacao() {
        let first = direct_client("alice", "alice-b").await;
        let _ = first.encryption().recovery().disable().await;
        let _ = first.encryption().backups().disable_and_delete().await;
        let recovery_key = first.encryption().recovery().enable().await.unwrap();
        let bob_id = UserId::parse("@bob:localhost").unwrap();
        let room = first.create_dm(&bob_id).await.unwrap();
        first.sync_once(SyncSettings::default()).await.unwrap();
        let text = format!("historico {}", std::process::id());
        room.send(RoomMessageEventContent::text_plain(&text))
            .await
            .unwrap();
        sleep(Duration::from_secs(3)).await;
        first
            .encryption()
            .backups()
            .wait_for_steady_state()
            .await
            .unwrap();

        login(
            server(),
            "alice".into(),
            "senha123".into(),
            data_dir("alice-c").to_string_lossy().to_string(),
            "pass".into(),
        )
        .await
        .unwrap();
        start_sync().await.unwrap();

        let room_id = room.room_id().to_string();
        let mut visible = false;
        let _ = timeout(
            Duration::from_secs(60),
            watch_rooms_with(|rooms| {
                visible = rooms.iter().any(|item| item.id == room_id);
                !visible
            }),
        )
        .await;
        assert!(visible, "a sala não apareceu");
        open_when_joined(&room_id).await;
        assert!(!find_text_briefly(&room_id, &text).await);

        let mut incomplete = false;
        let _ = timeout(
            Duration::from_secs(60),
            watch_recovery_status_with(|status| {
                incomplete = status == RecoveryStatus::Incomplete;
                !incomplete
            }),
        )
        .await;
        assert!(incomplete, "o estado deveria ser incompleto");

        assert!(matches!(
            recover_keys("chave incorreta".into()).await,
            Err(EncryptionError::InvalidKey)
        ));
        recover_keys(recovery_key).await.unwrap();

        let found = find_text(&room_id, &text).await;
        stop_sync().await;
        leave_and_forget(&room).await;
        assert!(found);
    }

    async fn find_text_briefly(room_id: &str, text: &str) -> bool {
        let mut found = false;
        let _ = timeout(
            Duration::from_secs(5),
            watch_messages_with(room_id.to_owned(), |messages| {
                found = messages
                    .iter()
                    .any(|message| message.kind == MessageKind::Text && message.text == text);
                !found
            }),
        )
        .await;
        found
    }
}
