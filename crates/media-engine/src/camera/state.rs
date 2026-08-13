use std::time::Duration;
use thiserror::Error;
use vigilo_common::CameraState;

#[derive(Debug, Error, PartialEq, Eq)]
#[error("invalid camera transition from {from:?} to {to:?}")]
pub struct TransitionError {
    from: CameraState,
    to: CameraState,
}

pub fn transition(from: CameraState, to: CameraState) -> Result<CameraState, TransitionError> {
    use CameraState::*;
    let valid = matches!(
        (from, to),
        (Disabled, Starting)
            | (Starting, Connecting)
            | (Connecting, Online)
            | (Connecting, Reconnecting)
            | (Connecting, Offline)
            | (Online, Degraded)
            | (Online, Reconnecting)
            | (Online, Stopping)
            | (Degraded, Online)
            | (Degraded, Reconnecting)
            | (Degraded, Stopping)
            | (Reconnecting, Connecting)
            | (Reconnecting, Offline)
            | (Reconnecting, Stopping)
            | (Offline, Starting)
            | (Offline, Stopping)
            | (Stopping, Disabled)
            | (_, Error)
    );
    valid.then_some(to).ok_or(TransitionError { from, to })
}

pub fn reconnect_delay(attempt: u32, jitter_millis: u64) -> Duration {
    let base = 2_u64.saturating_pow(attempt.min(5)).min(30);
    Duration::from_millis(base * 1_000 + jitter_millis.min(1_000))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_impossible_transition() {
        assert!(transition(CameraState::Disabled, CameraState::Online).is_err());
    }

    #[test]
    fn caps_backoff_and_jitter() {
        assert_eq!(reconnect_delay(99, 5_000), Duration::from_secs(31));
    }
}
