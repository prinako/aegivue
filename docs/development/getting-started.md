# Development setup

This guide covers a local Aegivue checkout, the containerized development stack,
and the checks run by CI.

## Prerequisites

- Docker Engine with Docker Compose v2
- Node.js 22 or newer
- A stable Rust toolchain with `rustfmt` and `clippy`
- Flutter 3.38.7 for frontend work

An RTSP camera is optional. The application and automated checks can run without
one.

## Configure the checkout

From the repository root:

```sh
cp .env.example .env
```

Replace `AEGIVUE_POSTGRES_PASSWORD` with a long, random password. The default API
and web bindings only listen on localhost. If another device needs to open the
dashboard, change `AEGIVUE_WEB_BIND` deliberately and review the security warning
in the main [README](../../README.md#security).

Validate the resolved Compose configuration before starting services:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml config --quiet
```

## Run the development stack

The development override builds the API, media engine, and web app from the local
checkout:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

The stock Compose stack runs `aegivue-migrate` before the API and media engine.
Migration files are read from the current checkout under `database/migrations`, so
local source and local schema should normally move together during development.

Once the health checks pass, open:

| Service | Address |
| --- | --- |
| Web dashboard | <http://127.0.0.1:8080> |
| OpenAPI UI | <http://127.0.0.1:3000/docs> |
| API health | <http://127.0.0.1:3000/api/v1/health> |

Inspect service state and logs with:

```sh
docker compose ps
docker compose logs --tail=100 aegivue-api aegivue-media aegivue-webrtc aegivue-web
```

Stop the stack without deleting database or recording volumes:

```sh
docker compose down
```

Do not add `--volumes` unless you intend to delete local PostgreSQL data and
recordings managed by Compose.

## Database migrations during development

Schema changes live in `database/migrations` and are applied in filename order by
`database/migrate.sh`. Applied filenames are recorded in the `schema_migrations`
table.

When adding a schema change, create a new numbered migration rather than modifying
a migration that may already have been applied, for example:

```text
0005_add_storage_quota.sql
```

Run the migration job explicitly when you want to verify a migration without
rebuilding the entire stack:

```sh
docker compose run --rm aegivue-migrate
```

Inspect applied migrations with:

```sh
docker compose exec aegivue-postgres \
  psql -U aegivue -d aegivue \
  -c "SELECT name, applied_at FROM schema_migrations ORDER BY applied_at;"
```

If application code reports a missing table or column, verify the active database
schema before debugging camera or media code. See
[Upgrades and database migrations](../operations/upgrades.md) for the production
upgrade model and schema-mismatch troubleshooting.

## Run the CI checks locally

### TypeScript API

```sh
npm ci --prefix apps/api
npm --prefix apps/api run typecheck
npm --prefix apps/api run lint
npm --prefix apps/api run format:check
npm --prefix apps/api test
npm --prefix apps/api run build
```

To apply formatting changes, run `npm --prefix apps/api run format`.

### Rust media engine

```sh
rustup component add rustfmt clippy
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test
```

To apply formatting changes, run `cargo fmt`.

### Flutter web app

Run these commands from `apps/web`:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build web --release
```

CI uses Flutter 3.38.7. If you use FVM, prefix Flutter and Dart commands with
`fvm`. To apply formatting changes, run `dart format .`.

## Integration smoke test

The integration override provides a camera-free RTSP fixture:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml \
  -f docker-compose.integration.yml up --build -d
sh scripts/integration-rtsp.sh
```

When it finishes, inspect logs if necessary and stop the stack with the same file
arguments followed by `down`.

## Common problems

- **A port is already in use:** change the corresponding bind in `.env`, or stop
  the process already using ports 3000, 8080, 5432, or UDP 8189.
- **A container stays unhealthy:** run `docker compose ps` and inspect that
  service's logs. Database migration failures commonly indicate an incorrect
  `AEGIVUE_POSTGRES_PASSWORD`, stale local configuration, or an application/schema
  version mismatch.
- **A required PostgreSQL column does not exist:** run the migration job explicitly,
  inspect `schema_migrations`, and confirm the migration file exists in the active
  checkout before restarting services.
- **Formatting passes locally but fails in CI:** use Node.js 22, stable rustfmt,
  and Flutter 3.38.7, matching [CI](../../.github/workflows/ci.yml).
- **Live video does not work from another device:** follow the WebRTC and HLS
  checks in [Adding an RTSP camera](../cameras/rtsp.md#troubleshooting).
