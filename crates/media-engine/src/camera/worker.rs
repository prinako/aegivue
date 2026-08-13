use super::commands::CameraCommand;
use crate::{recording::recorder::CameraConfig, rtsp};
use sqlx::PgPool;
use std::path::PathBuf;
use tokio::{
    sync::{mpsc, watch},
    time::sleep,
};
use tokio_util::sync::CancellationToken;
use vigilo_common::CameraState;

pub struct CameraWorker {
    camera: CameraConfig,
    database: PgPool,
    storage: PathBuf,
    commands: mpsc::Receiver<CameraCommand>,
    status: watch::Sender<CameraState>,
    shutdown: CancellationToken,
}

impl CameraWorker {
    pub fn new(
        camera: CameraConfig,
        database: PgPool,
        storage: PathBuf,
        commands: mpsc::Receiver<CameraCommand>,
        status: watch::Sender<CameraState>,
        shutdown: CancellationToken,
    ) -> Self {
        Self {
            camera,
            database,
            storage,
            commands,
            status,
            shutdown,
        }
    }

    pub async fn run(mut self) {
        let mut attempt = 0;
        loop {
            if self.shutdown.is_cancelled() {
                break;
            }
            self.set_state(CameraState::Connecting);
            match rtsp::connection::connect(
                &self.camera,
                self.storage.clone(),
                self.database.clone(),
            )
            .await
            {
                Ok((mut child, recorder)) => {
                    self.set_state(CameraState::Online);
                    attempt = 0;
                    let mut metadata_tick =
                        tokio::time::interval(std::time::Duration::from_secs(5));
                    let should_stop = loop {
                        tokio::select! {
                            result = child.wait() => { tracing::warn!(camera_id=%self.camera.id, ?result, "FFmpeg stream ended"); break false; }
                            command = self.commands.recv() => match command {
                                Some(CameraCommand::Status(reply)) => { let _ = reply.send(*self.status.borrow()); }
                                Some(CameraCommand::Stop) | None => { self.set_state(CameraState::Stopping); let _=child.start_kill(); let _=child.wait().await; break true; }
                            },
                            () = self.shutdown.cancelled() => { self.set_state(CameraState::Stopping); let _=child.start_kill(); let _=child.wait().await; break true; }
                            _ = metadata_tick.tick() => recorder.persist_segments(false).await,
                        }
                    };
                    recorder.finalize().await;
                    if should_stop {
                        break;
                    }
                }
                Err(error) => {
                    tracing::warn!(camera_id=%self.camera.id, error=%error, "RTSP connection attempt failed")
                }
            }
            self.set_state(CameraState::Reconnecting);
            attempt += 1;
            tokio::select! { () = sleep(rtsp::reconnect::delay(attempt)) => {}, () = self.shutdown.cancelled() => break, command = self.commands.recv() => if matches!(command, Some(CameraCommand::Stop) | None) { break; } }
        }
        self.set_state(CameraState::Disabled);
    }

    fn set_state(&self, state: CameraState) {
        self.status.send_replace(state);
        tracing::info!(camera_id=%self.camera.id, ?state, "camera state changed");
    }
}
