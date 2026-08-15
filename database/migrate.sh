#!/bin/sh
set -eu
psql "$AEGIVUE_DATABASE_URL" -v ON_ERROR_STOP=1 -c 'CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())'
for migration in /migrations/*.sql; do
  name=$(basename "$migration")
  applied=$(psql "$AEGIVUE_DATABASE_URL" -At -v ON_ERROR_STOP=1 -c "SELECT 1 FROM schema_migrations WHERE name = '$name'")
  if [ "$applied" = 1 ]; then continue; fi
  psql "$AEGIVUE_DATABASE_URL" -v ON_ERROR_STOP=1 -1 -f "$migration"
  psql "$AEGIVUE_DATABASE_URL" -v ON_ERROR_STOP=1 -c "INSERT INTO schema_migrations(name) VALUES ('$name')"
done
