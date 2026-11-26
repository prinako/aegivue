# Continuous timeline streaming — implementation contract

## Current media compatibility

Aegivue currently records independent `.mp4` files via FFmpeg's segment
muxer, using `-reset_timestamps 1` and `-movflags +faststart` (see
`crates/media-engine/src/recording/recorder.rs`). These MP4 files cannot be
directly appended into a browser `MediaSource` as-is. The existing recording
player and Grid view must keep using the single-file playback URL.

## New client foundation

`apps/web/web/timeline_stream_player.js` adds `AegivueTimelineStream`, a
persistent MSE SourceBuffer owner with serialized appends and old-buffer
eviction. **It is deliberately not wired into the Flutter timeline yet.**
Using it on existing MP4 URLs would produce decode errors.

## Required delivery API before integration

Provide an authenticated, camera-scoped and timestamp-addressable endpoint
that remuxes indexed recordings to compatible fragmented MP4, including an
initialization segment and media fragments. Requirements:

- Remux (`-c copy`) when codecs and parameters allow, and fail explicitly
  for unsupported codec transitions; do not transcode silently.
- Emit valid fMP4 initialization data (`ftyp`/`moov`) and `moof`/`mdat`
  fragments with correct decode timestamps. Avoid mixing unrelated init
  segments and fragments in one SourceBuffer unless the browser supports
  `changeType()` and the change is handled explicitly.
- Maintain absolute camera timeline mapping in metadata: segment start/end,
  discontinuities, and codec identity. Respect real gaps; do not compress time.
- Enforce recording/camera authorization and expiry, backpressure, request
  cancellation, and bounded prefetch. Avoid fetching whole recording files.
- Support byte-range requests or equivalent chunked delivery and predictable
  cache headers. Reject incomplete `.mp4.partial` segments.
- Document a fallback for MSE-incompatible browsers/codecs.

## Flutter integration after the delivery API

Create a `TimelineStreamPlayer` widget that retains one HTML video element per
selected camera, across recording boundaries. The shared UTC coordinator
supplies seek targets and play/pause intent; fragment scheduling and the
SourceBuffer stay inside the dedicated player. Prebuffer only bounded lookahead,
evict buffered footage outside the retention window, and cancel stale fetches
when the user scrubs. Display a clear loading/gap/error state.

For transition to live near the edge, integrate MediaMTX LL-HLS separately.
Do not promise seamless transitions between incompatible media pipelines.

## Validation required

Test on Chrome and Firefox with real captured H.264/AAC segments, multiple
camera boundaries, actual gaps, timestamp discontinuities, seek cancellation,
codec changes, and memory/network measurements before replacing the deployed
timeline player.
