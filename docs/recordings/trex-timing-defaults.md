# MP4 trex timing fallback

Fragment sample durations follow the ISO BMFF precedence: `trun` per-sample duration, then `tfhd` default, then `moov/mvex/trex` default. Missing or zero durations are rejected. Synthetic tests cover fallback, precedence and malformed zero defaults.

## Still required

- Validate this parser against FFmpeg's real fragmented MP4 output from Aegivue recordings.
- Compare timestamps with FFprobe, including AVC B-frames and AAC, multi-trun and multi-moof fragments.
- Handle edit lists and `tfhd` flag semantics and ensure safe numeric ranges before feeding the MSE player.
- Integrate authoritative metadata into the API (stream response format still unchanged).
- Prove continuous playback in one persistent SourceBuffer.

This change is a conservative parser improvement, **not** an integrated streaming or playback solution.
