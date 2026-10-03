use std::sync::LazyLock;

use matrix_sdk::Client;
use tokio::sync::RwLock;

static CLIENT: LazyLock<RwLock<Option<Client>>> = LazyLock::new(|| RwLock::new(None));

pub(crate) async fn set(client: Client) {
    *CLIENT.write().await = Some(client);
}

pub(crate) async fn get() -> Option<Client> {
    CLIENT.read().await.clone()
}

pub(crate) async fn take() -> Option<Client> {
    CLIENT.write().await.take()
}
