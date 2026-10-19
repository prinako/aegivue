# Recordings

The **Recordings** dashboard route lists finalized footage after the media
engine has indexed its metadata. Active `.mp4.partial` files do not appear in
the library.

## Recording library

Recordings are ordered by start time, newest first. Each card shows a thumbnail,
camera ID, local start time, duration, container, retention or protection state,
and the resolution and file size when available. Select a card to open the
player and see available codec, resolution, frame-rate, retention, and
protection details.

The date filter, camera filter, **Grid / Timeline** control, and refresh action
are in the main Recordings header. On narrow screens the actions use a compact,
horizontally scrollable row instead of adding another page heading.

Use the **Grid / Timeline** control without leaving the Recordings route:

- **Grid** keeps the newest-first, virtualized card library and server-side
  pagination.
- **Timeline** shows one row for each selected or available camera. Colored
  tracks represent finalized footage; empty track areas have no indexed
  recording.

The 24-hour and 6-hour views merge overlapping and exactly adjacent intervals
for visualization only. Genuine gaps remain visible and the original recording
files and timestamps are unchanged. Selecting coverage resolves the clicked
local timestamp to an original recording; if multiple files overlap there, a
chooser preserves access to each one. The 1-hour view shows individual files,
using separate compact lanes only for genuine overlaps.

Disabled and offline cameras remain visible, and a selected camera
that is no longer registered is labeled unavailable when historical intervals
or the active filter still reference it. The timeline never assumes that a
registered camera has footage.

### Timeline dates and zoom

With no date filter, Timeline opens on the current local calendar day. Previous
day, **Today**, and next day change only the timeline viewport. The 24-hour,
6-hour, and 1-hour presets use fixed-width windows that fill the available
space; the timeline does not scroll horizontally. The 24-hour view contains the
whole selected day. In the narrower views, use **Previous window** and **Next
window** to move by six hours or one hour. Zoom focuses the window containing
the shared playback timestamp, or the current time when playback has not been
selected. Time ticks become more detailed with zoom, and today's timeline
includes a current-time marker. A local day runs from one local midnight to the
next, so a daylight-saving transition can contain 23 or 25 elapsed hours.

The Grid's date and camera filters are shared with Timeline. Camera selections
choose its rows and constrain its interval request. Date bounds are intersected
with the displayed local day. Timeline navigation and zoom do not rewrite or
clear those filters, so returning to Grid preserves the user's exact search.
The browser converts the resulting interval bounds to UTC for the API.

Selecting an interval opens the synchronized playback workspace below the
timeline. It creates players for up to the first four cameras in camera-ID
order, using the cameras selected by the filter or all cameras when **All
cameras** is active. Four is the current simultaneous-player limit, defined by
`RecordingTimelineViewModel.maximumSimultaneousPlayers`; use the camera filter
to choose a different group. A one-column grid is used on narrow screens and a
two-column grid on desktop. Cameras without footage at the shared timestamp
show **No footage** and do not create a video element.

The workspace has one UTC-based shared clock, global play and pause, a shared
timeline seek, and an amber shared playhead. Displayed timestamps are converted
to browser-local time. Each camera resolves the recording covering that clock
time and seeks by its own recording start offset. At a recording boundary it
resolves the next indexed file; a genuine gap remains a no-footage tile while
other cameras continue. If every camera is in a gap, the shared clock does not
start. Overlaps resolve deterministically by start time, end time, and recording
ID, while clicking overlapping coverage still offers the original alternatives.

Clicking within an individual or merged coverage segment seeks every active
camera to the represented timestamp. If media metadata is still loading, the
player queues the seek and applies it when the playable duration is known.
Browser seeking can land on the nearest decodable frame rather than the exact
requested millisecond, depending on the recording's keyframes and codec. The
coordinator corrects player drift greater than 750 milliseconds. Accuracy is
therefore best effort and remains subject to keyframe placement, decoding
performance, and browser scheduling. A browser may reject programmatic playback
until the user interacts with the page; the player reports that error and the
shared controls remain available for retry. Each camera also has independent
mute and fullscreen controls.

## Searching recordings

Use **All cameras** in the Recordings header to select one or more cameras by
name. Disabled and offline cameras remain available because their historical
recordings are still searchable. An empty selection, **Select all**, and
**Clear** all mean that no camera restriction is applied. A selected camera
that is no longer in the current camera list remains identified in the filter
until it is cleared.

Select **Filter by date** to set either or both time bounds:

- **From** alone includes recordings that start at or after that date and time.
- **To** alone includes recordings that start at or before that date and time.
- Setting both creates an inclusive custom range.
- Selecting the same date for both bounds, without times, searches that local
  calendar day.

A date without a time uses the start of the selected local day for **From** and
the end of the selected local day for **To**. Times shown in the library and
filter are local to the browser. The web client converts applied bounds to UTC
ISO-8601 timestamps before requesting the API.

