$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Sql = Join-Path $Root "ops/sql/grant-public-read.sql"

Get-Content -LiteralPath $Sql -Raw |
    docker compose exec -T krameriusPostgres psql -U fedoraAdmin -d kramerius -v ON_ERROR_STOP=1
