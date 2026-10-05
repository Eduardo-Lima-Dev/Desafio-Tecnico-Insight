use std::error::Error as StdError;
use std::sync::Arc;

use eyeball_im::Vector;
use flutter_rust_bridge::frb;
use futures_util::{pin_mut, StreamExt};
use matrix_sdk::latest_events::LatestEventValue;
use matrix_sdk::ruma::api::error::ErrorKind;
use matrix_sdk::ruma::events::room::message::MessageType;
use matrix_sdk::ruma::events::{AnySyncMessageLikeEvent, AnySyncTimelineEvent};
use matrix_sdk::{Client, HttpError};
use matrix_sdk_ui::room_list_service::filters::new_filter_joined;
use matrix_sdk_ui::room_list_service::RoomListItem;
use matrix_sdk_ui::sync_service::{State, SyncService};

use crate::frb_generated::StreamSink;
use crate::{client_holder, sync_holder};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RoomSummary {
    pub id: String,
    pub name: String,
    pub last_message: Option<String>,
    pub last_message_at_ms: Option<u64>,
    pub unread_count: u64,
    pub member_count: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SyncStatus {
    Idle,
    Running,
    Offline,
    SessionExpired,
    Failed,
    Stopped,
}

#[derive(Debug, thiserror::Error)]
pub enum SyncError {
    #[error("not logged in")]
    NotLoggedIn,
    #[error("session expired")]
    SessionExpired,
    #[error("sync failed")]
    Failed,
}

pub async fn start_sync() -> Result<(), SyncError> {
    let client = client_holder::get().await.ok_or(SyncError::NotLoggedIn)?;
    let service = SyncService::builder(client)
        .with_room_list_timeline_limit(20)
        .with_offline_mode()
        .build()
        .await
        .map_err(|_| SyncError::Failed)?;
    service.start().await;
    sync_holder::replace(Arc::new(service)).await;
    Ok(())
}

pub async fn stop_sync() {
    sync_holder::stop().await;
}

pub async fn watch_sync_status(sink: StreamSink<SyncStatus>) -> Result<(), SyncError> {
    watch_sync_status_with(|status| sink.add(status).is_ok()).await
}

pub async fn watch_rooms(sink: StreamSink<Vec<RoomSummary>>) -> Result<(), SyncError> {
    watch_rooms_with(|rooms| sink.add(rooms).is_ok()).await
}

#[frb(ignore)]
pub async fn watch_sync_status_with<F>(mut emit: F) -> Result<(), SyncError>
where
    F: FnMut(SyncStatus) -> bool,
{
    let service = sync_holder::get().await.ok_or(SyncError::NotLoggedIn)?;
    let client = client_holder::get().await.ok_or(SyncError::NotLoggedIn)?;
    let mut stop = sync_holder::stop_signal();
    let mut states = service.state();
    let mut current = states.get();
    loop {
        let status = resolve_status(&client, &current).await;
        if !emit(status) || status == SyncStatus::SessionExpired {
            break;
        }
        tokio::select! {
            next = states.next() => match next {
                Some(next) => current = next,
                None => break,
            },
            _ = stop.changed() => break,
        }
    }
    Ok(())
}

#[frb(ignore)]
pub async fn watch_rooms_with<F>(mut emit: F) -> Result<(), SyncError>
where
    F: FnMut(Vec<RoomSummary>) -> bool,
{
    let service = sync_holder::get().await.ok_or(SyncError::NotLoggedIn)?;
    let mut stop = sync_holder::stop_signal();
    let room_list = service
        .room_list_service()
        .all_rooms()
        .await
        .map_err(|_| SyncError::Failed)?;
    let (stream, controller) = room_list.entries_with_dynamic_adapters(200);
    controller.set_filter(Box::new(new_filter_joined()));
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
        let summaries = rooms.iter().map(to_summary).collect();
        if !emit(summaries) {
            break;
        }
    }
    Ok(())
}

async fn resolve_status(client: &Client, state: &State) -> SyncStatus {
    let status = map_state(state);
    if status != SyncStatus::Offline {
        return status;
    }
    match client.whoami().await {
        Err(error)
            if matches!(
                error.client_api_error_kind(),
                Some(ErrorKind::UnknownToken { .. })
            ) =>
        {
            SyncStatus::SessionExpired
        }
        _ => SyncStatus::Offline,
    }
}

fn map_state(state: &State) -> SyncStatus {
    match state {
        State::Idle => SyncStatus::Idle,
        State::Running => SyncStatus::Running,
        State::Offline => SyncStatus::Offline,
        State::Terminated => SyncStatus::Stopped,
        State::Error(error) => {
            if is_unknown_token(error.as_ref()) {
                SyncStatus::SessionExpired
            } else {
                SyncStatus::Failed
            }
        }
    }
}

fn is_unknown_token(error: &(dyn StdError + 'static)) -> bool {
    let mut current: Option<&(dyn StdError + 'static)> = Some(error);
    while let Some(err) = current {
        let kind = err
            .downcast_ref::<matrix_sdk::Error>()
            .and_then(|e| e.client_api_error_kind())
            .or_else(|| {
                err.downcast_ref::<HttpError>()
                    .and_then(|e| e.client_api_error_kind())
            });
        if matches!(kind, Some(ErrorKind::UnknownToken { .. })) {
            return true;
        }
        current = err.source();
    }
    false
}

fn to_summary(item: &RoomListItem) -> RoomSummary {
    let name = item
        .cached_display_name()
        .map(|name| name.to_string())
        .filter(|name| !name.trim().is_empty())
        .unwrap_or_else(|| "Sala sem nome".to_owned());

    RoomSummary {
        id: item.room_id().to_string(),
        name,
        last_message: last_message_text(&item.latest_event()),
        last_message_at_ms: item.latest_event_timestamp().map(|ts| u64::from(ts.0)),
        unread_count: item.num_unread_messages(),
        member_count: item.joined_members_count(),
    }
}

fn last_message_text(value: &LatestEventValue) -> Option<String> {
    let LatestEventValue::Remote(event) = value else {
        return None;
    };
    let AnySyncTimelineEvent::MessageLike(event) = event.raw().deserialize().ok()? else {
        return None;
    };
    match event {
        AnySyncMessageLikeEvent::RoomMessage(message) => {
            let message = message.as_original()?;
            match &message.content.msgtype {
                MessageType::Text(text) => Some(text.body.clone()),
                MessageType::Notice(notice) => Some(notice.body.clone()),
                MessageType::Emote(emote) => Some(emote.body.clone()),
                _ => Some("Mensagem".to_owned()),
            }
        }
        AnySyncMessageLikeEvent::RoomEncrypted(_) => Some("Mensagem criptografada".to_owned()),
        _ => None,
    }
}
