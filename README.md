# Vigilo

Vigilo is a self-hosted NVR foundation for reliable RTSP recording and playback.

## Status

Vigilo is in early development. Implemented today: PostgreSQL-backed camera configuration, validated Fastify camera/control/recording APIs, a private Rust media control service, independently supervised camera workers, FFmpeg RTSP stream-copy recording into 60-second MP4 segments, recording metadata, and an initial Flutter web camera/recording dashboard.

Milestone 1 is implemented but still needs validation against a representative matrix of real camera models/codecs. Motion detection, ONVIF, alerts, and optional AI remain planned. Authentication and encrypted camera-secret storage are also required before internet-facing production use.

## Architecture

- `apps/api`: TypeScript/Fastify control plane; configuration and metadata only.
- `crates/media-engine`: Rust/Tokio media plane; isolated camera workers and FFmpeg recording.
- `apps/web`: Flutter web dashboard, served by Nginx with same-origin API proxying.
- `crates/vigilo-common`: versionable shared media contracts.
- `database/migrations`: relational schema; media blobs never enter PostgreSQL.
- `storage`: local development mount points; production storage is configurable.

Each camera is supervised independently so a failed stream cannot terminate unrelated workers. PostgreSQL `cameras.enabled` is the durable desired state. The media service reconciles it at startup and every 15 seconds, without creating duplicate workers.

FFmpeg writes each active segment as `HH-MM-SS.mp4.partial` beneath `<storage>/<camera>/YYYY/MM/DD/HH`. The media engine scans all date directories, atomically renames completed non-empty segments to `.mp4`, then inserts metadata. Segment timestamps come from each UTC path rather than worker uptime. Production segment duration defaults to 60 seconds and may be set from 5–3600 seconds with `VIGILO_RECORDING_SEGMENT_SECONDS`.

Recordings are listed with `?page=1&pageSize=25` (maximum 100). `GET /api/v1/recordings/:id/media` streams files, supports byte ranges, and never exposes storage paths.

## Run locally

Requirements: Docker with Compose. Copy `.env.example` to `.env`, set a strong `VIGILO_POSTGRES_PASSWORD`, and run:

```sh
docker compose up --build
curl http://127.0.0.1:3000/api/v1/health
```

Open the web interface at `http://127.0.0.1:8080`. API documentation is at `http://127.0.0.1:3000/docs`. Add a camera with `POST /api/v1/cameras`; enabled cameras start automatically and are restored after service restarts.

Flutter development is pinned through `apps/web/.fvmrc`. From `apps/web`, run Flutter tooling through FVM, for example `fvm flutter pub get`, `fvm flutter analyze`, `fvm flutter test`, and `fvm flutter build web`.

For a camera-free integration test, start the base stack plus `docker-compose.integration.yml`, then run `sh scripts/integration-rtsp.sh`. It publishes FFmpeg `testsrc` to a local MediaMTX service and verifies ONLINE state, segment metadata, and a 1 KiB HTTP range response.

## Security notes

Camera passwords and full RTSP URLs are never returned or logged. The initial schema currently stores passwords in a restricted column and FFmpeg receives its credential-bearing URL in process arguments. Encryption/key-provider integration and a mechanism that avoids argv exposure remain security debt. Keep the API bound to localhost or behind an authenticated reverse proxy.

Motion detection, AI, ONVIF, alerts, authentication, retention management, and embedded live video are planned and are not implemented.
