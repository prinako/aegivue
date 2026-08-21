use std::{path::{Path, PathBuf}, process::Stdio};
use tokio::{fs, process::Command};

const THUMBNAIL_WIDTH: &str = "640";

pub async fn ensure_thumbnail(storage: &Path, recording: &Path) -> Result<PathBuf, String> {
    let target = thumbnail_path(storage, recording)?;
    if fs::try_exists(&target).await.unwrap_or(false) {
        return Ok(target);
    }

    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)
            .await
            .map_err(|error| error.to_string())?;
    }

    let temp = target.with_extension("jpg.partial");
    let _ = fs::remove_file(&temp).await;

    let output = Command::new("ffmpeg")
        .args([
            "-hide_banner",
            "-loglevel",
            "warning",
            "-ss",
            "0.5",
            "-i",
        ])
        .arg(recording)
        .args([
            "-frames:v",
            "1",
            "-vf",
            &format!("scale={THUMBNAIL_WIDTH}:-2"),
            "-q:v",
            "4",
            "-f",
            "image2",
        ])
        .arg(&temp)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .output()
        .await
        .map_err(|error| error.to_string())?;

    if !output.status.success() {
        let _ = fs::remove_file(&temp).await;
        return Err(String::from_utf8_lossy(&output.stderr).trim().to_string());
    }

    let metadata = fs::metadata(&temp)
        .await
        .map_err(|error| error.to_string())?;
    if metadata.len() == 0 {
        let _ = fs::remove_file(&temp).await;
        return Err("generated thumbnail is empty".to_string());
    }

    fs::rename(&temp, &target)
        .await
        .map_err(|error| error.to_string())?;
    Ok(target)
}

pub fn thumbnail_path(storage: &Path, recording: &Path) -> Result<PathBuf, String> {
    let relative = recording
        .strip_prefix(storage)
        .map_err(|_| "recording path is outside storage root".to_string())?;
    let mut target = storage.join(".thumbnails").join(relative);
    target.set_extension("jpg");
    Ok(target)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn thumbnail_path_mirrors_recording_tree() {
        let storage = Path::new("/data/recordings");
        let recording = Path::new("/data/recordings/front-door/2026/08/21/13/13-20-00.mp4");
        let thumbnail = thumbnail_path(storage, recording).expect("thumbnail path");
        assert_eq!(
            thumbnail,
            Path::new("/data/recordings/.thumbnails/front-door/2026/08/21/13/13-20-00.jpg")
        );
    }
}
