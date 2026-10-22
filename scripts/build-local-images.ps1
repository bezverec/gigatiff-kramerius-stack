[CmdletBinding()]
param(
    [string]$AdminClientDir = (Join-Path $PSScriptRoot "../../kramerius-admin-client"),
    [string]$GigaTiffSourceDir = (Join-Path $PSScriptRoot "../../gigatiff"),
    [ValidateRange(1, 32)][int]$BuildJobs = 4,
    [ValidateSet("web-client", "auth-shim", "admin-client", "bootstrap", "server")]
    [string[]]$Components = @("web-client", "auth-shim", "admin-client", "bootstrap", "server"),
    [string]$OutputDirectory = "",
    [switch]$SkipPull,
    [switch]$Publish
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$AdminClientDir = (Resolve-Path -LiteralPath $AdminClientDir).ProviderPath
$GigaTiffSourceDir = (Resolve-Path -LiteralPath $GigaTiffSourceDir).ProviderPath
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $root (".local-build/" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).ProviderPath

function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

# Parse both manifests with the standard TOML parser, without requiring host Python.
$parser = @'
import json, pathlib, tomllib
versions = tomllib.loads(pathlib.Path('/stack/versions.toml').read_text(encoding='utf-8'))
cargo = tomllib.loads(pathlib.Path('/gigatiff/Cargo.toml').read_text(encoding='utf-8'))
print(json.dumps({'versions': versions, 'gigatiff_version': cargo['workspace']['package']['version']}))
'@
$parsed = (Invoke-Checked docker @("run", "--rm", "--mount", "type=bind,source=$root,target=/stack,readonly",
    "--mount", "type=bind,source=$GigaTiffSourceDir,target=/gigatiff,readonly",
    "python:3.15.1-alpine3.24", "python", "-c", $parser)) -join "`n" | ConvertFrom-Json
$versions = $parsed.versions
if ($parsed.gigatiff_version -ne $versions.core.gigatiff_server_version) {
    throw "GigaTIFF source version does not match versions.toml"
}
$adminRevision = (Invoke-Checked git @("-C", $AdminClientDir, "rev-parse", "HEAD")).Trim()
if ($adminRevision -ne $versions.core.kramerius_admin_client_ref) {
    throw "Admin checkout must match $($versions.core.kramerius_admin_client_ref)"
}
if (Invoke-Checked git @("-C", $AdminClientDir, "status", "--porcelain")) {
    throw "Admin checkout must be clean"
}
$gigaRevision = (Invoke-Checked git @("-C", $GigaTiffSourceDir, "rev-parse", "HEAD")).Trim()
$gigaDirty = [bool](Invoke-Checked git @("-C", $GigaTiffSourceDir, "status", "--porcelain"))
$stackRevision = (Invoke-Checked git @("-C", $root, "rev-parse", "HEAD")).Trim()
$stackDirty = [bool](Invoke-Checked git @("-C", $root, "status", "--porcelain"))
if ($Publish) {
    if ($gigaDirty -or $stackDirty) {
        throw "Publication requires clean, committed stack and GigaTIFF sources"
    }
    if ($gigaRevision -ne $versions.core.gigatiff_ref) {
        throw "Publication requires the GigaTIFF revision pinned in versions.toml"
    }
}

$builds = @(
    @{ Component = "web-client"; Name = $versions.ghcr.web_client_image; Context = $root; File = "$root/Dockerfile.web-client-gigatiff" },
    @{ Component = "auth-shim"; Name = $versions.ghcr.auth_shim_image; Context = $root; File = "$root/Dockerfile.auth-shim" },
    @{ Component = "admin-client"; Name = $versions.ghcr.admin_client_image; Context = $AdminClientDir; File = "$root/ops/admin-client/Dockerfile.gigatiff" },
    @{ Component = "bootstrap"; Name = $versions.ghcr.bootstrap_image; Context = $root; File = "$root/Containerfile.clean-bootstrap" },
    @{ Component = "server"; Name = $versions.ghcr.gigatiff_server_image; Context = $GigaTiffSourceDir; File = "$GigaTiffSourceDir/Dockerfile" }
)
$report = [ordered]@{
    stack_version = $versions.stack.version
    created_utc = [DateTime]::UtcNow.ToString("o")
    versions = $versions
    stack_revision = $stackRevision
    stack_dirty = $stackDirty
    gigatiff_revision = $gigaRevision
    gigatiff_dirty = $gigaDirty
    admin_revision = $adminRevision
    platform = "linux/amd64"
    published = [bool]$Publish
    images = @()
}
$reportPath = Join-Path $OutputDirectory "images.json"
foreach ($build in $builds | Where-Object { $_.Component -in $Components }) {
    $isServer = $build.Component -eq "server"
    $version = if ($isServer) { $versions.core.gigatiff_server_version } else { $versions.stack.version }
    $namespace = if ($Publish) { $versions.ghcr.namespace } else { "localhost" }
    $tag = "$namespace/$($build.Name):$version"
    $alias = if ($isServer) { "gigatiff-server:local" } else { "localhost/$($build.Name):clean" }
    $source = if ($isServer) { $versions.core.gigatiff_repository } else { $versions.stack.repository }
    $revision = if ($isServer) { $gigaRevision } else { $stackRevision }
    $dirty = if ($isServer) { $gigaDirty } else { $stackDirty }
    $args = @("buildx", "build", "--platform", "linux/amd64", "--progress", "plain",
        "--sbom=true", "--provenance=mode=min", "--metadata-file", "$OutputDirectory/$($build.Component)-metadata.json",
        "--tag", $tag, "--file", $build.File,
        "--label", "org.opencontainers.image.source=$source", "--label", "org.opencontainers.image.revision=$revision",
        "--label", "org.opencontainers.image.version=$version", "--label", "io.gigatiff.local-dirty=$dirty")
    if ($Publish) {
        $args += "--push"
    } else {
        $args += @("--load", "--tag", $alias)
    }
    if (-not $SkipPull) { $args += "--pull" }
    if ($isServer) {
        $args += @("--build-arg", "GIGATIFF_BUILD_JOBS=$BuildJobs", "--build-arg", "GIGATIFF_BUILD_GROK=1",
            "--build-arg", "GIGATIFF_SERVER_FEATURES=jpeg2000-grok-ffi", "--build-arg", "GROK_REF=$($versions.build.grok)",
            "--build-arg", "RUST_IMAGE=$($versions.build.rust)", "--build-arg", "DEBIAN_RUNTIME_IMAGE=$($versions.build.debian)")
    }
    $args += $build.Context
    $destination = if ($Publish) { "publish to GHCR" } else { "local only" }
    Write-Host "Building $tag ($destination)"
    & docker @args 2>&1 | Tee-Object -FilePath "$OutputDirectory/$($build.Component).log"
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $tag. See $OutputDirectory" }
    if ($Publish) {
        $metadata = Get-Content -LiteralPath "$OutputDirectory/$($build.Component)-metadata.json" -Raw | ConvertFrom-Json
        $digest = $metadata.'containerimage.digest'
        if (-not $digest) { throw "Missing registry digest for $tag" }
        Invoke-Checked docker @("buildx", "imagetools", "inspect", "$tag@$digest") | Out-Host
        $report.images += [ordered]@{ component = $build.Component; tag = $tag; digest = $digest }
    } else {
        $inspect = (Invoke-Checked docker @("image", "inspect", $tag)) -join "`n" | ConvertFrom-Json
        $report.images += [ordered]@{ component = $build.Component; tag = $tag; alias = $alias; id = $inspect[0].Id }
    }
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding utf8
}
if ($Publish) {
    Write-Host "Images published to GHCR without GitHub Actions. Report: $reportPath"
} else {
    Write-Host "Local images ready. No registry upload or GitHub Actions were used. Report: $reportPath"
}
