# Browser MSE continuity harness

Open `/mse_continuity_harness.html` in an authenticated origin that can serve
fragmented MP4 files. This is an opt-in test page, not the Flutter player.

From the browser console:
```js
await runMseContinuity({
  mimeType: 'video/mp4; codecs="avc1.640028"',
  fragments: [
    { url: '/test/first.mp4', timestampOffset: 0, appendWindowStart: 0, appendWindowEnd: 10 },
    { url: '/test/second.mp4', timestampOffset: 10, appendWindowStart: 10, appendWindowEnd: 20 }
  ],
  expectedBoundary: 10
});
```
These are example URLs and offsets, **not validated camera media**. Supply values measured from the exact remuxed output, and verify matching init/decoder configuration. Each URL must be a compatible fMP4 response. The test checks that playback progresses past a boundary with one video element and a single SourceBuffer. This does not prove A/V sync, gap handling or continuous decoding on its own.

Remaining tests: use two actual adjacent Aegivue MP4s, FFmpeg copy-remux both, validate packet PTS/DTS and SPS/PPS hashes, test in Chromium/Firefox, test different H.264 profiles and true recording gaps. Record browser results and CI before enabling Flutter integration.

No browser test has been executed by this PR. This file is test infrastructure only.
