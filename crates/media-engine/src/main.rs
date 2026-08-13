use tokio_util::sync::CancellationToken;
#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(std::env::var("VIGILO_LOG_LEVEL").unwrap_or_else(|_| "info".into()))
        .init();
    let cancel = CancellationToken::new();
    let signal = cancel.clone();
    tokio::spawn(async move {
        let _ = tokio::signal::ctrl_c().await;
        signal.cancel();
    });
    tracing::info!(service = "vigilo-media", "media engine started");
    cancel.cancelled().await;
    tracing::info!(service = "vigilo-media", "shutdown complete");
}
