use super::commands::CameraCommand;
use crate::{ffmpeg, live, recording::recorder::CameraConfig, rtsp};
use aegivue_common::CameraState;
use sqlx::PgPool;
use std::path::PathBuf;
use tokio::{
    sync::{mpsc, watch},
    time::sleep,
};
use tokio_util::sync::CancellationToken;

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
        if !self.camera.recording_enabled {
            self.run_live_only().await;
            self.set_state(CameraState::Disabled);
            return;
        }

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
                    if !self.set_state(CameraState::Online) {
                        ffmpeg::terminate(&mut child, &self.camera.id, "recording").await;
                        break;
                    }

                    let live_shutdown = self.shutdown.child_token();
                    let live_task =
                        tokio::spawn(live::supervise(self.camera.clone(), live_shutdown.clone()));

                    attempt = 0;
                    let mut metadata_tick =
                        tokio::time::interval(std::time::Duration::from_secs(5));
                    let should_stop = loop {
                        tokio::select! {
                            result = child.wait() => {
                                tracing::warn!(camera_id=%self.camera.id, ?result, "FFmpeg stream ended");
                                break false;
                            }
                            command = self.commands.recv() => match command {
                                Some(CameraCommand::Status(reply)) => { let _ = reply.send(*self.status.borrow()); }
                                Some(CameraCommand::Stop) | None => {
                                    self.set_state(CameraState::Stopping);
                                    live_shutdown.cancel();
                                    ffmpeg::terminate(&mut child, &self.camera.id, "recording").await;
                                    break true;
                                }
                            },
                            () = self.shutdown.cancelled() => {
                                self.set_state(CameraState::Stopping);
                                live_shutdown.cancel();
                                ffmpeg::terminate(&mut child, &self.camera.id, "recording").await;
                                break true;
                            }
                            _ = metadata_tick.tick() => recorder.persist_segments(false).await,
                        }
                    };

                    live_shutdown.cancel();
                    let _ = live_task.await;
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

    async fn run_live_only(&mut self) {
        if !self.set_state(CameraState::Connecting) {
            return;
        }

        let live_shutdown = self.shutdown.child_token();
        let live_task = tokio::spawn(live::supervise(self.camera.clone(), live_shutdown.clone()));

        tracing::info!(
            camera_id=%self.camera.id,
            "recording disabled; running live preview without recorder"
        );
        if !self.set_state(CameraState::Online) {
            live_shutdown.cancel();
            let _ = live_task.await;
            return;
        }

        loop {
            tokio::select! {
                command = self.commands.recv() => match command {
                    Some(CameraCommand::Status(reply)) => {
                        let _ = reply.send(*self.status.borrow());
                    }
                    Some(CameraCommand::Stop) | None => {
                        self.set_state(CameraState::Stopping);
                        live_shutdown.cancel();
                        break;
                    }
                },
                () = self.shutdown.cancelled() => {
                    self.set_state(CameraState::Stopping);
                    live_shutdown.cancel();
                    break;
                }
            }
        }

        let _ = live_task.await;
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
