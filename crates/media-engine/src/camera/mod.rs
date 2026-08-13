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
            | (Online, Degraded)
            | (Online, Stopping)
            | (Degraded, Online)
            | (Degraded, Reconnecting)
            | (Reconnecting, Connecting)
            | (Reconnecting, Offline)
            | (Offline, Starting)
            | (Stopping, Disabled)
            | (_, Error)
    );
    valid.then_some(to).ok_or(TransitionError { from, to })
}

pub fn reconnect_delay(attempt: u32) -> Duration {
    Duration::from_secs(2_u64.saturating_pow(attempt.min(5)).min(30))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_impossible_transition() {
        assert!(transition(CameraState::Disabled, CameraState::Online).is_err());
    }
    #[test]
    fn caps_backoff() {
        assert_eq!(reconnect_delay(99), Duration::from_secs(30));
    }
}
