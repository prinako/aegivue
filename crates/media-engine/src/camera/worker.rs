use super::commands::CameraCommand;
use crate::{recording::recorder::CameraConfig, rtsp};
use sqlx::PgPool;
use std::path::PathBuf;
use tokio::{
    io::AsyncReadExt,
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
    segment_seconds: u64,
}

impl CameraWorker {
    pub fn new(
        camera: CameraConfig,
        database: PgPool,
        storage: PathBuf,
        commands: mpsc::Receiver<CameraCommand>,
        status: watch::Sender<CameraState>,
        shutdown: CancellationToken,
        segment_seconds: u64,
    ) -> Self {
        Self {
            camera,
            database,
            storage,
            commands,
            status,
            shutdown,
            segment_seconds,
        }
    }

    pub async fn run(mut self) {
        let mut attempt = 0;
        loop {
            if self.shutdown.is_cancelled() {
                break;
            }
            if !self.set_state(CameraState::Connecting) {
                break;
            }
            match rtsp::connection::connect(
                &self.camera,
                self.storage.clone(),
                self.database.clone(),
                self.segment_seconds,
            )
            .await
            {
                Ok((mut child, recorder)) => {
                    if let Some(mut stderr) = child.stderr.take() {
                        tokio::spawn(async move {
                            let mut sink = [0_u8; 4096];
                            while stderr.read(&mut sink).await.is_ok_and(|read| read > 0) {}
                        });
                    }
                    if !self.set_state(CameraState::Online) {
                        break;
                    }
                    attempt = 0;
                    let mut metadata_tick =
                        tokio::time::interval(std::time::Duration::from_secs(5));
                    let should_stop = loop {
                        tokio::select! {
                            result = child.wait() => { tracing::warn!(camera_id=%self.camera.id, ?result, "FFmpeg stream ended"); break false; }
                            command = self.commands.recv() => match command {
                                Some(CameraCommand::Status(reply)) => { let _ = reply.send(*self.status.borrow()); }
                                Some(CameraCommand::Stop) | None => { self.set_state(CameraState::Stopping); terminate_child(&mut child).await; break true; }
                            },
                            () = self.shutdown.cancelled() => { self.set_state(CameraState::Stopping); terminate_child(&mut child).await; break true; }
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
            if !self.set_state(CameraState::Reconnecting) {
                break;
            }
            attempt += 1;
            let stop = tokio::select! { () = sleep(rtsp::reconnect::delay(attempt)) => false, () = self.shutdown.cancelled() => true, command = self.commands.recv() => matches!(command, Some(CameraCommand::Stop) | None) };
            if stop {
                self.set_state(CameraState::Stopping);
                break;
            }
        }
        self.set_state(CameraState::Disabled);
    }

    fn set_state(&self, next: CameraState) -> bool {
        let current = *self.status.borrow();
        match super::state::transition(current, next) {
            Ok(state) => {
                self.status.send_replace(state);
                tracing::info!(camera_id=%self.camera.id, ?state, "camera state changed");
                true
            }
            Err(error) => {
                tracing::error!(camera_id=%self.camera.id, %error, "invalid camera state transition prevented");
                false
            }
        }
    }
}

async fn terminate_child(child: &mut tokio::process::Child) {
    let _ = child.start_kill();
    if tokio::time::timeout(std::time::Duration::from_secs(5), child.wait())
        .await
        .is_err()
    {
        tracing::warn!("FFmpeg did not exit within shutdown timeout");
    }
}
