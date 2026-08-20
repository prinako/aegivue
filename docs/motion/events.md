# Motion detection and events

Aegivue now has a first-pass motion-detection pipeline in the Rust media engine and exposes persisted events through the API and Flutter dashboard.

## What is implemented

For each camera with motion detection enabled, the media engine starts a supervised motion-analysis task alongside live viewing and recording. The detector uses the camera's configured motion stream (`main` or `sub`), analysis FPS, and sensitivity.

The current detector:

- opens the selected RTSP stream with FFmpeg;
- downsamples video to 160×90 grayscale frames;
- compares consecutive frames using changed-pixel ratio;
- maps camera sensitivity to a trigger threshold;
- creates a PostgreSQL `motion` event when the score crosses the threshold;
- updates the event with the highest observed motion score;
- closes the event after roughly two seconds of quiet frames;
- stores detector metadata such as stream, analysis FPS, sensitivity, and analysis resolution.

The detector is supervised independently. A detector failure schedules a restart and should not stop the camera recorder or live-view publisher.

When recording mode is `motion`, an active motion event also controls the event
recorder. Aegivue promotes completed segments from the rolling pre-event buffer,
records while the event is active, continues through the configured post-event
window, and links the resulting recording metadata to the event.

## Camera settings

Motion settings are part of the existing camera configuration:

- `enabled` — enable or disable motion analysis;
- `stream` — choose `main` or `sub` for analysis;
- `fps` — analysis frame rate, from 0.1 to 30 FPS;
- `sensitivity` — normalized sensitivity from 0 to 1.

When `stream` is `sub`, the camera must have a substream configured.

The current implementation is intentionally lightweight and analyzes the whole 160×90 frame. Motion zones and exclusion zones are represented in the database schema but are not yet applied by the detector.

## Event lifecycle

A motion event is stored in the `events` table with:

- `camera_id`;
- `kind = motion`;
- `started_at` and `ended_at`;
- the peak `score` observed while the event is active;
- JSON metadata describing the detector configuration.

A typical event metadata payload looks like:

```json
{
  "detector": "frame-difference-v1",
  "stream": "sub",
  "analysisFps": 5.0,
  "sensitivity": 0.65,
  "width": 160,
  "height": 90
}
```

## Events API

The API exposes persisted events at `/api/v1/events`.

List events:

```http
GET /api/v1/events?page=1&pageSize=25
```

Optional filters:

```http
GET /api/v1/events?kind=motion&cameraId=front-door&page=1&pageSize=25
```

Read one event:

```http
GET /api/v1/events/<event-id>
```

The response includes the camera ID and name, event kind, start/end time, score, and detector metadata.

## Flutter Motion events view

The Flutter dashboard includes a **Motion events** destination on desktop and mobile. It displays persisted motion events with:

- camera name;
- event timestamp;
- active or ended state;
- duration for completed events;
- peak motion score;
- analysis stream;
- analysis FPS;
- sensitivity;
- detector name.

The view supports refresh and paginated/infinite-scroll loading.

## Motion-triggered recording

Set `recording.mode` to `motion` to avoid running the main recorder continuously.
The media engine then:

1. keeps a rolling, one-second-segment pre-event buffer when
   `preEventSeconds > 0`;
2. starts the main recorder when it observes an open motion event;
3. promotes closed prebuffer segments that fall inside the configured window;
4. continues recording for `postEventSeconds` after the detector closes the event;
5. finalizes segments and links them to the triggering event.

The prebuffer is transient and stored below `.prebuffer` in the recording storage.
Its newest segment is never promoted because FFmpeg may still be writing it. If
the prebuffer cannot start, motion recording can still begin at the trigger, but
pre-event footage will be unavailable.

## Current limitations

This is the first motion-processing implementation. The following are not yet complete:

- motion zones and exclusion-zone scoring;
- illumination-change and environmental false-positive suppression;
- configurable temporal debounce / quiet period;
- recovery of stale open events after unexpected process termination;
- object/AI detection and event enrichment.

## Troubleshooting

Start with media-engine logs:

```sh
docker compose logs --tail=200 aegivue-media
```

A successful trigger includes a message similar to:

```text
motion event started
```

with `camera_id`, `event_id`, `score`, and `threshold` fields. When the scene becomes quiet, the same event should later log:

```text
motion event ended
```

To inspect recent motion events directly in PostgreSQL with the stock Compose stack:

```sh
docker compose exec aegivue-postgres \
  psql -U aegivue -d aegivue \
  -c "SELECT id, camera_id, kind, started_at, ended_at, score, metadata FROM events WHERE kind='motion' ORDER BY started_at DESC LIMIT 20;"
```

For customized deployments, use the actual PostgreSQL service or container name for that stack.
