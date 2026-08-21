use super::recorder::CameraConfig;
use chrono::{DateTime, Local, NaiveDateTime, TimeZone};
use std::{
    path::{Path, PathBuf},
    process::Stdio,
    time::Duration,
};
use tokio::{
    fs,
    process::{Child, Command},
};
use tokio_util::sync::CancellationToken;

const BUFFER_SEGMENT_SECONDS: u64 = 1;
const PRUNE_INTERVAL_SECONDS: u64 = 2;
const SAFETY_SEGMENTS: i64 = 3;

pub struct PreEventBuffer {
    root: PathBuf,
    keep_seconds: i32,
}

impl PreEventBuffer {
    pub async fn start(
        camera: &CameraConfig,
        storage: &Path,
        keep_seconds: i32,
    ) -> Result<(Self, Child), std::io::Error> {
        let root = storage.join(".prebuffer").join(&camera.id);
        fs::create_dir_all(&root).await?;
        cleanup_directory(&root).await;

        let pattern = root.join("%Y%m%d-%H%M%S.mp4");
        let segment_seconds = BUFFER_SEGMENT_SECONDS.to_string();
        let mut command = Command::new("ffmpeg");
        command
            .args([
                "-hide_banner",
                "-loglevel",
                "warning",
                "-rtsp_transport",
                "tcp",
                "-timeout",
                "10000000",
                "-i",
            ])
            .arg(camera.rtsp_url())
            .args([
                "-map",
                "0:v:0",
                "-map",
                "0:a?",
                "-c:v",
                "copy",
                "-c:a",
                "aac",
                "-b:a",
                "64k",
                "-f",
                "segment",
                "-segment_format",
                "mp4",
                "-segment_time",
                &segment_seconds,
                "-reset_timestamps",
                "1",
                "-strftime",
                "1",
                "-movflags",
                "+faststart",
            ])
            .arg(pattern)
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .kill_on_drop(true);

        Ok((Self { root, keep_seconds }, command.spawn()?))
    }

    pub async fn prune(&self) {
        let cutoff = Local::now()
            - chrono::Duration::seconds(i64::from(self.keep_seconds) + SAFETY_SEGMENTS);
        let Ok(mut entries) = fs::read_dir(&self.root).await else {
            return;
        };
        while let Ok(Some(entry)) = entries.next_entry().await {
            let path = entry.path();
            let Some(start) = buffered_segment_time(&path) else {
                continue;
            };
            if start < cutoff {
                let _ = fs::remove_file(path).await;
            }
        }
    }

    pub async fn snapshot(
        &self,
        trigger_at: DateTime<Local>,
        destination: &Path,
    ) -> Result<Vec<(PathBuf, DateTime<Local>)>, String> {
        if self.keep_seconds <= 0 {
            return Ok(Vec::new());
        }

        let cutoff = trigger_at - chrono::Duration::seconds(i64::from(self.keep_seconds));
        let mut candidates = Vec::new();
        let Ok(mut entries) = fs::read_dir(&self.root).await else {
            return Ok(candidates);
        };
        while let Ok(Some(entry)) = entries.next_entry().await {
            let path = entry.path();
            let Some(start) = buffered_segment_time(&path) else {
                continue;
            };
            if start >= cutoff && start < trigger_at {
                candidates.push((path, start));
            }
        }
        candidates.sort_by_key(|(_, start)| *start);

        // FFmpeg may still have the newest segment open. Keep it out of the
        // event snapshot so only complete MP4 files are assembled later.
        if !candidates.is_empty() {
            candidates.pop();
        }

        fs::create_dir_all(destination)
            .await
            .map_err(|error| error.to_string())?;
        let mut staged = Vec::new();
        for (index, (source, start)) in candidates.into_iter().enumerate() {
            let target = destination.join(format!("pre-{index:04}.mp4"));
            if fs::copy(&source, &target).await.is_err() {
                continue;
            }
            if probe_duration_ms(&target).await.is_none() {
                let _ = fs::remove_file(&target).await;
                continue;
            }
            staged.push((target, start));
        }
        Ok(staged)
    }
}

pub async fn supervise_pruning(
    buffer: std::sync::Arc<PreEventBuffer>,
    shutdown: CancellationToken,
) {
    let mut tick = tokio::time::interval(Duration::from_secs(PRUNE_INTERVAL_SECONDS));
    tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        tokio::select! {
            _ = tick.tick() => buffer.prune().await,
            () = shutdown.cancelled() => break,
        }
    }
}

fn buffered_segment_time(path: &Path) -> Option<DateTime<Local>> {
    let filename = path.file_name()?.to_str()?.strip_suffix(".mp4")?;
    let value = NaiveDateTime::parse_from_str(filename, "%Y%m%d-%H%M%S").ok()?;
    Local.from_local_datetime(&value).earliest()
}

async fn probe_duration_ms(path: &Path) -> Option<i64> {
    let output = Command::new("ffprobe")
        .args([
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
        ])
        .arg(path)
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .await
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let seconds: f64 = String::from_utf8(output.stdout).ok()?.trim().parse().ok()?;
    let milliseconds = (seconds * 1000.0).round() as i64;
    (milliseconds > 0).then_some(milliseconds)
}

async fn cleanup_directory(root: &Path) {
    let Ok(mut entries) = fs::read_dir(root).await else {
        return;
    };
    while let Ok(Some(entry)) = entries.next_entry().await {
        let _ = fs::remove_file(entry.path()).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_buffer_segment_timestamp() {
        let path = Path::new("20260820-101644.mp4");
        let parsed = buffered_segment_time(path).expect("timestamp");
        assert_eq!(
            parsed.format("%Y-%m-%d %H:%M:%S").to_string(),
            "2026-08-20 10:16:44"
        );
    }
}
