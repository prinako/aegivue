use rand::Rng;
use std::time::Duration;

pub fn delay(attempt: u32) -> Duration {
    let jitter = rand::rng().random_range(0..=1_000);
    crate::camera::state::reconnect_delay(attempt, jitter)
}
