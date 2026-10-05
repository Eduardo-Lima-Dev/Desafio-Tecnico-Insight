use eyeball_im::Vector;
use flutter_rust_bridge::frb;
use futures_util::{pin_mut, StreamExt};
use matrix_sdk::ruma::events::direct::OwnedDirectUserIdentifier;
use matrix_sdk::ruma::events::room::member::MembershipState;
use matrix_sdk::ruma::{RoomId, UserId};
use matrix_sdk_ui::room_list_service::filters::new_filter_invite;
use matrix_sdk_ui::room_list_service::RoomListItem;

use crate::frb_generated::StreamSink;
use crate::{client_holder, sync_holder};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InviteSummary {
    pub room_id: String,
    pub name: String,
    pub inviter_id: String,
    pub inviter_name: String,
}

#[derive(Debug, thiserror::Error)]
pub enum ConversationError {
    #[error("not logged in")]
    NotLoggedIn,
    #[error("invalid user")]
    InvalidUser,
    #[error("conversation with yourself")]
    SelfConversation,
    #[error("user not found")]
    UserNotFound,
    #[error("room not found")]
    RoomNotFound,
    #[error("conversation failed")]
    Failed,
}

pub async fn create_conversation(user_id: String) -> Result<String, ConversationError> {
    let client = client_holder::get()
        .await
        .ok_or(ConversationError::NotLoggedIn)?;
    let user_id = UserId::parse(&user_id).map_err(|_| ConversationError::InvalidUser)?;
    if client.user_id() == Some(&user_id) {
        return Err(ConversationError::SelfConversation);
    }
    if let Some(existing) = existing_conversation(&client, &user_id).await {
        return Ok(existing);
    }

    match client.account().fetch_user_profile_of(&user_id).await {
        Ok(_) => {}
        Err(error) => {
            let not_found = error
                .as_client_api_error()
                .is_some_and(|api| api.status_code.as_u16() == 404);
            return Err(if not_found {
                ConversationError::UserNotFound
            } else {
                ConversationError::Failed
            });
        }
    }

    let room = client
        .create_dm(&user_id)
        .await
        .map_err(|_| ConversationError::Failed)?;
    Ok(room.room_id().to_string())
}

async fn existing_conversation(client: &matrix_sdk::Client, user_id: &UserId) -> Option<String> {
    let target = OwnedDirectUserIdentifier::from(user_id.to_owned());
    for room in client.joined_rooms() {
        if !room.direct_targets().contains(&target) {
            continue;
        }
        let still_there = match room.get_member_no_sync(user_id).await {
            Ok(Some(member)) => matches!(
                member.membership(),
                MembershipState::Join | MembershipState::Invite
            ),
            Ok(None) => true,
            Err(_) => false,
        };
        if still_there {
            return Some(room.room_id().to_string());
        }
    }
    None
}

pub async fn accept_invite(room_id: String) -> Result<(), ConversationError> {
    let room = invited_room(&room_id).await?;
    room.join().await.map_err(|_| ConversationError::Failed)
}

pub async fn decline_invite(room_id: String) -> Result<(), ConversationError> {
    let room = invited_room(&room_id).await?;
    room.leave().await.map_err(|_| ConversationError::Failed)
}

pub async fn watch_invites(sink: StreamSink<Vec<InviteSummary>>) -> Result<(), ConversationError> {
    watch_invites_with(|invites| sink.add(invites).is_ok()).await
}

#[frb(ignore)]
pub async fn watch_invites_with<F>(mut emit: F) -> Result<(), ConversationError>
where
    F: FnMut(Vec<InviteSummary>) -> bool,
{
    let service = sync_holder::get()
        .await
        .ok_or(ConversationError::NotLoggedIn)?;
    let mut stop = sync_holder::stop_signal();
    let room_list = service
        .room_list_service()
        .all_rooms()
        .await
        .map_err(|_| ConversationError::Failed)?;
    let (stream, controller) = room_list.entries_with_dynamic_adapters(200);
    controller.set_filter(Box::new(new_filter_invite()));
    pin_mut!(stream);

    let mut rooms: Vector<RoomListItem> = Vector::new();
    loop {
        let diffs = tokio::select! {
            diffs = stream.next() => match diffs {
                Some(diffs) => diffs,
                None => break,
            },
            _ = stop.changed() => break,
        };
        for diff in diffs {
            diff.apply(&mut rooms);
        }
        let mut invites = Vec::new();
        for item in rooms.iter() {
            if let Some(invite) = to_invite(item).await {
                invites.push(invite);
            }
        }
        if !emit(invites) {
            break;
        }
    }
    Ok(())
}

async fn invited_room(room_id: &str) -> Result<matrix_sdk::Room, ConversationError> {
    let client = client_holder::get()
        .await
        .ok_or(ConversationError::NotLoggedIn)?;
    let room_id = RoomId::parse(room_id).map_err(|_| ConversationError::RoomNotFound)?;
    client
        .get_room(&room_id)
        .ok_or(ConversationError::RoomNotFound)
}

