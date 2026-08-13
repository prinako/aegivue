use sqlx::postgres::PgPoolOptions;
use std::{env, net::SocketAddr, path::PathBuf};
use tokio_util::sync::CancellationToken;
use vigilo_media::{camera::CameraManager, health};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(env::var("VIGILO_LOG_LEVEL").unwrap_or_else(|_| "info".into()))
        .init();
    let database_url =
        env::var("VIGILO_DATABASE_URL").map_err(|_| "VIGILO_DATABASE_URL is required")?;
    let storage = PathBuf::from(
        env::var("VIGILO_STORAGE_PATH").map_err(|_| "VIGILO_STORAGE_PATH is required")?,
    );
    let bind: SocketAddr = env::var("VIGILO_MEDIA_BIND")
        .unwrap_or_else(|_| "0.0.0.0:3010".into())
        .parse()?;
    let database = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;
    let shutdown = CancellationToken::new();
    let manager = CameraManager::new(database, storage, shutdown.clone());
    manager.start_enabled().await?;
    let listener = tokio::net::TcpListener::bind(bind).await?;
    tracing::info!(service="vigilo-media",%bind,"media control API started");
    axum::serve(listener, health::router(manager))
        .with_graceful_shutdown(async move {
            shutdown_signal().await;
            shutdown.cancel();
        })
        .await?;
    Ok(())
}

async fn shutdown_signal() {
    #[cfg(unix)]
    {
        use tokio::signal::unix::{SignalKind, signal};
        let Ok(mut terminate) = signal(SignalKind::terminate()) else {
            let _ = tokio::signal::ctrl_c().await;
            return;
        };
        tokio::select! { _ = tokio::signal::ctrl_c() => {}, _ = terminate.recv() => {} }
    }
    #[cfg(not(unix))]
    let _ = tokio::signal::ctrl_c().await;
}
