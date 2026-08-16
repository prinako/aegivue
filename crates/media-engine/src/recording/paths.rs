use chrono::{DateTime, Datelike, NaiveDateTime, Timelike, Utc, Local};
use std::path::{Path, PathBuf};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum PathError {
    #[error("invalid camera storage key")]
    InvalidCameraKey,
}

pub fn camera_directory(
    root: &Path,
    camera_key: &str,
    at: DateTime<Local>,
) -> Result<PathBuf, PathError> {
    if camera_key.is_empty()
        || !camera_key
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-' || byte == b'_')
    {
        return Err(PathError::InvalidCameraKey);
    }
    Ok(root
        .join(camera_key)
        .join(format!("{:04}", at.year()))
        .join(format!("{:02}", at.month()))
        .join(format!("{:02}", at.day()))
        .join(format!("{:02}", at.hour())))
}

pub fn segment_path(
    root: &Path,
    camera_key: &str,
    at: DateTime<Utc>,
) -> Result<PathBuf, PathError> {
    Ok(camera_directory(root, camera_key, at)?.join(format!(
        "{:02}-{:02}-{:02}.mp4",
        at.hour(),
        at.minute(),
        at.second()
    )))
}

pub fn segment_time(root: &Path, camera_key: &str, path: &Path) -> Option<DateTime<Utc>> {
    let relative = path.strip_prefix(root.join(camera_key)).ok()?;
    let parts: Vec<_> = relative.iter().map(|part| part.to_str()).collect();
    if parts.len() != 5 || parts.iter().any(Option::is_none) {
        return None;
    }

    let filename = parts[4]?;
    let filename = filename
        .strip_suffix(".mp4.partial")
        .or_else(|| filename.strip_suffix(".mp4"))?;
    if !filename.starts_with(parts[3]?) {
        return None;
    }
    let value = format!(
        "{}-{}-{}T{}Z",
        parts[0]?,
        parts[1]?,
        parts[2]?,
        filename.replace('-', ":")
    );
    NaiveDateTime::parse_from_str(&value, "%Y-%m-%dT%H:%M:%SZ")
        .ok()
        .map(|value| value.and_utc())
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

    #[test]
    fn parses_segment_times_across_calendar_rollovers() {
        let root = Path::new("/data");
        for (path, expected) in [
            (
                "cam/2026/08/13/12/12-01-00.mp4.partial",
                "2026-08-13T12:01:00Z",
            ),
            (
                "cam/2026/08/13/13/13-00-00.mp4.partial",
                "2026-08-13T13:00:00Z",
            ),
            (
                "cam/2026/08/14/00/00-00-00.mp4.partial",
                "2026-08-14T00:00:00Z",
            ),
            (
                "cam/2026/09/01/00/00-00-00.mp4.partial",
                "2026-09-01T00:00:00Z",
            ),
            (
                "cam/2027/01/01/00/00-00-00.mp4.partial",
                "2027-01-01T00:00:00Z",
            ),
        ] {
            assert_eq!(
                segment_time(root, "cam", &root.join(path)).unwrap(),
                DateTime::parse_from_rfc3339(expected)
                    .unwrap()
                    .with_timezone(&Utc)
            );
        }
    }

    #[test]
    fn parses_finalized_segment_time() {
        let root = Path::new("/data");
        let path = root.join("cam/2026/08/13/12/12-01-00.mp4");
        assert_eq!(
            segment_time(root, "cam", &path).unwrap(),
            DateTime::parse_from_rfc3339("2026-08-13T12:01:00Z")
                .unwrap()
                .with_timezone(&Utc)
        );
    }
}
