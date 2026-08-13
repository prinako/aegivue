use chrono::{DateTime, Datelike, Timelike, Utc};
use std::path::{Path, PathBuf};
use thiserror::Error;
#[derive(Debug, Error)]
pub enum PathError {
    #[error("invalid camera storage key")]
    InvalidCameraKey,
}
pub fn segment_path(
    root: &Path,
    camera_key: &str,
    at: DateTime<Utc>,
) -> Result<PathBuf, PathError> {
    if camera_key.is_empty()
        || !camera_key
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
    {
        return Err(PathError::InvalidCameraKey);
    }
    Ok(root
        .join(camera_key)
        .join(format!("{:04}", at.year()))
        .join(format!("{:02}", at.month()))
        .join(format!("{:02}", at.day()))
        .join(format!("{:02}", at.hour()))
        .join(format!(
            "{:02}-{:02}-{:02}.mp4",
            at.hour(),
            at.minute(),
            at.second()
        )))
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn path_is_hierarchical() {
        let at = DateTime::parse_from_rfc3339("2026-08-13T14:20:00Z")
            .unwrap()
            .with_timezone(&Utc);
        assert_eq!(
            segment_path(Path::new("/data"), "front-door", at).unwrap(),
            PathBuf::from("/data/front-door/2026/08/13/14/14-20-00.mp4")
        );
    }
    #[test]
    fn blocks_traversal() {
        assert!(segment_path(Path::new("/data"), "../bad", Utc::now()).is_err());
    }
}
