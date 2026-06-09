$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Sql = Join-Path $Root "ops/sql/normalize-process-owners.sql"

Get-Content -LiteralPath $Sql -Raw |
    docker compose exec -T processPostgres psql -U process -d process -v ON_ERROR_STOP=1
