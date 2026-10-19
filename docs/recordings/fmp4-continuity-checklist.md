# Recording compatibility foundation

This branch builds on PR #96 and adds a conservative FFprobe-based stream
signature comparator. The comparator intentionally rejects transitions unless
video/audio layout and codec decoder configuration hashes match exactly.

## Current scope

- `probeMedia(file)` uses `ffprobe -show_streams -show_data_hash sha256`.
- `compatibleMedia(previous, next)` checks stream ordering, H.264 profile,
  level, dimensions, pixel format, audio properties, and extradata hashes.
- Unit tests cover profile, SPS/PPS, audio layout, and resolution mismatches.

**Not yet integrated into the fragment endpoint or browser player.** The
comparator is a foundational building block, not proof of MSE continuity.
Matching hashes are necessary but not sufficient for seamless append.

## Remaining acceptance tests before enabling Timeline playback

1. Use **real consecutive Aegivue MP4s** and independently probe both.
2. Verify actual `moov`/`moof`/`tfdt` decode timestamps after remux.
3. Build one persistent browser `MediaSource` and `SourceBuffer`, append
   initialization and media segments in order, map timestamps with
   `timestampOffset` or equivalent box-level normalization, and
   check monotonic decode/presentation timestamps including B-frame reorder.
4. Make gaps and overlaps explicit; do not misrepresent a wall-clock gap
   as continuously recorded footage.
5. Validate seek, cancellation, codec change, audio absence, and
   `QuotaExceededError` handling with bounded forward/backward buffering.
6. Only then connect Flutter Timeline. Preserve the existing Grid player.
7. Separately test LL-HLS live-edge handoff and backward seek.

Do not merge or deploy expecting continuous timeline playback until those
integration tests pass.
