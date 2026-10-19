# Parser validation gate

This branch fixes optional `tfhd` field cursor handling and adds a focused regression fixture.

**Still blocked:** the parser has not been validated against two real adjacent Aegivue recording files, and its output has not been compared with FFprobe packet DTS/PTS. It is not integrated into the fragment streaming route.

Before exposing timing metadata:
- Verify emitted FFmpeg fMP4 box layouts, per-track `tfdt`, trun composition offsets and trex fallback.
- Validate byte bounds, unknown flags, timestamp precision, track edits and initialization changes.
- Only emit timing metadata after validating the corresponding remuxed bytes; avoid publishing timing derived from source packets as though it described output.
- Test a single persistent browser SourceBuffer across two recordings, with real gaps.

Keep draft until CI and real-media integration pass.
