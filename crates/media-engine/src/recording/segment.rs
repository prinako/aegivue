use chrono::{DateTime, Utc};
use std::path::PathBuf;

#[derive(Debug)]
pub struct Segment {
    pub path: PathBuf,
    pub started_at: DateTime<Utc>,
}
