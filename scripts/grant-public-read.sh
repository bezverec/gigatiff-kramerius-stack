#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docker compose -f "$root/docker-compose.yml" exec -T krameriusPostgres \
  psql -U fedoraAdmin -d kramerius -v ON_ERROR_STOP=1 \
  < "$root/ops/sql/grant-public-read.sql"
