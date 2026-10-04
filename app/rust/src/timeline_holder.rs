use std::sync::{Arc, LazyLock};

use matrix_sdk::ruma::OwnedRoomId;
use matrix_sdk_ui::timeline::Timeline;
use tokio::sync::{watch, RwLock};

struct Open {
    room_id: OwnedRoomId,
    timeline: Arc<Timeline>,
}

static OPEN: LazyLock<RwLock<Option<Open>>> = LazyLock::new(|| RwLock::new(None));
static STOP: LazyLock<watch::Sender<u64>> = LazyLock::new(|| watch::channel(0).0);

pub(crate) fn stop_signal() -> watch::Receiver<u64> {
    STOP.subscribe()
}

fn notify_closed() {
    STOP.send_modify(|generation| *generation += 1);
}

pub(crate) async fn replace(room_id: OwnedRoomId, timeline: Arc<Timeline>) {
    *OPEN.write().await = Some(Open { room_id, timeline });
    notify_closed();
}

pub(crate) async fn get(room_id: &matrix_sdk::ruma::RoomId) -> Option<Arc<Timeline>> {
    OPEN.read()
        .await
        .as_ref()
        .filter(|open| open.room_id == room_id)
        .map(|open| open.timeline.clone())
}

pub(crate) async fn close(room_id: Option<&matrix_sdk::ruma::RoomId>) -> Option<OwnedRoomId> {
    let mut open = OPEN.write().await;
    let matches = match (open.as_ref(), room_id) {
        (Some(current), Some(expected)) => current.room_id == expected,
        (Some(_), None) => true,
        (None, _) => false,
    };
    if !matches {
        return None;
    }
    let closed = open.take().map(|open| open.room_id);
    drop(open);
    notify_closed();
    closed
}
