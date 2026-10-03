use std::sync::Arc;

use eyeball_im::Vector;
use flutter_rust_bridge::frb;
use futures_util::{pin_mut, StreamExt};
use matrix_sdk::ruma::api::client::receipt::create_receipt::v3::ReceiptType;
use matrix_sdk::ruma::events::room::message::{MessageType, RoomMessageEventContent};
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
    #[error("message not found")]
    MessageNotFound,
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

pub async fn send_message(room_id: String, text: String) -> Result<(), ChatError> {
    let body = text.trim();
    if body.is_empty() {
        return Err(ChatError::Failed);
    }
    let room_id = RoomId::parse(&room_id).map_err(|_| ChatError::RoomNotFound)?;
    let timeline = timeline_holder::get(&room_id)
        .await
        .ok_or(ChatError::RoomNotFound)?;
    timeline.room().send_queue().set_enabled(true);
    timeline
        .send(RoomMessageEventContent::text_plain(body).into())
        .await
        .map_err(|_| ChatError::Failed)?;
    Ok(())
}

pub async fn retry_send(room_id: String, message_id: String) -> Result<(), ChatError> {
    let room_id = RoomId::parse(&room_id).map_err(|_| ChatError::RoomNotFound)?;
    let timeline = timeline_holder::get(&room_id)
        .await
        .ok_or(ChatError::RoomNotFound)?;
    let handle = timeline
        .items()
        .await
        .iter()
        .find(|item| item.unique_id().0 == message_id)
        .and_then(|item| item.as_event())
        .and_then(|event| event.local_echo_send_handle())
        .ok_or(ChatError::MessageNotFound)?;
    timeline.room().send_queue().set_enabled(true);
    handle.unwedge().await.map_err(|_| ChatError::Failed)?;
    Ok(())
}

pub async fn load_older_messages(room_id: String, count: u16) -> Result<bool, ChatError> {
    let room_id = RoomId::parse(&room_id).map_err(|_| ChatError::RoomNotFound)?;
    let timeline = timeline_holder::get(&room_id)
        .await
        .ok_or(ChatError::RoomNotFound)?;
    timeline
        .paginate_backwards(count)
        .await
        .map_err(|_| ChatError::Failed)
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
    #[tokio::test]
    #[ignore = "exige o homeserver local em execução (docker compose up -d); cria e abandona uma sala de teste"]
    async fn envia_mensagens_e_confirma_o_envio() {
        let dir = std::env::temp_dir()
            .join(format!("chat-send-{}", std::process::id()))
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

        let client = client_holder::get().await.unwrap();
        let mut request = matrix_sdk::ruma::api::client::room::create_room::v3::Request::new();
        request.name = Some(format!("Teste de envio {}", std::process::id()));
        let room = client.create_room(request).await.unwrap();
        let room_id = room.room_id().to_string();

        open_room(room_id.clone()).await.unwrap();
        send_message(room_id.clone(), "Primeira mensagem".into())
            .await
            .unwrap();
        send_message(room_id.clone(), "  Segunda mensagem  ".into())
            .await
            .unwrap();

        let mut messages: Vec<ChatMessage> = Vec::new();
        let _ = timeout(
            Duration::from_secs(60),
            watch_messages_with(room_id.clone(), |batch| {
                let done = batch.len() == 2
                    && batch
                        .iter()
                        .all(|message| message.delivery == DeliveryState::Sent);
                messages = batch;
                !done
            }),
        )
        .await;
        for message in &messages {
            println!(
                "- own={:<5} {:?} {:?} {}",
                message.is_own, message.kind, message.delivery, message.text
            );
        }

        assert_eq!(messages.len(), 2);
        assert_eq!(messages[0].text, "Primeira mensagem");
        assert_eq!(messages[1].text, "Segunda mensagem");
        assert!(messages.iter().all(|message| message.is_own));
        assert!(messages
            .iter()
            .all(|message| message.delivery == DeliveryState::Sent));

        assert!(send_message(room_id.clone(), "   ".into()).await.is_err());
        assert!(matches!(
            retry_send(room_id.clone(), "inexistente".into()).await,
            Err(ChatError::MessageNotFound)
        ));

        close_room(room_id).await;
        let _ = room.leave().await;
        stop_sync().await;
        logout().await.unwrap();
    }
    #[tokio::test]
    #[ignore = "exige o homeserver local em execução (docker compose up -d)"]
    async fn carrega_o_historico_antigo_da_sala() {
        let dir = std::env::temp_dir()
            .join(format!("chat-history-{}", std::process::id()))
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
                    .find(|room| room.name == "Histórico longo")
                    .map(|room| room.id.clone());
                room_id.is_none()
            }),
        )
        .await;
        let room_id = room_id.expect("sala Histórico longo não encontrada");

        open_room(room_id.clone()).await.unwrap();
        let latest = std::sync::Arc::new(std::sync::Mutex::new(Vec::<ChatMessage>::new()));
        let sink = latest.clone();
        let watcher = tokio::spawn(watch_messages_with(room_id.clone(), move |batch| {
            *sink.lock().unwrap() = batch;
            true
        }));
        tokio::time::sleep(Duration::from_secs(5)).await;
        let initial = latest.lock().unwrap().len();
        println!("mensagens iniciais: {initial}");
        assert!(initial > 0 && initial < 80, "iniciais: {initial}");

        let mut reached_start = false;
        for round in 1..=10 {
            reached_start = load_older_messages(room_id.clone(), 30).await.unwrap();
            tokio::time::sleep(Duration::from_millis(500)).await;
            println!(
                "rodada {round}: {} mensagens, chegou ao início: {reached_start}",
                latest.lock().unwrap().len()
            );
            if reached_start {
                break;
            }
        }
        assert!(reached_start, "deveria ter chegado ao início da sala");

        let messages = latest.lock().unwrap().clone();
        assert_eq!(messages.len(), 80);
        assert_eq!(messages[0].text, "Mensagem 01 do histórico de teste");
        assert_eq!(messages[79].text, "Mensagem 80 do histórico de teste");
        assert!(messages
            .windows(2)
            .all(|pair| pair[0].sent_at_ms <= pair[1].sent_at_ms));
        let mut ids: Vec<&String> = messages.iter().map(|m| &m.id).collect();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), 80, "não deveria haver mensagens repetidas");

        watcher.abort();
        close_room(room_id).await;
        stop_sync().await;
        logout().await.unwrap();
    }
}
