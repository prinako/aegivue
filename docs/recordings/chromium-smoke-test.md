# Experimental Chromium MSE boundary smoke test

This adds an **opt-in** GitHub Actions job that generates two real FFmpeg fMP4 files, serves the existing MSE continuity harness, and checks playback passes the boundary in headless Chromium using a single SourceBuffer. This is synthetic media, **not two Aegivue camera recordings**. The job must complete successfully before any passing claim.

Use the workflow's manual dispatch or run it on changes to the harness/test files. A dedicated browser test is intentionally separate from the normal API/Flutter/Rust CI. Verify codec support in the runner; differing ffmpeg/libx264 builds can change codec parameters. If the browser rejects the generated init segment, inspect file codec strings and timing rather than weakening checks.

Acceptance for actual production: real adjacent camera clips (including optional AAC), measured DTS/PTS verification, correct init segments, gaps, browser Chromium and Firefox results, and CI passing. No Flutter integration or production deployment.
