# FFmpeg / FFprobe timing integration

The new integration test generates a deterministic two-second, 10 FPS MPEG-4 Part 2 video with FFmpeg, with keyframes every 10 frames, remuxed directly as fragmented MP4. It compares sample count, first DTS, first PTS and last packet presentation end against FFprobe output. FFmpeg and FFprobe must be installed in CI for this test to run; Vitest skips it if either binary is missing.

This validates **generated fMP4 parser output** rather than merely synthetic box fixtures. It does not yet exercise H.264 B-frame composition offsets, AAC audio, actual Aegivue camera recordings, the current recording endpoint, or browser MSE.

## Acceptance gate before API integration

1. Verify this test runs (not skipped) and passes in an FFmpeg-equipped CI job.
2. Run against two representative real Aegivue MP4 recordings (with video and audio where present), with an FFmpeg copy-remux using the same endpoint arguments.
3. Compare per-track PTS, DTS, duration and init/extradata compatibility.
4. Only then expose validated timing metadata in the API and build a persistent SourceBuffer coordinator.
