#!/usr/bin/env sh
set -eu

db="${DOCKHAND_DB:-/app/data/db/dockhand.db}"
env_name="${DOCKHAND_ENVIRONMENT_NAME:-Local Docker}"
stack_name="${DOCKHAND_STACK_NAME:-gigatiff-kramerius}"
compose_path="${DOCKHAND_STACK_COMPOSE_PATH:-/workspace/gigatiff-kramerius/docker-compose.yml}"
env_path="${DOCKHAND_STACK_ENV_PATH:-/workspace/gigatiff-kramerius/.env}"
env_path_sql="NULL"

if [ -f "$env_path" ]; then
  env_path_sql="'$env_path'"
fi

i=0
while [ ! -f "$db" ] && [ "$i" -lt 30 ]; do
  i=$((i + 1))
  sleep 1
done

if [ ! -f "$db" ]; then
  echo "Dockhand database not found at $db" >&2
  exit 1
fi

sqlite3 "$db" <<SQL
PRAGMA foreign_keys = ON;

INSERT INTO environments (
  name,
  connection_type,
  socket_path,
  collect_activity,
  collect_metrics,
  highlight_changes
) VALUES (
  '$env_name',
  'socket',
  '/var/run/docker.sock',
  1,
  1,
  1
)
ON CONFLICT(name) DO UPDATE SET
  connection_type = 'socket',
  socket_path = '/var/run/docker.sock',
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO stack_sources (
  stack_name,
  environment_id,
  source_type,
  compose_path,
  env_path
)
SELECT
  '$stack_name',
  id,
  'internal',
  '$compose_path',
  $env_path_sql
FROM environments
WHERE name = '$env_name'
ON CONFLICT(stack_name, environment_id) DO UPDATE SET
  source_type = 'internal',
  compose_path = excluded.compose_path,
  env_path = excluded.env_path,
  updated_at = CURRENT_TIMESTAMP;
SQL

echo "Registered Dockhand stack '$stack_name' for environment '$env_name'."
