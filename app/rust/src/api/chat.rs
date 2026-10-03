use std::sync::Arc;

use eyeball_im::Vector;
use flutter_rust_bridge::frb;
use futures_util::{pin_mut, StreamExt};
use matrix_sdk::ruma::api::client::receipt::create_receipt::v3::ReceiptType;
use matrix_sdk::ruma::events::room::message::MessageType;
use matrix_sdk::ruma::RoomId;
use matrix_sdk_ui::timeline::{
    EventSendState, EventTimelineItem, MsgLikeKind, Timeline, TimelineBuilder, TimelineDetails,
    TimelineItem, TimelineItemContent,
};

use crate::frb_generated::StreamSink;
use crate::{client_holder, sync_holder, timeline_holder};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MessageKind {
    Text,
    Encrypted,
    Other,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeliveryState {
    Sending,
    Sent,
    Failed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChatMessage {
    pub id: String,
    pub sender_id: String,
    pub sender_name: String,
    pub text: String,
    pub sent_at_ms: u64,
    pub is_own: bool,
    pub kind: MessageKind,
    pub delivery: DeliveryState,
}

#[derive(Debug, thiserror::Error)]
pub enum ChatError {
    #[error("not logged in")]
    NotLoggedIn,
    #[error("room not found")]
    RoomNotFound,
    #[error("chat failed")]
    Failed,
}

pub async fn open_room(room_id: String) -> Result<(), ChatError> {
    let room_id = RoomId::parse(&room_id).map_err(|_| ChatError::RoomNotFound)?;
    let client = client_holder::get().await.ok_or(ChatError::NotLoggedIn)?;
    let service = sync_holder::get().await.ok_or(ChatError::NotLoggedIn)?;
    let room = client.get_room(&room_id).ok_or(ChatError::RoomNotFound)?;

    service
        .room_list_service()
        .set_room_subscriptions(&[&room_id])
        .await;
    let timeline = TimelineBuilder::new(&room)
        .build()
        .await
        .map_err(|_| ChatError::Failed)?;
    timeline_holder::replace(room_id, Arc::new(timeline)).await;
    Ok(())
}

pub async fn close_room(room_id: String) {
    let Ok(room_id) = RoomId::parse(&room_id) else {
        return;
    };
    if let Some(closed) = timeline_holder::close(Some(&room_id)).await {
        if let Some(service) = sync_holder::get().await {
            service
                .room_list_service()
                .remove_room_subscriptions(&[&closed]);
        }
    }
}

pub async fn watch_messages(
    room_id: String,
    sink: StreamSink<Vec<ChatMessage>>,
) -> Result<(), ChatError> {
    watch_messages_with(room_id, |messages| sink.add(messages).is_ok()).await
}

#[frb(ignore)]
pub async fn watch_messages_with<F>(room_id: String, mut emit: F) -> Result<(), ChatError>
where
    F: FnMut(Vec<ChatMessage>) -> bool,
{
    let room_id = RoomId::parse(&room_id).map_err(|_| ChatError::RoomNotFound)?;
    let timeline = timeline_holder::get(&room_id)
        .await
        .ok_or(ChatError::RoomNotFound)?;
    let mut closed = timeline_holder::stop_signal();
    let (initial, stream) = timeline.subscribe().await;
    pin_mut!(stream);

    let mut items: Vector<Arc<TimelineItem>> = initial;
    if !publish(&timeline, &items, &mut emit).await {
        return Ok(());
    }
    loop {
        let diffs = tokio::select! {
            diffs = stream.next() => match diffs {
                Some(diffs) => diffs,
                None => break,
            },
            _ = closed.changed() => break,
        };
        for diff in diffs {
            diff.apply(&mut items);
        }
        if !publish(&timeline, &items, &mut emit).await {
            break;
        }
    }
    Ok(())
}

async fn publish<F>(timeline: &Timeline, items: &Vector<Arc<TimelineItem>>, emit: &mut F) -> bool
where
    F: FnMut(Vec<ChatMessage>) -> bool,
{
    let messages: Vec<ChatMessage> = items.iter().filter_map(to_message).collect();
    let has_incoming = messages.iter().any(|message| !message.is_own);
    let keep_going = emit(messages);
    if keep_going && has_incoming {
        let _ = timeline.mark_as_read(ReceiptType::Read).await;
    }
    keep_going
}

fn to_message(item: &Arc<TimelineItem>) -> Option<ChatMessage> {
    let event = item.as_event()?;
    let (kind, text) = describe(event)?;
    let sender = event.sender();

    Some(ChatMessage {
        id: item.unique_id().0.clone(),
        sender_id: sender.to_string(),
        sender_name: sender_name(event),
        text,
        sent_at_ms: u64::from(event.timestamp().0),
        is_own: event.is_own(),
        kind,
        delivery: delivery_of(event),
    })
}

fn describe(event: &EventTimelineItem) -> Option<(MessageKind, String)> {
    let TimelineItemContent::MsgLike(content) = event.content() else {
        return None;
    };
    Some(match &content.kind {
        MsgLikeKind::Message(message) => match message.msgtype() {
            MessageType::Text(_) | MessageType::Notice(_) | MessageType::Emote(_) => {
                (MessageKind::Text, message.body().to_owned())
            }
            _ => (MessageKind::Other, message.body().to_owned()),
        },
        MsgLikeKind::UnableToDecrypt(_) => (MessageKind::Encrypted, String::new()),
        MsgLikeKind::Redacted => (MessageKind::Other, "Mensagem apagada".to_owned()),
        _ => (MessageKind::Other, "Mensagem não suportada".to_owned()),
    })
}

fn sender_name(event: &EventTimelineItem) -> String {
    if let TimelineDetails::Ready(profile) = event.sender_profile() {
        if let Some(name) = profile
            .display_name
            .as_ref()
            .filter(|name| !name.trim().is_empty())
        {
            return name.clone();
        }
    }
    event.sender().localpart().to_owned()
}

fn delivery_of(event: &EventTimelineItem) -> DeliveryState {
    match event.send_state() {
        None | Some(EventSendState::Sent { .. }) => DeliveryState::Sent,
        Some(EventSendState::NotSentYet { .. }) => DeliveryState::Sending,
        Some(EventSendState::SendingFailed { .. }) => DeliveryState::Failed,
    }
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

    #[tokio::test]
    #[ignore = "exige o homeserver local em execução (docker compose up -d)"]
    async fn le_as_mensagens_de_uma_sala() {
        let dir = std::env::temp_dir()
            .join(format!("chat-{}", std::process::id()))
            .to_string_lossy()
            .to_string();
        login(
            server(),
            "alice".into(),
            "senha123".into(),
            dir,
            "pass".into(),
        )
        .await
        .unwrap();
        start_sync().await.unwrap();

        let mut room_id = None;
        let _ = timeout(
            Duration::from_secs(90),
            watch_rooms_with(|rooms| {
                room_id = rooms
                    .iter()
                    .find(|room| room.name == "Alice e Bob")
                    .map(|room| room.id.clone());
                room_id.is_none()
            }),
        )
        .await;
        let room_id = room_id.expect("sala Alice e Bob não encontrada");

        open_room(room_id.clone()).await.unwrap();
        let mut messages: Vec<ChatMessage> = Vec::new();
        let _ = timeout(
            Duration::from_secs(90),
            watch_messages_with(room_id.clone(), |batch| {
                let done = batch.len() >= 6;
                messages = batch;
                !done
            }),
        )
        .await;
        for message in &messages {
            println!(
                "- {:<6} own={:<5} {:?} {:?} {}",
                message.sender_name, message.is_own, message.kind, message.delivery, message.text
            );
        }

        assert!(messages.len() >= 6, "vieram {} mensagens", messages.len());
        assert_eq!(messages[0].text, "Oi, Bob! Tudo bem?");
        assert!(messages[0].is_own);
        assert_eq!(messages[0].sender_name, "Alice");
        assert_eq!(messages[1].text, "Tudo ótimo, Alice. E você?");
        assert!(!messages[1].is_own);
        assert_eq!(messages[1].sender_name, "Bob");
        assert!(messages
            .iter()
            .all(|m| m.kind == MessageKind::Text && m.delivery == DeliveryState::Sent));
        assert!(messages
            .windows(2)
            .all(|pair| pair[0].sent_at_ms <= pair[1].sent_at_ms));

        let watcher = tokio::spawn(watch_messages_with(room_id.clone(), |_| true));
        tokio::time::sleep(Duration::from_secs(1)).await;
        close_room(room_id).await;
        let ended = timeout(Duration::from_secs(5), watcher).await;
        assert!(ended.is_ok(), "o watcher deveria terminar ao fechar a sala");

        stop_sync().await;
        logout().await.unwrap();
    }
}
