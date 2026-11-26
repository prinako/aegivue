# Persistent MSE recorded timeline coordinator (experimental)

`apps/web/web/timeline_fragment_coordinator.js` wraps the existing
`AegivueTimelineStream` and consumes the measured-fragment endpoint from PR
#104. It serializes requests, checks an externally verified codec fingerprint,
reads the per-track timing header, applies timestampOffset and appendWindow
settings, and preserves recording gaps. The underlying MSE SourceBuffer and
video element remain alive across appended windows.

**Not enabled in Flutter.** The existing Grid and Timeline UX remain unchanged.

Caveats: This is a browser-side prototype, not verified seamless playback.
Caller-provided fingerprints are not a substitute for server-verified SPS/PPS
and init segment compatibility. Real fMP4 init handling, DTS continuity,
edit lists, two-track A/V offsets, browser buffering/error recovery, real-camera
integration, and seeking around gaps still need testing. No automated
prebuffer scheduler or LL-HLS handoff yet.

Before merging: load two consecutive Aegivue recordings with compatible
configurations into the *same* SourceBuffer in actual Chromium and Firefox;
assert no freezes, reset, incorrect timestamps or A/V desynchronization.
