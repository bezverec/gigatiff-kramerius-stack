#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docker compose -f "$root/docker-compose.yml" exec -T processPostgres \
  psql -U process -d process -v ON_ERROR_STOP=1 \
  < "$root/ops/sql/normalize-process-owners.sql"