Choose **Apply** to replace the results with the first filtered page. To remove
one bound, use its clear icon and then apply the remaining selection. Choose
**Clear** in the dialog to reset both immediately. When a filter is active, the
clear icon beside its label also resets both bounds. **Cancel** closes the
dialog without changing the current filter.

Filtering compares the recording's start time, not its entire duration. A
recording that starts before **From** is therefore excluded even if it continues
into the selected range. Camera and date filters combine with `AND`. The active
filters remain in effect during pull-to-refresh and while loading later pages.

## Playback and downloads

Select a recording card to open in-browser playback. The media endpoint supports
HTTP byte ranges so the player can seek within compatible recordings. Use the
download button on either the card or the open player to save the original
recording file.

Browser playback still depends on browser and operating-system codec support.
H.264 remains the recommended choice for the widest compatibility.

## Retention and protection

A camera's retention setting determines the initial expiry of newly finalized
recordings. Recordings from a camera without a retention period are kept
indefinitely. For an unprotected recording, open the player and use its expiry
control to choose a future date or clear an existing expiry to keep it
indefinitely. The dashboard presents expiry dates in local time and sends the
selected value to the API in UTC.

The retention worker periodically deletes expired, unprotected files and their
metadata. Protected recordings are skipped, and the dashboard disables their
expiry control. The recording library shows protection state but currently has
no control or public recordings endpoint for changing it.

## Pagination and performance

The dashboard requests 25 recordings at a time and automatically asks for the
next filtered page near the bottom of the grid. Filtering, ordering, counts, and
pagination are performed by PostgreSQL through the API.

Flutter's `SliverGrid.builder` constructs cards lazily instead of mounting a
widget for every loaded recording. This reduces the number of mounted cards,
but metadata for previously fetched pages remains in the view model and can
accumulate during a long browsing session. Lazy rendering does not guarantee a
fixed memory bound.

The filters remain in the application header while the grid scrolls, so they
stay available without consuming library content space.

## Recordings API

`GET /api/v1/recordings` returns recording metadata in newest-first order.

| Parameter | Description | Default and limits |
| --- | --- | --- |
| `page` | Requested page number | Default `1`; integer greater than or equal to `1` |
| `pageSize` | Number of recordings per page | Default `25`; integer from `1` through `100` |
| `from` | Inclusive lower bound on recording start time | Optional ISO-8601 timestamp with a timezone offset |
| `to` | Inclusive upper bound on recording start time | Optional ISO-8601 timestamp with a timezone offset |
| `cameraIds` | Camera IDs to match | Optional comma-separated list of valid camera IDs |

The API applies `cameraIds` to `camera_id` and `from` and `to` to `start_time`
in the database for both the page query and its count query. A recording may
match any requested camera, while camera and date constraints combine with
`AND`. The response uses the existing pagination envelope: `items`, `page`,
`pageSize`, `totalItems`, and `totalPages`. The totals therefore describe the
filtered result set.

The Flutter client serializes filter bounds in UTC with a `Z` suffix. Other API
clients may send any valid offset, such as `-03:00`; the offset must be URL-
encoded when necessary. For example:

```sh
curl --fail-with-body \
  'http://127.0.0.1:3000/api/v1/recordings?page=1&pageSize=25&cameraIds=front-door,garage&from=2026-10-17T08%3A00%3A00-03%3A00&to=2026-10-17T18%3A00%3A00-03%3A00'
```

Malformed timestamps, invalid camera IDs, page values outside their limits,
and ranges where `from` is later than `to` return HTTP `400` with error code
`VALIDATION_ERROR`.

### Timeline endpoint

`GET /api/v1/recordings/timeline` returns lightweight interval metadata for
recordings that overlap a requested UTC or offset-aware window. It does not
return thumbnails, file paths, or video data.

| Parameter | Description | Limits |
| --- | --- | --- |
| `from` | Start of the half-open window | Required ISO-8601 timestamp with an offset |
| `to` | End of the half-open window | Required ISO-8601 timestamp with an offset; must be after `from` |
| `cameraIds` | Camera IDs to match | Optional comma-separated valid IDs |

The maximum requested window is 31 elapsed days. The query includes recordings
that begin before the window and continue into it, end after it, or span it
completely. A missing `end_time` is derived only when indexed `duration_ms` is
available; incomplete rows without either value are omitted rather than shown
as fabricated availability. Results are ordered by start time and recording ID.

The endpoint fetches at most 5,001 database rows to detect overflow. If more
than 5,000 intervals match, it returns HTTP `422` with
`TIMELINE_RESULT_LIMIT`; clients must narrow the date or camera filter rather
than render a silently truncated timeline.

```json
{
  "items": [
    {
      "recordingId": "d01a30dc-9b3f-46de-a11b-5dc06d513f63",
      "cameraId": "front-door",
      "startTime": "2026-10-18T12:00:00.000Z",
      "endTime": "2026-10-18T12:05:00.000Z"
    }
  ]
}
```
