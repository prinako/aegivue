# Upgrades and database migrations

Aegivue uses PostgreSQL migrations to keep the database schema compatible with the API and Rust media engine. Treat application images and database migrations as one release unit.

## Why this matters

The API and media engine may begin using a new column as soon as a newer image starts. If the matching migration has not been applied, the service can remain up while camera operations fail repeatedly.

A typical schema-mismatch symptom looks like:

```text
camera reconciliation start deferred
error returned from database: column rc.retention_days does not exist
```

This means the running media code expects a schema change that the active PostgreSQL database does not yet have.

## Current Compose migration flow

The stock `docker-compose.yml` starts `aegivue-migrate` after PostgreSQL becomes healthy and requires that migration job to complete before `aegivue-api` or `aegivue-media` start.

The migration service currently uses the PostgreSQL image and bind-mounts migration files from the checked-out repository:

```yaml
volumes:
  - ./database/migrations:/migrations:ro
  - ./database/migrate.sh:/migrate.sh:ro
```

Because API and media images are pulled from GHCR while migrations come from the local checkout, operators must update both the repository checkout and container images during an upgrade. Pulling newer application images without updating the local migration files can create an application/schema mismatch.

## Safe upgrade procedure

Back up both PostgreSQL data and the recording volume before an upgrade.

From the repository root:

```sh
git pull

docker compose pull

docker compose run --rm aegivue-migrate

docker compose up -d
```

Then verify service health:

```sh
docker compose ps
docker compose logs --tail=100 aegivue-api aegivue-media
```

If your deployment uses a customized Compose stack or different service names, run the equivalent commands against that stack. Do not assume the stock service names match an existing HomeLab deployment.

## Verify applied migrations

The migration runner records completed files in `schema_migrations`.

Using the stock Compose service name:

```sh
docker compose exec aegivue-postgres \
  psql -U aegivue -d aegivue \
  -c "SELECT name, applied_at FROM schema_migrations ORDER BY applied_at;"
```

For a deployment whose PostgreSQL container is named `aegivue-db`:

```sh
docker exec -it aegivue-db \
  psql -U aegivue -d aegivue \
  -c "SELECT name, applied_at FROM schema_migrations ORDER BY applied_at;"
```

The list should include every migration present in `database/migrations` for the deployed application version.

## Verify a required column

For example, per-camera recording retention requires `recording_configs.retention_days`.

```sh
docker exec -it aegivue-db \
  psql -U aegivue -d aegivue \
  -c "SELECT camera_id, retention_days FROM recording_configs;"
```

If PostgreSQL reports that the column does not exist, the migration has not been applied to that database.

## Migration rules for contributors

Once a migration has been released, do not edit it to add new schema changes. Add a new numbered migration instead, for example:

```text
0005_add_storage_quota.sql
0006_add_event_index.sql
```

The current migration runner tracks applied migrations by filename. Editing an already-applied migration will not cause existing installations to rerun it.

Each migration should be transactional when possible, safe to apply exactly once, and reviewed together with every API/media change that depends on it.

## Troubleshooting schema mismatch

If a service reports a missing table or column:

1. Confirm which database container the running service actually uses.
2. Inspect `schema_migrations` in that database.
3. Confirm the matching migration file exists in the deployed checkout.
4. Run the migration job explicitly.
5. Verify the schema directly with `psql`.
6. Restart the API/media services only after the schema is current.

Avoid treating manual `ALTER TABLE` commands as the normal upgrade path. They are useful for emergency recovery, but the installation should ultimately be brought back into agreement with the tracked migration history.

## Planned hardening

The current bind-mounted migration design is simple but allows local checkout and GHCR image versions to drift. A future deployment hardening step should package migrations into a versioned Aegivue migration image and release it with the API, media, and web images under the same version or commit tag.

That would make the release relationship explicit:

```text
Aegivue release
  ├── aegivue-api:<version>
  ├── aegivue-media:<version>
  ├── aegivue-web:<version>
  └── aegivue-migrate:<version>
```

Until then, always update the local repository checkout before running the migration service during an upgrade.
