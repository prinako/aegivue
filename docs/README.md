# Aegivue documentation

Welcome to the Aegivue handbook. These guides cover installation, camera setup,
day-two operations, architecture, and contribution workflows.

> [!IMPORTANT]
> Aegivue does not currently provide built-in authentication. Keep the web UI and
> API on a trusted network or place them behind an authenticated reverse proxy.

## Choose a path

### I want to run Aegivue

1. Follow the repository [quick start](../README.md#quick-start).
2. Review the [configuration reference](reference/configuration.md).
3. [Add and verify an RTSP camera](cameras/rtsp.md).
4. Bookmark the [troubleshooting runbook](operations/troubleshooting.md).

### I operate an existing installation

- [Upgrade safely and apply database migrations](operations/upgrades.md)
- [Diagnose unhealthy services, streams, and storage](operations/troubleshooting.md)
- [Configure motion detection and inspect events](motion/events.md)

### I want to contribute

1. [Set up the development environment](development/getting-started.md).
2. Read the [system architecture](architecture/overview.md).
3. Review [ADR 0001: Service boundaries](architecture/0001-service-boundaries.md).
4. Run the complete local CI command set before opening a pull request.

## Documentation map

| Area | Guide | What it covers |
| --- | --- | --- |
| Getting started | [Project quick start](../README.md#quick-start) | First deployment and service URLs |
| Reference | [Configuration](reference/configuration.md) | Environment variables, defaults, exposure, and restart scope |
| Cameras | [RTSP cameras](cameras/rtsp.md) | Stream paths, codecs, live viewing, and camera diagnostics |
| Motion | [Motion detection and events](motion/events.md) | Detector settings, event lifecycle, API, and limitations |
| Operations | [Upgrades](operations/upgrades.md) | Backups, migrations, verification, and rollback considerations |
| Operations | [Troubleshooting](operations/troubleshooting.md) | Symptom-first incident checks and diagnostic commands |
| Architecture | [System overview](architecture/overview.md) | Data flows, trust boundaries, storage, and failure isolation |
| Architecture | [ADR 0001](architecture/0001-service-boundaries.md) | Rationale for the current service boundaries |
| Development | [Development setup](development/getting-started.md) | Toolchains, local stack, tests, formatting, and migrations |

## Supported deployment model

The documented baseline is Docker Compose on a Linux host with cameras reachable
from that host. Commands assume:

- the repository root is the current directory;
- configuration is stored in an untracked `.env` copied from `.env.example`;
- stock service names from `docker-compose.yml` are in use;
- PostgreSQL data and recordings live in Docker-managed volumes.

If your deployment changes service names, networks, ports, or storage mounts,
translate commands accordingly and record those differences in your operations
runbook.

## Conventions

- Shell commands run from the repository root unless noted otherwise.
- `<camera-id>`, `<event-id>`, and similar values are placeholders.
- Examples use the default localhost bindings from `.env.example`.
- Never commit real credentials, camera URLs containing credentials, or `.env`.
- Treat application images and database migrations as one release unit.
- Never edit a numbered migration after release; add a new migration instead.
- Update docs in the same change as behavior, configuration, or architecture.

## Getting help

Start with the [troubleshooting runbook](operations/troubleshooting.md) and collect
the output of `docker compose ps` plus relevant service logs. When reporting a
problem, include the Aegivue image tag or commit, host platform, camera codec, and
the smallest reproducible sequence. Remove credentials and private addresses
before sharing logs publicly.
