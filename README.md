# Vigilo

Vigilo is a self-hosted NVR and intelligent video-surveillance platform for RTSP/ONVIF cameras, recording, motion events, live viewing, alerts, and optional AI detection.

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

Each camera will be supervised independently so a failed stream cannot terminate unrelated workers. See [service-boundary ADR](docs/architecture/0001-service-boundaries.md).

## Run locally

Requirements: Docker with Compose. Copy `.env.example` to `.env`, set a strong `VIGILO_POSTGRES_PASSWORD`, and run:

```sh
docker compose up --build
curl http://127.0.0.1:3000/api/v1/health
```

Open the web interface at `http://127.0.0.1:8080`. API documentation is at `http://127.0.0.1:3000/docs`. Add a camera with `POST /api/v1/cameras`; enabled cameras start automatically and are restored after service restarts.

## Security notes

Camera passwords are never returned by camera APIs. The initial schema currently stores them in a restricted column pending integration with an encryption/key provider; do not treat this foundation as production-ready until encryption at rest and authentication are implemented. Keep the API bound to localhost or behind an authenticated reverse proxy.
