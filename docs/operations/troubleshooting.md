# Troubleshooting runbook

Use this guide from the symptom outward. Run commands from the repository root and
avoid posting raw environment output or camera URLs publicly because they may
contain credentials.

## First response

Capture service state before restarting anything:

```sh
docker compose ps
docker compose logs --since=15m --tail=300 \
  aegivue-api aegivue-media aegivue-webrtc aegivue-web
curl --fail http://127.0.0.1:3000/api/v1/health
```

Then identify whether the failure is global, limited to one service, or limited to
one camera. A single-camera failure usually points to reachability, credentials,
codec compatibility, or that camera's worker rather than PostgreSQL or the API.

## Service will not start

1. Validate configuration: `docker compose config --quiet`.
2. Check the failed container's exit status and health in `docker compose ps`.
3. Read its earliest error, not only the final restart message.
4. Confirm ports `3000`, `8080`, and UDP `8189` are not already claimed.
5. Verify the database password is consistent with the existing PostgreSQL volume.

If the migration job fails, do not repeatedly restart application services. Fix
the migration or database connection first, then run:

```sh
docker compose run --rm aegivue-migrate
docker compose up -d
```

## API is unavailable

Check the API directly to separate it from the web proxy:

```sh
curl -v http://127.0.0.1:3000/api/v1/health
docker compose logs --tail=200 aegivue-api
```

- Connection refused usually means the container is down or the bind address is
  wrong.
- HTTP `5xx` with PostgreSQL errors points to database reachability or schema
  mismatch.
- The API works directly but not through the dashboard points to Nginx proxying or
  browser-origin configuration.

## Camera remains offline

```sh
curl --fail http://127.0.0.1:3000/api/v1/cameras/<camera-id>/status
docker compose logs --tail=200 aegivue-media
```

Verify, in order:

1. The camera is enabled and its host is reachable from the Docker host.
2. The RTSP port, credentials, and exact vendor stream path are correct.
3. Routing and firewall rules allow the media engine onto the camera network.
4. The camera has not reached its concurrent RTSP session limit.
5. Its stream codec can be consumed by the installed FFmpeg build.

See [Adding an RTSP camera](../cameras/rtsp.md) for request examples and codec
guidance.

## Recording is missing or unplayable

Check media logs and recent indexed recordings:

```sh
docker compose logs --tail=300 aegivue-media
curl --fail 'http://127.0.0.1:3000/api/v1/recordings?page=1&pageSize=25'
```

- A `.mp4.partial` file is active or was interrupted; it is not a finalized
  recording.
- Files on disk but absent from the API indicate finalization, probing, or database
  indexing failed.
- Metadata in PostgreSQL but a missing file indicates a storage mount, manual
  deletion, or consistency problem.
- Immediate disappearance may indicate retention or expiry settings.

Confirm both API and media containers mount the same recording volume. Do not
delete partial files while FFmpeg is still running.

## Live view fails

Test the HLS fallback first:

```sh
curl --fail http://127.0.0.1:8080/live/<camera-id>/index.m3u8
docker compose logs --tail=200 aegivue-webrtc aegivue-web
```

| Observation | Likely area |
| --- | --- |
| HLS and WebRTC both fail | Camera publisher, MediaMTX path, or web proxy |
| HLS works, WebRTC fails | Advertised host, UDP `8189`, firewall, or NAT |
| Works on host, not another device | Localhost bind or unreachable WebRTC candidate |
| Audio/video unsupported in browser | Camera codec compatibility |

Set `AEGIVUE_WEBRTC_HOST` to an address reachable by the browser and allow UDP
`8189` to the Docker host. H.264 is the safest browser-facing video codec.

## Motion events do not appear

1. Confirm motion detection is enabled for the camera.
2. If analysis uses `sub`, confirm a substream exists and is reachable.
3. Check media logs for detector start, restart, and FFmpeg errors.
4. Temporarily increase sensitivity or analysis FPS to distinguish configuration
   from pipeline failure.
5. Query recent events through `/api/v1/events?kind=motion`.

See [Motion detection and events](../motion/events.md) for score behavior and
current detector limitations.

## Database schema mismatch

Errors such as `column ... does not exist` mean code and schema versions differ.
Inspect applied migrations before changing tables manually:

```sh
docker compose exec aegivue-postgres \
  psql -U aegivue -d aegivue \
  -c "SELECT name, applied_at FROM schema_migrations ORDER BY applied_at;"
```

Follow the [upgrade and migration guide](upgrades.md) to restore version alignment.

## Storage or permission errors

Check available space and mount ownership on the host. For bind-mounted storage,
the configured `PUID` and `PGID` must be able to create directories, write partial
segments, rename finalized files, and remove expired recordings. Avoid broad
permission changes; correct ownership on the specific recording directory.

## Escalation checklist

Collect these details before opening an issue:

- Aegivue image tag or Git commit
- Host OS, architecture, Docker, and Compose versions
- `docker compose ps` output
- Redacted logs covering the first failure
- Whether all cameras or one camera are affected
- Camera video codec and stream resolution
- Exact reproduction steps and expected behavior

Remove passwords, embedded RTSP credentials, public IP addresses, and other
sensitive deployment details.
