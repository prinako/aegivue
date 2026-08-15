use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    process::Child,
    time::{Duration, timeout},
};

const MAX_LOG_LINE_BYTES: usize = 2_048;

pub fn log_stderr(
    child: &mut Child,
    camera_id: &str,
    process: &'static str,
    username: Option<&str>,
    password: Option<&str>,
) {
    let Some(mut stderr) = child.stderr.take() else {
        return;
    };
    let camera_id = camera_id.to_owned();
    let username = username.map(str::to_owned);
    let password = password.map(str::to_owned);

    tokio::spawn(async move {
        let mut chunk = [0_u8; 1_024];
        let mut line = Vec::with_capacity(MAX_LOG_LINE_BYTES);
        let mut truncated = false;

        loop {
            match stderr.read(&mut chunk).await {
                Ok(0) => {
                    emit_line(&camera_id, process, &username, &password, &line, truncated);
                    break;
                }
                Ok(read) => {
                    for &byte in &chunk[..read] {
                        if byte == b'\n' {
                            emit_line(&camera_id, process, &username, &password, &line, truncated);
                            line.clear();
                            truncated = false;
                        } else if line.len() < MAX_LOG_LINE_BYTES {
                            line.push(byte);
                        } else {
                            truncated = true;
                        }
                    }
                }
                Err(error) => {
                    tracing::debug!(camera_id, process, %error, "unable to read FFmpeg diagnostics");
                    break;
                }
            }
        }
    });
}

pub async fn terminate(child: &mut Child, camera_id: &str, process: &'static str) {
    if let Some(mut stdin) = child.stdin.take() {
        let _ = stdin.write_all(b"q\n").await;
        let _ = stdin.shutdown().await;
    }

    if timeout(Duration::from_secs(2), child.wait()).await.is_ok() {
        return;
    }
    tracing::warn!(
        camera_id,
        process,
        "FFmpeg did not exit within shutdown timeout"
    );
    let _ = child.start_kill();
    let _ = timeout(Duration::from_secs(2), child.wait()).await;
}

fn emit_line(
    camera_id: &str,
    process: &'static str,
    username: &Option<String>,
    password: &Option<String>,
    bytes: &[u8],
    truncated: bool,
) {
    if bytes.is_empty() {
        return;
    }
    let message = String::from_utf8_lossy(bytes);
    let message = sanitize_diagnostic(&message, username.as_deref(), password.as_deref());
    tracing::warn!(camera_id, process, truncated, message, "FFmpeg diagnostic");
}

pub(crate) fn sanitize_diagnostic(
    message: &str,
    username: Option<&str>,
    password: Option<&str>,
) -> String {
    let mut sanitized = redact_rtsp_urls(message);
    for secret in [username, password]
        .into_iter()
        .flatten()
        .filter(|value| !value.is_empty())
    {
        sanitized = sanitized.replace(secret, "[REDACTED]");
        sanitized = sanitized.replace(&percent_encode(secret), "[REDACTED]");
    }
    for key in [
        "password=",
        "password:",
        "passwd=",
        "token=",
        "authorization:",
    ] {
        sanitized = redact_value_after(&sanitized, key);
    }
    sanitized
}

fn redact_rtsp_urls(message: &str) -> String {
    let mut remaining = message;
    let mut result = String::with_capacity(message.len());
    while let Some(start) = remaining.to_ascii_lowercase().find("rtsp://") {
        result.push_str(&remaining[..start]);
        result.push_str("rtsp://[REDACTED]");
        let url = &remaining[start..];
        let end = url
            .char_indices()
            .find_map(|(index, character)| character.is_whitespace().then_some(index))
            .unwrap_or(url.len());
        remaining = &url[end..];
    }
    result.push_str(remaining);
    result
}

fn redact_value_after(message: &str, key: &str) -> String {
    let lower = message.to_ascii_lowercase();
    let Some(start) = lower.find(key) else {
        return message.to_owned();
    };
    let value_start = start + key.len();
    let value_end = message[value_start..]
        .char_indices()
        .find_map(|(index, character)| {
            (character.is_whitespace() || matches!(character, ',' | ';'))
                .then_some(value_start + index)
        })
        .unwrap_or(message.len());
    format!(
        "{}{}[REDACTED]{}",
        &message[..start],
        &message[start..value_start],
        &message[value_end..]
    )
}

fn percent_encode(value: &str) -> String {
    value
        .bytes()
        .map(|byte| match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => {
                (byte as char).to_string()
            }
            _ => format!("%{byte:02X}"),
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn removes_rtsp_urls_and_passwords_from_diagnostics() {
        let diagnostic = "[rtsp] failed rtsp://alice:p%40ss@camera:554/live password=p@ss";
        let sanitized = sanitize_diagnostic(diagnostic, Some("alice"), Some("p@ss"));
        assert_eq!(
            sanitized,
            "[rtsp] failed rtsp://[REDACTED] password=[REDACTED]"
        );
        assert!(!sanitized.contains("alice"));
        assert!(!sanitized.contains("p%40ss"));
    }

    #[test]
    fn keeps_non_secret_failure_context() {
        assert_eq!(
            sanitize_diagnostic("Connection timed out after 10000 ms", None, None),
            "Connection timed out after 10000 ms"
        );
    }
}
