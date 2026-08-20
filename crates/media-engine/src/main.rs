use aegivue_media::{camera::CameraManager, health, retention};
use sqlx::postgres::PgPoolOptions;
use std::{env, net::SocketAddr, path::PathBuf};
use tokio_util::sync::CancellationToken;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(env::var("AEGIVUE_LOG_LEVEL").unwrap_or_else(|_| "info".into()))
        .init();
    let database_url =
        env::var("AEGIVUE_DATABASE_URL").map_err(|_| "AEGIVUE_DATABASE_URL is required")?;
    let storage = PathBuf::from(
        env::var("AEGIVUE_STORAGE_PATH").map_err(|_| "AEGIVUE_STORAGE_PATH is required")?,
    );
    let bind: SocketAddr = env::var("AEGIVUE_MEDIA_BIND")
        .unwrap_or_else(|_| "0.0.0.0:3010".into())
        .parse()?;
    let segment_seconds: u64 = env::var("AEGIVUE_RECORDING_SEGMENT_SECONDS")
        .unwrap_or_else(|_| "60".into())
        .parse()?;
    if !(5..=3600).contains(&segment_seconds) {
        return Err("AEGIVUE_RECORDING_SEGMENT_SECONDS must be between 5 and 3600".into());
    }
    let database = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;
    let shutdown = CancellationToken::new();
    let manager = CameraManager::new(
        database.clone(),
        storage.clone(),
        shutdown.clone(),
        segment_seconds,
    );
    manager.start_enabled().await?;

    let retention_database = database.clone();
    let retention_storage = storage.clone();
    let retention_shutdown = shutdown.child_token();
    tokio::spawn(async move {
        retention::supervise(retention_database, retention_storage, retention_shutdown).await;
    });

    let reconcile_manager = manager.clone();
    let reconcile_shutdown = shutdown.clone();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(15));
        loop {
            tokio::select! { _ = interval.tick() => { if let Err(error) = reconcile_manager.reconcile().await { tracing::error!(%error, "camera reconciliation failed"); } }, () = reconcile_shutdown.cancelled() => break }
        }
    });
    let listener = tokio::net::TcpListener::bind(bind).await?;
    tracing::info!(service="aegivue-media",%bind,"media control API started");
    axum::serve(listener, health::router(manager.clone()))
        .with_graceful_shutdown(async move {
            shutdown_signal().await;
            shutdown.cancel();
        })
        .await?;
    manager.shutdown_workers().await;
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
