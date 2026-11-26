# Fragmented MP4 remux API (experimental)

`GET /api/v1/recordings/:id/fragment?startSeconds=0&durationSeconds=10`

The API resolves the recording from PostgreSQL and the configured recordings
volume, then remuxes an existing finalized MP4 with FFmpeg stream copy
(`-c copy`), sending a fresh fMP4 init segment and the requested media range
over an HTTP response.

- Query parameters: `startSeconds` (0–86400, default 0),
  `durationSeconds` (0.1–30, default 10).
- Existing API authentication and recording path checks apply.
- Remux requests are capped at four concurrent FFmpeg processes per API
  instance. Additional requests receive HTTP 503 with `Retry-After: 1`.
- Responses are streamed, with `Content-Type: video/mp4` and
  `Cache-Control: private, no-store`.
- The original MP4 is never modified. The Rust recording pipeline is unchanged.

## Known limitations

Each response contains its own fMP4 initialization segment, and `-ss` with
stream copy is keyframe-aligned. This endpoint alone **does not** guarantee
seamless concatenation in a single MSE SourceBuffer: the next phase must
normalize decode timestamps, initialization-segment changes, exact codec
compatibility, and discontinuities. Camera-provided codecs might not be
supported by MSE or the browser.

This is a bounded per-recording transport primitive, not yet an adaptive
playlist or production-ready multi-file playback solution. The Flutter
recording timeline still uses the previous player until integration and
real-media browser validation are completed.

## Validation

Verify output with `ffprobe` and Chrome/Firefox MSE playback using actual
Aegivue recordings. Test auth, invalid recording IDs, file absence, concurrent
requests, client cancellation, invalid codec, malformed fragments, and
recording gaps. The repository CI must pass before merge.
