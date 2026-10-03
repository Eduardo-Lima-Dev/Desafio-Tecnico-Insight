use std::sync::{Arc, LazyLock};

use matrix_sdk_ui::sync_service::SyncService;
use tokio::sync::{watch, RwLock};

static SYNC: LazyLock<RwLock<Option<Arc<SyncService>>>> = LazyLock::new(|| RwLock::new(None));
static STOP: LazyLock<watch::Sender<u64>> = LazyLock::new(|| watch::channel(0).0);

pub(crate) fn stop_signal() -> watch::Receiver<u64> {
    STOP.subscribe()
}

fn notify_stopped() {
    STOP.send_modify(|generation| *generation += 1);
}

pub(crate) async fn replace(service: Arc<SyncService>) {
    let previous = SYNC.write().await.replace(service);
    if let Some(previous) = previous {
        previous.stop().await;
        notify_stopped();
    }
}

pub(crate) async fn get() -> Option<Arc<SyncService>> {
    SYNC.read().await.clone()
}

pub(crate) async fn stop() {
    let service = SYNC.write().await.take();
    if let Some(service) = service {
        service.stop().await;
    }
    notify_stopped();
}
