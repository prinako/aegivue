use super::commands::CameraCommand;
use crate::{
    ffmpeg, live, motion,
    recording::{
        motion_event::MotionEventRecorder,
        prebuffer::{self, PreEventBuffer},
        recorder::CameraConfig,
    },
    rtsp,
};
use aegivue_common::CameraState;
use chrono::{DateTime, Local, Utc};
use sqlx::PgPool;
use std::{path::PathBuf, sync::Arc};
use tokio::{
    process::Child,
    sync::{mpsc, watch},
    time::{Duration, sleep},
};
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

struct MotionRecordingSession {
    event_id: Uuid,
    child: Child,
    recorder: MotionEventRecorder,
}

pub struct CameraWorker {
    camera: CameraConfig,
    database: PgPool,
    storage: PathBuf,
    commands: mpsc::Receiver<CameraCommand>,
    status: watch::Sender<CameraState>,
    shutdown: CancellationToken,
    segment_seconds: u64,
    recording_mode: String,
    pre_event_seconds: i32,
    post_event_seconds: i32,
}

impl CameraWorker {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        camera: CameraConfig,
        database: PgPool,
        storage: PathBuf,
        commands: mpsc::Receiver<CameraCommand>,
        status: watch::Sender<CameraState>,
        shutdown: CancellationToken,
        segment_seconds: u64,
        recording_mode: String,
        pre_event_seconds: i32,
        post_event_seconds: i32,
    ) -> Self {
        Self {
            camera,
            database,
            storage,
            commands,
            status,
            shutdown,
            segment_seconds,
            recording_mode,
            pre_event_seconds,
            post_event_seconds,
        }
    }

    pub async fn run(mut self) {
        if !self.camera.recording_enabled {
            self.run_live_only().await;
        } else if self.recording_mode == "motion" {
            self.run_motion_recording().await;
        } else {
            self.run_continuous_recording().await;
        }
        self.set_state(CameraState::Disabled);
    }

    async fn run_continuous_recording(&mut self) {
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

                    let auxiliary_shutdown = self.shutdown.child_token();
                    let live_task = tokio::spawn(live::supervise(
                        self.camera.clone(),
                        auxiliary_shutdown.child_token(),
                    ));
                    let motion_task = tokio::spawn(motion::detector::supervise(
                        self.camera.clone(),
                        self.database.clone(),
                        auxiliary_shutdown.child_token(),
                    ));

                    attempt = 0;
                    let mut metadata_tick = tokio::time::interval(Duration::from_secs(5));
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
                                    auxiliary_shutdown.cancel();
                                    ffmpeg::terminate(&mut child, &self.camera.id, "recording").await;
                                    break true;
                                }
                            },
                            () = self.shutdown.cancelled() => {
                                self.set_state(CameraState::Stopping);
                                auxiliary_shutdown.cancel();
                                ffmpeg::terminate(&mut child, &self.camera.id, "recording").await;
                                break true;
                            }
                            _ = metadata_tick.tick() => recorder.persist_segments(false).await,
                        }
                    };

                    auxiliary_shutdown.cancel();
                    let _ = live_task.await;
                    let _ = motion_task.await;
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
            let stop = tokio::select! {
                () = sleep(rtsp::reconnect::delay(attempt)) => false,
                () = self.shutdown.cancelled() => true,
                command = self.commands.recv() => matches!(command, Some(CameraCommand::Stop) | None)
            };
            if stop {
                self.set_state(CameraState::Stopping);
                break;
            }
        }
    }

    async fn run_motion_recording(&mut self) {
        if !self.set_state(CameraState::Connecting) {
            return;
        }

        let auxiliary_shutdown = self.shutdown.child_token();
        let live_task = tokio::spawn(live::supervise(
            self.camera.clone(),
            auxiliary_shutdown.child_token(),
        ));
        let motion_task = tokio::spawn(motion::detector::supervise(
            self.camera.clone(),
            self.database.clone(),
            auxiliary_shutdown.child_token(),
        ));

        let mut prebuffer_child: Option<Child> = None;
        let mut prebuffer_task = None;
        let prebuffer = if self.pre_event_seconds > 0 {
            match PreEventBuffer::start(&self.camera, &self.storage, self.pre_event_seconds).await {
                Ok((buffer, mut child)) => {
                    ffmpeg::log_stderr(
                        &mut child,
                        &self.camera.id,
                        "pre-event-buffer",
                        self.camera.username.as_deref(),
                        self.camera.password_secret.as_deref(),
                    );
                    let buffer = Arc::new(buffer);
                    prebuffer_task = Some(tokio::spawn(prebuffer::supervise_pruning(
                        buffer.clone(),
                        auxiliary_shutdown.child_token(),
                    )));
                    prebuffer_child = Some(child);
                    tracing::info!(
                        camera_id=%self.camera.id,
                        pre_event_seconds=self.pre_event_seconds,
                        "pre-event recording buffer started"
                    );
                    Some(buffer)
                }
                Err(error) => {
                    tracing::warn!(
                        camera_id=%self.camera.id,
                        %error,
                        "unable to start pre-event recording buffer; motion recording will start at trigger"
                    );
                    None
                }
            }
        } else {
            None
        };

        tracing::info!(
            camera_id=%self.camera.id,
            pre_event_seconds=self.pre_event_seconds,
            post_event_seconds=self.post_event_seconds,
            "motion recording mode active; event recorder is idle until motion is detected"
        );

        if !self.set_state(CameraState::Online) {
            auxiliary_shutdown.cancel();
            if let Some(mut child) = prebuffer_child.take() {
                ffmpeg::terminate(&mut child, &self.camera.id, "pre-event-buffer").await;
            }
            if let Some(task) = prebuffer_task.take() {
                let _ = task.await;
            }
            let _ = live_task.await;
            let _ = motion_task.await;
            return;
        }

        let mut event_poll = tokio::time::interval(Duration::from_millis(250));
        event_poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
        let mut session: Option<MotionRecordingSession> = None;

        loop {
            tokio::select! {
                command = self.commands.recv() => match command {
                    Some(CameraCommand::Status(reply)) => {
                        let _ = reply.send(*self.status.borrow());
                    }
                    Some(CameraCommand::Stop) | None => {
                        self.set_state(CameraState::Stopping);
                        auxiliary_shutdown.cancel();
                        break;
                    }
                },
                () = self.shutdown.cancelled() => {
                    self.set_state(CameraState::Stopping);
                    auxiliary_shutdown.cancel();
                    break;
                }
                _ = event_poll.tick() => {
                    if let Some(active) = session.as_mut()
                        && active.child.try_wait().is_ok_and(|status| status.is_some())
                    {
                        tracing::warn!(camera_id=%self.camera.id, event_id=%active.event_id, "motion-triggered recorder exited unexpectedly");
                        let finished = session.take().expect("motion recording session exists");
                        self.finish_motion_session(finished).await;
                    }

                    let desired_event = match self.current_motion_event().await {
                        Ok(event) => event,
                        Err(error) => {
                            tracing::warn!(camera_id=%self.camera.id, %error, "unable to read motion recording trigger state");
                            continue;
                        }
                    };

                    match (session.is_some(), desired_event) {
                        (false, Some((event_id, event_started_at))) => {
                            match self
                                .start_motion_session(
                                    event_id,
                                    event_started_at,
                                    prebuffer.as_deref(),
                                )
                                .await
                            {
                                Ok(started) => session = Some(started),
                                Err(error) => tracing::warn!(camera_id=%self.camera.id, event_id=%event_id, %error, "unable to start motion-triggered recorder"),
                            }
                        }
                        (true, None) => {
                            let finished = session.take().expect("motion recording session exists");
                            self.finish_motion_session(finished).await;
                        }
                        _ => {}
                    }
                }
            }
        }

        if let Some(active) = session.take() {
            self.finish_motion_session(active).await;
        }
        auxiliary_shutdown.cancel();
        if let Some(mut child) = prebuffer_child.take() {
            ffmpeg::terminate(&mut child, &self.camera.id, "pre-event-buffer").await;
        }
        if let Some(task) = prebuffer_task.take() {
            let _ = task.await;
        }
        let _ = live_task.await;
        let _ = motion_task.await;
    }

    async fn current_motion_event(&self) -> Result<Option<(Uuid, DateTime<Utc>)>, sqlx::Error> {
        sqlx::query_as::<_, (Uuid, DateTime<Utc>)>(
            "SELECT id, started_at FROM events WHERE camera_id=$1 AND kind='motion' AND (ended_at IS NULL OR ended_at + ($2 * INTERVAL '1 second') > now()) ORDER BY started_at DESC LIMIT 1",
        )
        .bind(&self.camera.id)
        .bind(self.post_event_seconds)
        .fetch_optional(&self.database)
        .await
    }

    async fn start_motion_session(
        &self,
        event_id: Uuid,
        event_started_at: DateTime<Utc>,
        prebuffer: Option<&PreEventBuffer>,
    ) -> Result<MotionRecordingSession, String> {
        let (recorder, mut child) = MotionEventRecorder::start(
            self.camera.clone(),
            self.storage.clone(),
            self.database.clone(),
            event_id,
            event_started_at.with_timezone(&Local),
            prebuffer,
        )
        .await?;
        ffmpeg::log_stderr(
            &mut child,
            &self.camera.id,
            "motion-recording",
            self.camera.username.as_deref(),
            self.camera.password_secret.as_deref(),
        );
        tracing::info!(
            camera_id=%self.camera.id,
            event_id=%event_id,
            pre_event_segments=recorder.pre_event_segment_count(),
            "motion-triggered recorder started"
        );
        Ok(MotionRecordingSession {
            event_id,
            child,
            recorder,
        })
    }

    async fn finish_motion_session(&self, mut session: MotionRecordingSession) {
        ffmpeg::terminate(&mut session.child, &self.camera.id, "motion-recording").await;
        match session.recorder.finalize().await {
            Ok(path) => tracing::info!(
                camera_id=%self.camera.id,
                event_id=%session.event_id,
                path=%path.display(),
                "motion-triggered recorder stopped"
            ),
            Err(error) => tracing::warn!(
                camera_id=%self.camera.id,
                event_id=%session.event_id,
                %error,
                "unable to finalize motion-triggered recording"
            ),
        }
    }

    async fn run_live_only(&mut self) {
        if !self.set_state(CameraState::Connecting) {
            return;
        }

        let auxiliary_shutdown = self.shutdown.child_token();
        let live_task = tokio::spawn(live::supervise(
            self.camera.clone(),
            auxiliary_shutdown.child_token(),
        ));
        let motion_task = tokio::spawn(motion::detector::supervise(
            self.camera.clone(),
            self.database.clone(),
            auxiliary_shutdown.child_token(),
        ));

        tracing::info!(
            camera_id=%self.camera.id,
            "recording disabled; running live preview without recorder"
        );
        if !self.set_state(CameraState::Online) {
            auxiliary_shutdown.cancel();
            let _ = live_task.await;
            let _ = motion_task.await;
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
                        auxiliary_shutdown.cancel();
                        break;
                    }
                },
                () = self.shutdown.cancelled() => {
                    self.set_state(CameraState::Stopping);
                    auxiliary_shutdown.cancel();
                    break;
                }
            }
        }

        let _ = live_task.await;
        let _ = motion_task.await;
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
