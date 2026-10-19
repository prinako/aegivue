# MSE timestamp mapping (experimental)

This branch introduces a **pure timeline planner**, not a full media remux or browser player.

`planRecordingAppend(originUtcMs, recording, fragment, previousEndSeconds)`
maps a probed fragment's **measured first presentation timestamp** to a common
wall-clock timeline; it gives a `timestampOffset` and append windows. It
preserves actual gaps and clips overlapping ranges. Call `applyAppendPlan`
only after waiting for SourceBuffer `updateend`.

## Critical limitations

- The current API's FFmpeg `-ss` remux does **not** measure or expose actual
  first PTS, segment packet duration, edit lists, `tfdt`, or decode time.
- The planner assumes that supplied fragment duration matches the actual
  portion of a recording starting at `startTime`; this is **not guaranteed**.
- For H.264 B-frames, presentation timestamps alone do not establish decode
  continuity. Check `tfdt`, composition offsets, and random-access boundaries.
- `timestampOffset` is an MSE application-side adjustment. It does not
  rewrite MP4 boxes and is not necessarily sufficient to append separate
  FFmpeg outputs continuously.
- A single SourceBuffer may reject initialization segment changes even for
  nominally matching codecs. Browser behavior needs verification.
- No persistent MSE player is wired up. No Flutter, Grid or LL-HLS changes.

## Acceptance gate

Generate two **real adjacent camera recordings** and inspect both source MP4s
and remuxed outputs with FFprobe/MP4 parsing. Verify true per-track timescales,
init compatibility, first DTS/PTS and keyframe alignment. Append both to one
persistent SourceBuffer in Chromium and Firefox; assert uninterrupted timeupdate
progress, correct A/V sync, no false gap compression, and recovery from actual
recording gaps. Test seek and cancellation as well. Do not merge as completed
continuous playback before these pass.
