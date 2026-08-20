# ADR 0001: Service boundaries

## Status

Accepted

## Context

Aegivue must serve configuration and recording metadata while continuously handling
unreliable RTSP streams and long-running FFmpeg processes. Media failures must not
block API requests or take unrelated cameras offline. Video files are also a poor
fit for PostgreSQL, but their metadata must remain queryable.

## Decision

Aegivue separates the system into these boundaries:

| Component | Ownership |
| --- | --- |
| TypeScript API | Public control plane, validation, camera CRUD, recording queries, and media-engine coordination |
| Rust media engine | Camera reconciliation, isolated workers, FFmpeg processes, segment finalization, and retention cleanup |
| PostgreSQL | Durable desired camera state and recording metadata |
| Recording volume | Finalized video segments; PostgreSQL stores references rather than video blobs |
| MediaMTX | Private RTSP ingest from the media engine and browser-facing WebRTC/LL-HLS delivery through the web proxy |
| Flutter/Nginx web service | User interface and same-origin proxying for API and live media requests |

The API communicates with the media engine through private internal HTTP. The
media engine is the only application service that needs direct access to camera
networks. PostgreSQL, internal control endpoints, and RTSP publishing remain on
private Compose networks.

PostgreSQL owns desired state. The media manager reconciles enabled cameras on
startup and periodically. Each camera receives an isolated supervised Tokio task
and FFmpeg child process. A camera is removed only after its worker stops, and the
database prevents deletion while recordings still reference it.

Camera credentials are accepted on writes but omitted from API read models and
structured logs.

## Consequences

- A failed or stalled camera does not stop API traffic or unrelated workers.
- The control plane can evolve independently from FFmpeg orchestration.
- Operators must back up both PostgreSQL and the recording volume to preserve a
  complete installation.
- Database and filesystem consistency require explicit segment finalization and
  retention logic.
- The deployment contains more services and internal network paths than a single
  process would.
- Authentication and encrypted camera-secret storage remain separate hardening
  concerns; service isolation does not replace either control.

## Related documentation

- [System architecture](overview.md)
- [Configuration reference](../reference/configuration.md)
- [Troubleshooting runbook](../operations/troubleshooting.md)
