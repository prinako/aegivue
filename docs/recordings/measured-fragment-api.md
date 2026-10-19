# Measured fMP4 fragment response (experimental)

`GET /api/v1/recordings/:id/fragment/measured?startSeconds=0&durationSeconds=10`

Uses existing auth, recording lookup and path checks. Separately from the
legacy streaming route, remuxes a bounded window into memory, parses timing
from exactly the emitted MP4 bytes, and returns `Content-Type: video/mp4`
plus `X-Recording-Timing-Base64` (base64url-encoded JSON).

Decoded example shape:
```json
{
  "requestedStartSeconds": 0,
  "tracks": [{
    "trackId": 1, "timescale": 1000,
    "firstDecodeSeconds": 0, "firstPresentationSeconds": 0,
    "endPresentationSeconds": 10, "samples": 250
  }]
}
```
Numbers above illustrate schema only, not actual recordings.

Limits: 32 MiB total output, 30-second FFmpeg timeout, two simultaneous
measured remuxes per API process; abort cancels the FFmpeg subprocess. The
existing `/fragment` streaming endpoint is unchanged.

Caveats: This is **not production-ready**. Header size is not independently
bounded and may be large for unusually many tracks. FFmpeg stderr is ignored
in this experimental path. The parser does not yet address edit lists, all
fragment layout variants, or verified actual camera files. Media is buffered
rather than streamed and may incur latency/memory pressure. Browser MSE
continuity and Flutter are not implemented.

Acceptance: real Aegivue MP4 files; ffprobe comparison on each track; API
authentication, cancellation, large output, codec change, malformed input,
and browser tests across adjacent recordings. Keep draft until complete.
