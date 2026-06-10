#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[clean-bootstrap] %s\n' "$*"
}

wait_for_http() {
  local name="$1"
  local url="$2"
  local tries="${3:-90}"
  local delay="${4:-2}"

  for _ in $(seq 1 "$tries"); do
    if curl -fsS "$url" >/dev/null; then
      log "$name is ready"
      return 0
    fi
    sleep "$delay"
  done

  log "$name did not become ready: $url"
  return 1
}

wait_for_postgres() {
  local name="$1"
  local host="$2"
  local port="$3"
  local user="$4"
  local tries="${5:-90}"
  local delay="${6:-2}"

  for _ in $(seq 1 "$tries"); do
    if pg_isready -h "$host" -p "$port" -U "$user" >/dev/null 2>&1; then
      log "$name is ready"
      return 0
    fi
    sleep "$delay"
  done

  log "$name did not become ready: $host:$port"
  return 1
}

psql_kramerius() {
  PGPASSWORD="${KRAMERIUS_DB_PASSWORD}" psql \
    -h "${KRAMERIUS_DB_HOST}" \
    -p "${KRAMERIUS_DB_PORT}" \
    -U "${KRAMERIUS_DB_USER}" \
    -d "${KRAMERIUS_DB_NAME}" \
    -v ON_ERROR_STOP=1 \
    "$@"
}

psql_process() {
  PGPASSWORD="${PROCESS_DB_PASSWORD}" psql \
    -h "${PROCESS_DB_HOST}" \
    -p "${PROCESS_DB_PORT}" \
    -U "${PROCESS_DB_USER}" \
    -d "${PROCESS_DB_NAME}" \
    -v ON_ERROR_STOP=1 \
    "$@"
}

require_field() {
  local core="$1"
  local field="$2"
  local status

  status="$(curl -fsS -o /dev/null -w '%{http_code}' "${SOLR_URL}/${core}/schema/fields/${field}")"
  if [ "$status" != "200" ]; then
    log "missing Solr field ${core}/${field}"
    return 1
  fi
  log "Solr field ${core}/${field} exists"
}

warn_field() {
  local core="$1"
  local field="$2"

  if require_field "$core" "$field"; then
    return 0
  fi

  log "warning: optional Solr field ${core}/${field} was not confirmed"
  return 0
}

KRAMERIUS_DB_HOST="${KRAMERIUS_DB_HOST:-krameriusPostgres}"
KRAMERIUS_DB_PORT="${KRAMERIUS_DB_PORT:-5432}"
KRAMERIUS_DB_NAME="${KRAMERIUS_DB_NAME:-kramerius}"
KRAMERIUS_DB_USER="${KRAMERIUS_DB_USER:-fedoraAdmin}"
KRAMERIUS_DB_PASSWORD="${KRAMERIUS_DB_PASSWORD:-fedoraAdmin}"

PROCESS_DB_HOST="${PROCESS_DB_HOST:-processPostgres}"
PROCESS_DB_PORT="${PROCESS_DB_PORT:-5432}"
PROCESS_DB_NAME="${PROCESS_DB_NAME:-process}"
PROCESS_DB_USER="${PROCESS_DB_USER:-process}"
PROCESS_DB_PASSWORD="${PROCESS_DB_PASSWORD:-process}"

SOLR_URL="${SOLR_URL:-http://solr:8983/solr}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://keycloak_eduid:8990}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-kramerius}"
KRAMERIUS_HEALTH_URL="${KRAMERIUS_HEALTH_URL:-http://kramerius:8080/search/api/client/v7.0/info}"

wait_for_postgres "Kramerius PostgreSQL" "$KRAMERIUS_DB_HOST" "$KRAMERIUS_DB_PORT" "$KRAMERIUS_DB_USER"
wait_for_postgres "Process PostgreSQL" "$PROCESS_DB_HOST" "$PROCESS_DB_PORT" "$PROCESS_DB_USER"
wait_for_http "Solr" "${SOLR_URL}/admin/info/system"
wait_for_http "Keycloak" "${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}"
wait_for_http "Kramerius API" "$KRAMERIUS_HEALTH_URL" 150 2

require_field "search" "authors.aut.facet"
require_field "search" "coords.is_point"
warn_field "logs" "created"

if [ -f /ops/sql/grant-public-read.sql ]; then
  log "applying public read SQL helper"
  psql_kramerius -f /ops/sql/grant-public-read.sql
fi

if [ -f /ops/sql/normalize-process-owners.sql ]; then
  log "applying process owner compatibility SQL helper"
  psql_process -f /ops/sql/normalize-process-owners.sql
fi

log "clean stack bootstrap finished"