async fn to_invite(item: &RoomListItem) -> Option<InviteSummary> {
    let details = item.invite_details().await.ok()?;
    let inviter_name = details
        .inviter
        .as_ref()
        .and_then(|member| member.display_name().map(str::to_owned))
        .filter(|name| !name.trim().is_empty())
        .unwrap_or_else(|| details.inviter_id.localpart().to_owned());
    let name = item
        .cached_display_name()
        .map(|name| name.to_string())
        .filter(|name| !name.trim().is_empty())
        .unwrap_or_else(|| inviter_name.clone());

    Some(InviteSummary {
        room_id: item.room_id().to_string(),
        name,
        inviter_id: details.inviter_id.to_string(),
        inviter_name,
    })
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use tokio::time::timeout;

    use super::*;
    use crate::api::rooms::{start_sync, stop_sync, watch_rooms_with};
    use crate::api::session::{login, logout};

    fn server() -> String {
        std::env::var("SYNAPSE_URL").unwrap_or_else(|_| "http://localhost:8008".to_owned())
    }

    async fn enter(user: &str) {
        let dir = std::env::temp_dir()
            .join(format!(
                "conv-{user}-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ))
            .to_string_lossy()
            .to_string();
        login(server(), user.into(), "senha123".into(), dir, "pass".into())
            .await
            .unwrap();
        start_sync().await.unwrap();
        let _ = timeout(
            Duration::from_secs(60),
            watch_rooms_with(|rooms| rooms.len() < 3),
        )
        .await;
    }

    async fn leave_session() {
        stop_sync().await;
        logout().await.unwrap();
    }

    async fn wait_for_room(room_id: &str) -> bool {
        let mut found = false;
        let _ = timeout(
            Duration::from_secs(60),
            watch_rooms_with(|rooms| {
                found = rooms.iter().any(|room| room.id == room_id);
                !found
            }),
        )
        .await;
        found
    }

    async fn wait_for_invite(room_id: &str) -> Option<InviteSummary> {
        let mut found = None;
        let _ = timeout(
            Duration::from_secs(60),
            watch_invites_with(|invites| {
                found = invites.into_iter().find(|invite| invite.room_id == room_id);
                found.is_none()
            }),
        )
        .await;
        found
    }

    async fn cleanup(room_id: &str) {
        let client = client_holder::get().await.unwrap();
        if let Some(room) = client.get_room(&RoomId::parse(room_id).unwrap()) {
            let _ = room.leave().await;
            let _ = room.forget().await;
        }
    }

    #[tokio::test]
    #[ignore = "exige o homeserver local em execução (docker compose up -d); cria e abandona conversas de teste"]
    async fn cria_conversa_e_o_outro_usuario_aceita_ou_recusa() {
        enter("alice").await;

        assert!(matches!(
            create_conversation("invalido".into()).await,
            Err(ConversationError::InvalidUser)
        ));
        assert!(matches!(
            create_conversation("@alice:localhost".into()).await,
            Err(ConversationError::SelfConversation)
        ));
        assert!(matches!(
            create_conversation("@naoexiste:localhost".into()).await,
            Err(ConversationError::UserNotFound)
        ));

        let with_bob = create_conversation("@bob:localhost".into()).await.unwrap();
        tokio::time::sleep(Duration::from_secs(4)).await;
        let again = create_conversation("@bob:localhost".into()).await.unwrap();
        println!("conversa com o bob: {with_bob} (repetida: {again})");
        assert_eq!(with_bob, again, "não deveria duplicar a conversa");
        let created = client_holder::get()
            .await
            .unwrap()
            .get_room(&RoomId::parse(&with_bob).unwrap())
            .unwrap();
        assert!(
            created
                .latest_encryption_state()
                .await
                .unwrap()
                .is_encrypted(),
            "a conversa criada deveria ser criptografada"
        );
        assert!(
            wait_for_room(&with_bob).await,
            "a conversa deveria aparecer na lista"
        );

        let with_carol = create_conversation("@carol:localhost".into())
            .await
            .unwrap();
        assert_ne!(with_bob, with_carol);
        leave_session().await;

        enter("bob").await;
        let invite = wait_for_invite(&with_bob).await.expect("convite do bob");
        println!("convite para o bob: {invite:?}");
        assert_eq!(invite.inviter_id, "@alice:localhost");
        assert_eq!(invite.inviter_name, "Alice");
        assert!(!invite.name.is_empty());
        accept_invite(with_bob.clone()).await.unwrap();
        assert!(
            wait_for_room(&with_bob).await,
            "o bob deveria ver a conversa depois de aceitar"
        );
        cleanup(&with_bob).await;
        leave_session().await;

        enter("carol").await;
        let invite = wait_for_invite(&with_carol)
            .await
            .expect("convite da carol");
        assert_eq!(invite.inviter_name, "Alice");
        decline_invite(with_carol.clone()).await.unwrap();
        let mut still_pending = true;
        let _ = timeout(
            Duration::from_secs(30),
            watch_invites_with(|invites| {
                still_pending = invites.iter().any(|i| i.room_id == with_carol);
                still_pending
            }),
        )
        .await;
        assert!(!still_pending, "o convite recusado deveria sumir");
        leave_session().await;

        enter("alice").await;
        cleanup(&with_bob).await;
        cleanup(&with_carol).await;
        leave_session().await;
    }
}
