# Vigilo

Vigilo is a self-hosted NVR and intelligent video-surveillance platform for RTSP/ONVIF cameras, recording, motion events, live viewing, alerts, and optional AI detection.

## Status

Vigilo is in early development. Implemented today: a PostgreSQL 17 schema, validated Fastify health and camera create/list/get/delete APIs, credential-safe camera read models, Docker deployment foundation, and tested Rust primitives for camera lifecycle, bounded pre-event packet retention, and recording paths.

In progress: media-engine orchestration, RTSP ingestion and 60-second segmented recording. Planned after that: recording metadata/listing, Flutter UI, motion detection, ONVIF, and optional AI. This repository does **not** yet provide a complete NVR.

## Architecture

- `apps/api`: TypeScript/Fastify control plane; configuration and metadata only.
- `crates/media-engine`: Rust/Tokio media plane; camera workers and future FFmpeg integration.
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

The API documentation is at `http://127.0.0.1:3000/docs`. See [development setup](docs/development/getting-started.md) for local quality commands.

## Security notes

Camera passwords are never returned by camera APIs. The initial schema currently stores them in a restricted column pending integration with an encryption/key provider; do not treat this foundation as production-ready until encryption at rest and authentication are implemented. Keep the API bound to localhost or behind an authenticated reverse proxy.
