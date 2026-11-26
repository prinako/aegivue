# Real camera MSE validation (manual, opt-in)

The script `apps/web/test_js/mse_real_recordings.mjs` takes two actual finalized H.264 MP4 recording paths, probes video stream compatibility including extradata hash, remuxes to fMP4 using FFmpeg stream copy, and runs the same Google Chrome MSE boundary test used by CI.

It **does not** run in ordinary CI because no private camera recordings are committed to the repository. Install Playwright and Google Chrome as in `.github/workflows/mse-browser-smoke.yml`; FFmpeg and FFprobe must be on PATH.

Example, from the repository root (paths are illustrative):

```bash
AEGIVUE_MSE_MIME='video/mp4; codecs="avc1.42C01E"' \
  node apps/web/test_js/mse_real_recordings.mjs /path/to/first.mp4 /path/to/second.mp4
```

Determine the actual avc1 codec string from the clips' AVC decoder configuration rather than copying the example. The script rejects differing profiles, levels, resolutions, pixel formats and extradata hashes. It validates video only and artificially joins the two fragment timelines; **this does not validate actual wall-clock recording gaps, audio synchronization, authenticated API fetches, or full Flutter integration**.

The files are read locally, never uploaded. Neither real-file testing nor Firefox verification has yet been performed. Do not enable the persistent Timeline player in production until those acceptance tests pass.
