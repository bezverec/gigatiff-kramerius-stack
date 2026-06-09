param(
    [string]$PublicHost = "127.0.0.1",
    [string]$BindAddr = "127.0.0.1",
    [int]$WebClientPort = 1234,
    [int]$AdminClientPort = 1235,
    [int]$KrameriusApiPort = 8088,
    [string]$KeycloakPublicHost = "keycloak.localhost",
    [int]$KeycloakPort = 8990,
    [int]$GigaTiffPort = 18082,
    [string]$GigaTiffInternalBaseUrl = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

function Set-PropertyLine {
    param(
        [string]$Path,
        [string]$Key,
        [string]$Value
    )

    $lines = Get-Content -LiteralPath $Path
    $found = $false
    $updated = foreach ($line in $lines) {
        if ($line -match "^\s*$([regex]::Escape($Key))=") {
            $found = $true
            "$Key=$Value"
        } else {
            $line
        }
    }
    if (-not $found) {
        $updated += "$Key=$Value"
    }
    Set-Content -LiteralPath $Path -Encoding UTF8 -Value $updated
}

$envPath = Join-Path $Root ".env"
if (-not $GigaTiffInternalBaseUrl) {
    $GigaTiffInternalBaseUrl = "http://host.docker.internal:$GigaTiffPort/iiif/3"
}
@(
    "KRAMERIUS_BIND_ADDR=$BindAddr"
    "KRAMERIUS_PUBLIC_HOST=$PublicHost"
    "WEB_CLIENT_PORT=$WebClientPort"
    "ADMIN_CLIENT_PORT=$AdminClientPort"
    "KRAMERIUS_API_PORT=$KrameriusApiPort"
    "KEYCLOAK_PUBLIC_HOST=$KeycloakPublicHost"
    "KEYCLOAK_PORT=$KeycloakPort"
    "SOLR_PORT=8983"
    "PROCESS_MANAGER_PORT=8082"
    "CURATOR_WORKER_PORT=8084"
    "PUBLIC_WORKER_PORT=8086"
    "KRAMERIUS_DB_PORT=15432"
    "PROCESS_DB_PORT=25432"
    "GIGATIFF_PORT=$GigaTiffPort"
    "GIGATIFF_INTERNAL_BASE_URL=$GigaTiffInternalBaseUrl"
    "GIGATIFF_SOURCE_DIR=../gigatiff"
    "GIGATIFF_CACHE_NAMESPACE=gigatiff-server-response-v12-jp2-auto-fix"
    "DOCKHAND_PORT=3000"
    "DASHY_PORT=18080"
) | Set-Content -LiteralPath $envPath -Encoding UTF8

$migration = Join-Path $Root "mnt/import/.kramerius4/migration.properties"
$gigaBase = "http://${PublicHost}:$GigaTiffPort/iiif/3"
Set-PropertyLine $migration "convert.imageServerTilesURLPrefix" $GigaTiffInternalBaseUrl
Set-PropertyLine $migration "convert.imageServerImagesURLPrefix" $GigaTiffInternalBaseUrl
Set-PropertyLine $migration "convert.imageServerSuffix.removeFilenameExtensions" "false"
Set-PropertyLine $migration "convert.imageServerSuffix.tiles" ""

$rewrite = Join-Path $Root "rewrite.config"
$rewriteText = Get-Content -LiteralPath $rewrite -Raw
$rewriteText = $rewriteText -replace "http://[^/\s]+:18082/iiif/3", $gigaBase
Set-Content -LiteralPath $rewrite -Encoding UTF8 -NoNewline -Value $rewriteText.TrimEnd()

$configuration = Join-Path $Root "mnt/import/.kramerius4/configuration.properties"
Set-PropertyLine $configuration "client" "http://${PublicHost}:$WebClientPort/"

$keycloak = Join-Path $Root "mnt/import/.kramerius4/keycloak.json"
$keycloakJson = Get-Content -LiteralPath $keycloak -Raw | ConvertFrom-Json
$keycloakJson.'auth-server-url' = "http://${KeycloakPublicHost}:$KeycloakPort/"
$keycloakJson | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $keycloak -Encoding UTF8

$configMain = Join-Path $Root "public/local-config/gigatiff/config-main.json"
$config = Get-Content -LiteralPath $configMain -Raw | ConvertFrom-Json
$config.app.name.cs = "GigaTIFF"
$config.app.name.en = "GigaTIFF"
$config.app.logo = "/favicon.svg"
$config.app.adminClientUrl = "http://${PublicHost}:$AdminClientPort"
$config.api.baseUrl = "http://${PublicHost}:$KrameriusApiPort"
$config | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $configMain -Encoding UTF8

$libraries = Join-Path $Root "public/local-config/libraries.json"
$libraryJson = Get-Content -LiteralPath $libraries -Raw | ConvertFrom-Json
foreach ($library in $libraryJson) {
    $library.name = "GigaTIFF"
    $library.name_en = "GigaTIFF"
    $library.new_client_url = "http://${PublicHost}:$WebClientPort"
    $library.url = "http://${PublicHost}:$WebClientPort"
    $library.logo = "/favicon.svg"
}
$libraryJson | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $libraries -Encoding UTF8

Write-Host "Configured Kramerius test stack for http://${PublicHost}:$WebClientPort"
Write-Host "Review .env if you need additional port overrides."
