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

## Searching recordings

Select **Filter by date** above the grid to set either or both bounds:

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
into the selected range. The active filter remains in effect during pull-to-
refresh and while loading later pages.

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

The date filter and library heading remain outside the scrolling grid so the
filter stays available while browsing.

## Recordings API

`GET /api/v1/recordings` returns recording metadata in newest-first order.

| Parameter | Description | Default and limits |
| --- | --- | --- |
| `page` | Requested page number | Default `1`; integer greater than or equal to `1` |
| `pageSize` | Number of recordings per page | Default `25`; integer from `1` through `100` |
| `from` | Inclusive lower bound on recording start time | Optional ISO-8601 timestamp with a timezone offset |
| `to` | Inclusive upper bound on recording start time | Optional ISO-8601 timestamp with a timezone offset |

The API applies `from` and `to` to `start_time` in the database for both the
page query and its count query. The response uses the existing pagination
envelope: `items`, `page`, `pageSize`, `totalItems`, and `totalPages`. The totals
therefore describe the filtered result set.

The Flutter client serializes filter bounds in UTC with a `Z` suffix. Other API
clients may send any valid offset, such as `-03:00`; the offset must be URL-
encoded when necessary. For example:

```sh
curl --fail-with-body \
  'http://127.0.0.1:3000/api/v1/recordings?page=1&pageSize=25&from=2026-10-17T08%3A00%3A00-03%3A00&to=2026-10-17T18%3A00%3A00-03%3A00'
```

Malformed timestamps, page values outside their limits, and ranges where
`from` is later than `to` return HTTP `400` with error code
`VALIDATION_ERROR`.
