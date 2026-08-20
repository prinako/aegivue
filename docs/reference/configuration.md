# Configuration reference

Aegivue reads deployment settings from environment variables. For Docker Compose,
copy `.env.example` to `.env`; Compose maps the relevant values into each service.

```sh
cp .env.example .env
docker compose config --quiet
```

> [!CAUTION]
> `.env` contains database credentials. Keep it out of version control and limit
> filesystem access to the deployment operator.

## Required values

| Variable | Used by | Description |
| --- | --- | --- |
| `AEGIVUE_POSTGRES_PASSWORD` | Compose, PostgreSQL, migration runner | Database password. Replace the example value before startup. |
| `AEGIVUE_DATABASE_URL` | API, media engine, migrations | PostgreSQL connection URL. Compose constructs an internal URL from the password; the example value is useful for host-run processes. |

## Host exposure

| Variable | Default | Description |
| --- | --- | --- |
| `AEGIVUE_API_BIND` | `127.0.0.1` | Host address publishing API port `3000`. |
| `AEGIVUE_WEB_BIND` | `127.0.0.1` | Host address publishing web port `8080`. |
| `AEGIVUE_WEBRTC_HOST` | `127.0.0.1` | Address advertised to browsers as a WebRTC candidate. Use a reachable LAN IP or DNS name for remote clients. |
| `AEGIVUE_WEBRTC_ICE_BIND` | `0.0.0.0` | Host address publishing UDP port `8189`. |
| `AEGIVUE_TRUST_PROXY` | `false` | Enables trusted-proxy behavior in Fastify. Enable only with a correctly configured reverse proxy. |

Changing exposure settings requires recreating the affected containers:

```sh
docker compose up -d --force-recreate aegivue-api aegivue-webrtc aegivue-web
```

## Runtime settings

| Variable | Default | Validation / purpose |
| --- | --- | --- |
| `AEGIVUE_LOG_LEVEL` | `info` | Application and MediaMTX log verbosity. |
| `AEGIVUE_RECORDING_SEGMENT_SECONDS` | `60` | Segment duration in seconds; media engine accepts `5` through `3600`. |
| `AEGIVUE_IMAGE_TAG` | `latest` | Tag used for the API, media, and web images. Pin a release or commit tag for reproducible deployments. |
| `PUID` | `1000` | Host user ID used by containers where configured. |
| `PGID` | `1000` | Host group ID used by containers where configured. |

## Service-internal settings

The stock Compose file supplies these values. Most operators should not override
them unless changing the topology.

| Variable | Compose value | Purpose |
| --- | --- | --- |
| `AEGIVUE_API_HOST` | `0.0.0.0` | API listen address inside its container. |
| `AEGIVUE_API_PORT` | `3000` | API listen port inside its container. |
| `AEGIVUE_MEDIA_URL` | `http://aegivue-media:3010` | API-to-media control endpoint. |
| `AEGIVUE_MEDIA_BIND` | `0.0.0.0:3010` | Media control listen address on the private network. |
| `AEGIVUE_STORAGE_PATH` | `/data/recordings` | Shared recording path used by API and media services. |
| `AEGIVUE_LIVE_PATH` | `/tmp/aegivue-live` | Media-engine transient live-stream state. |
| `AEGIVUE_WEBRTC_PUBLISH_URL` | `rtsp://aegivue-webrtc:8554` | Private MediaMTX publish endpoint. |

The API and media engine must see the same recording files at the same logical
path. If you replace the Compose volume with a bind mount, preserve that invariant
and ensure the configured UID/GID can read and write it.

## Camera-level settings

Camera behavior is stored in PostgreSQL and managed through the dashboard or API,
not environment variables.

| Group | Setting | Range / values | Default |
| --- | --- | --- | --- |
| Connection | RTSP port | `1`–`65535` | `554` |
| Recording | Mode | `continuous`, `motion` | `continuous` |
| Recording | Pre-event | `0`–`120` seconds | `5` |
| Recording | Post-event | `0`–`600` seconds | `15` |
| Recording | Retention | `1`–`3650` days or unlimited | unlimited |
| Motion | Enabled | boolean | `false` |
| Motion | Stream | `main`, `sub` | `sub` |
| Motion | Analysis rate | `0.1`–`30` FPS | `5` |
| Motion | Sensitivity | `0`–`1` | `0.65` |

Selecting `sub` requires a configured substream. See [RTSP cameras](../cameras/rtsp.md)
and [Motion detection and events](../motion/events.md) for operational guidance.

## Validate a deployment

Render and validate the effective Compose model without starting services:

```sh
docker compose config --quiet
```

After a change, confirm the effective environment and service health without
publishing secrets in issue reports:

```sh
docker compose ps
docker compose logs --tail=100 aegivue-api aegivue-media aegivue-webrtc
```
