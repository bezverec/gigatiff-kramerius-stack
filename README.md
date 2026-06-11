# GigaTIFF Kramerius Stack

This repository contains a reproducible local or LAN test deployment for the
GigaTIFF Kramerius Stack: Kramerius 7.2.1 connected to the GigaTIFF IIIF image
server.

It tracks configuration and installation scaffolding only. Runtime databases,
Akubra object-store data, Solr indexes, imported NDK packages, generated JP2
files, logs, caches and temporary files are intentionally ignored.

## Versioning

Stack version means a tested integration bundle. Component versions keep their
own upstream meaning.

Current bundle:

```text
GigaTIFF Kramerius Stack: stack-0.1.4
Runtime directory:          gigatiff-kramerius
```

Compatibility matrix:

```text
Core:
  Kramerius API:            7.2.1
  Kramerius web client v3:  3.0.15-beta
  Kramerius admin client:   c36565ff75591bc593bc042b31b83b7b6dd17869
  GigaTIFF server:          0.3.0
  Web-client auth shim:     0.1

Services:
  Curator worker:           7.2.1
  Public worker:            7.2.1
  Process manager:          1.5
  Solr:                     10.0.0
  PostgreSQL:               18.4
  Keycloak PostgreSQL:      14.10
  Keycloak:                 22.0.11-1.10
  Dragonfly:                1.30.3
```

The machine-readable source of truth is `versions.toml`.

## What This Stack Starts

- Kramerius 7.2.1 API and workers.
- PostgreSQL databases for Kramerius, Keycloak and the process manager.
- Solr 10 with user-managed cores.
- Keycloak for OAuth2 authentication.
- A small web-client auth shim for Keycloak login/token/logout routes.
- Kramerius web client with GigaTIFF branding.
- Kramerius admin client.
- GigaTIFF IIIF image server with Dragonfly response cache.
- Optional Dockhand and Dashy helper tools.

## Repository Layout

- `docker-compose.yml` - core Kramerius, Solr, Keycloak, workers, web client and admin client.
- `docker-compose.gigatiff.yml` - optional integrated GigaTIFF image server and Dragonfly cache.
- `docker-compose.tools.yml` - optional Dockhand and Dashy tools.
- `docker-compose.clean.yml` - clean-stack override for Buildah-built local images and bootstrap.
- `docker-compose.ghcr.yml` - clean-stack override for prebuilt GHCR images.
- `versions.toml` - stack version, component pins and GHCR image names.
- `Containerfile.clean-bootstrap` - small Debian Trixie bootstrap image for post-start checks and SQL helpers.
- `Dockerfile.auth-shim` - small Python auth bridge used by the web client.
- `mnt/import/.kramerius4` - Kramerius runtime configuration mounted into API and workers.
- `mnt/containers/solr/data` - Solr core configuration only, not generated indexes.
- `public/local-config` - web-client runtime configuration.
- `public/favicon.svg` - GigaTIFF favicon mounted into the web client.
- `ops/admin-client` - Docker build wrapper for the required admin client.
- `ops/auth-shim` - OAuth2 login/token/logout bridge for web-client v3.
- `ops/bootstrap` - clean-stack bootstrap entrypoint.
- `ops/web-client` - GigaTIFF web-client CSS and login fallback assets.
- `ops/keycloak/kramerius-realm.json` - disposable test realm import for Keycloak.
- `ops/dockhand/register-stack.sh` - Dockhand stack registration helper.
- `ops/dashy/conf.yml` - Dashy dashboard configuration.
- `ops/sql/grant-public-read.sql` - local test permission helper for public IMG_FULL access.
- `ops/sql/normalize-process-owners.sql` - local process manager owner cleanup helper.
- `scripts/build-clean-images.sh` - Buildah image builder for the clean stack.
- `scripts/build-ghcr-images.sh` - Buildah image builder using the public GHCR image tags.
- `scripts/prepare-clean-stack.sh` - creates a clean install directory from Git-managed files only.
- `scripts/configure-endpoints.*` - helpers for switching between localhost and LAN URLs.
- `scripts/grant-public-read.*` - helpers for applying the public read permission SQL.
- `scripts/normalize-process-owners.*` - helpers for fixing process owner JSON compatibility.

## Prerequisites

Install:

- Buildah on the Linux host that will build the clean local images.
- Docker with Compose v2.
- Git.
- PowerShell 7 or a POSIX shell, depending on which helper scripts you use.

Clone the required repositories side by side. Keep the source checkout and the
runtime deployment directory clearly separated; the examples use
`gigatiff-kramerius-stack-src` for the Git checkout and `gigatiff-kramerius`
for the live Compose stack.

```bash
mkdir services
cd services
git clone https://github.com/bezverec/gigatiff.git
git clone https://github.com/bezverec/gigatiff-kramerius-stack.git gigatiff-kramerius-stack-src
git clone https://github.com/ceskaexpedice/kramerius-admin-client.git
cd gigatiff-kramerius-stack-src
```

Expected layout:

```text
services/
  gigatiff/
  gigatiff-kramerius-stack-src/
  kramerius-admin-client/
```

The admin client checkout is required because the clean Buildah workflow builds
it from `../kramerius-admin-client`.

## Default Install

The preferred installation path is the clean Buildah stack. It is the only
recommended path for a reproducible test deployment.

Do not copy a running Kramerius directory to create a new install. A live
directory may contain PostgreSQL data, Solr indexes, Akubra object-store files,
converted JP2 files, logs and caches. The Buildah workflow creates fresh images
and a fresh stack directory from Git-managed configuration only.

The clean workflow includes:

- Kramerius configuration.
- Solr schema fixes.
- Keycloak realm import.
- GigaTIFF-branded web-client files.
- Web-client login bridge for Keycloak.
- Integrated GigaTIFF image server and Dragonfly cache.
- Admin-client build output.
- Bootstrap checks and local test SQL helpers.

It deliberately excludes:

- imported NDK packages,
- generated JP2/TIFF image payloads,
- Akubra object-store data,
- PostgreSQL data,
- Solr index data,
- GigaTIFF response cache,
- logs or temporary files.

From the repository checkout, prepare a clean runtime directory:

```bash
./scripts/prepare-clean-stack.sh /home/bezverec/services/gigatiff-kramerius
cd /home/bezverec/services/gigatiff-kramerius
```

Configure endpoint URLs for the target host:

```bash
./scripts/configure-endpoints.sh 10.0.120.30 0.0.0.0
```

If another Kramerius stack is already running on the same host, set alternate
ports before running the helper:

```bash
WEB_CLIENT_PORT=2234 \
ADMIN_CLIENT_PORT=2235 \
KRAMERIUS_API_PORT=28088 \
KRAMERIUS_DEBUG_PORT=25005 \
KRAMERIUS_AJP_PORT=28009 \
KEYCLOAK_PORT=28990 \
SOLR_PORT=28983 \
LOCK_SERVER_PORT_1=25701 \
LOCK_SERVER_PORT_2=25702 \
LOCK_SERVER_PORT_3=25703 \
PROCESS_MANAGER_PORT=28082 \
CURATOR_WORKER_PORT=28084 \
PUBLIC_WORKER_PORT=28086 \
KRAMERIUS_DB_PORT=60432 \
PROCESS_DB_PORT=60433 \
GIGATIFF_PORT=38082 \
DOCKHAND_PORT=23000 \
DASHY_PORT=28080 \
./scripts/configure-endpoints.sh 10.0.120.30 0.0.0.0
```

Build clean local images with Buildah. The build script reads `.env`, so run
endpoint configuration before this step:

```bash
./scripts/build-clean-images.sh
```

The script builds:

```text
localhost/gigatiff-kramerius-web-client:clean
localhost/gigatiff-kramerius-auth-shim:clean
localhost/gigatiff-kramerius-admin-client:clean
localhost/gigatiff-kramerius-bootstrap:clean
```

By default, it also publishes those images into the local Docker daemon so
Docker Compose can run them. Set `PUSH_TO_DOCKER=0` if you only want Buildah
storage images.

### GHCR Images

The same stack can use prebuilt images from GitHub Container Registry instead
of local Buildah images.

Published image names for `stack-0.1.4`:

```text
ghcr.io/bezverec/gigatiff-kramerius-web-client:stack-0.1.4
ghcr.io/bezverec/gigatiff-kramerius-auth-shim:stack-0.1.4
ghcr.io/bezverec/gigatiff-kramerius-admin-client:stack-0.1.4
ghcr.io/bezverec/gigatiff-kramerius-bootstrap:stack-0.1.4
ghcr.io/bezverec/gigatiff-server:0.3.0
```

To publish them from GitHub Actions, run the `Publish GHCR Images` workflow or
push a tag named like `stack-0.1.4`. The workflow reads `versions.toml`, checks
out the pinned admin client and GigaTIFF revisions, builds Linux `amd64` images,
adds OCI metadata, and publishes SBOM/provenance attestations.

To build the same tags locally with Buildah:

```bash
./scripts/build-ghcr-images.sh
```

By default this builds the GHCR-tagged images and also publishes them into the
local Docker daemon. To push to GHCR from a logged-in Buildah session:

```bash
buildah login ghcr.io
PUSH_TO_GHCR=1 ./scripts/build-ghcr-images.sh
```

To run the stack from GHCR images instead of local Buildah images, add
`docker-compose.ghcr.yml` after the clean and GigaTIFF files and explicitly
disable local builds:

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.clean.yml \
  -f docker-compose.gigatiff.yml \
  -f docker-compose.ghcr.yml \
  up -d --pull always --no-build
```

The admin-client image is runtime-configured from `.env`, so the same GHCR image
works for localhost and LAN deployments.

Start the clean stack, including the GigaTIFF image server:

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.clean.yml \
  -f docker-compose.gigatiff.yml \
  up -d
```

Run the bootstrap checks and disposable test permission helpers:

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.clean.yml \
  --profile bootstrap run --rm clean-bootstrap
```

`clean-bootstrap` waits for PostgreSQL, Solr, Keycloak and the Kramerius API,
checks that the Solr schema contains the fields required by our fixes, verifies
that the `kramerius` realm exists, applies `ops/sql/grant-public-read.sql`, and
applies `ops/sql/normalize-process-owners.sql`.

The clean stack imports the test Keycloak realm automatically from:

```text
ops/keycloak/kramerius-realm.json
```

The imported disposable user is:

```text
username: krameriusAdmin
password: krameriusAdmin
```

When you want to include the optional helper tools in the same clean deployment,
compose the tools file as well:

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.clean.yml \
  -f docker-compose.gigatiff.yml \
  -f docker-compose.tools.yml \
  --profile tools up -d
```

Use a new target directory for every clean deployment. Do not run
`prepare-clean-stack.sh` over a directory that already contains a live database,
Solr index or imported documents.

## Configuration

The clean stack is configured by `.env` plus mounted configuration files under
`mnt/import/.kramerius4`, `public/local-config` and `rewrite.config`.

Generate `.env` with `scripts/configure-endpoints.*`.

For a localhost-only workstation:

```bash
./scripts/configure-endpoints.sh 127.0.0.1 127.0.0.1
```

For a LAN host, for example ZimaBoard at `10.0.120.30`:

```bash
./scripts/configure-endpoints.sh 10.0.120.30 0.0.0.0
```

PowerShell equivalent:

```powershell
.\scripts\configure-endpoints.ps1 -PublicHost 10.0.120.30 -BindAddr 0.0.0.0
```

The helper updates:

- `.env`
- `mnt/import/.kramerius4/configuration.properties`
- `mnt/import/.kramerius4/keycloak.json`
- `mnt/import/.kramerius4/migration.properties`
- `public/local-config/gigatiff/config-main.json`
- `public/local-config/libraries.json`
- `rewrite.config`

The helper deliberately keeps two GigaTIFF addresses:

- `GIGATIFF_INTERNAL_BASE_URL` is written into `migration.properties` and is
  used by Kramerius and worker containers during import and image proxying.
- `http://<KRAMERIUS_PUBLIC_HOST>:<GIGATIFF_PORT>/iiif/3` is written into
  `rewrite.config` for browser-facing legacy IIP rewrites.

For the clean stack, keep `docker-compose.gigatiff.yml` running on
`GIGATIFF_PORT`. Imported Akubra datastreams store
`GIGATIFF_INTERNAL_BASE_URL`; if that URL points to
`host.docker.internal:<GIGATIFF_PORT>` but no GigaTIFF server listens there,
ordinary search endpoints can still return 200 while thumbnails, `IMG_FULL` and
`/search/iiif/.../info.json` return HTTP 500.

On Docker Desktop, the default internal URL is
`http://host.docker.internal:18082/iiif/3`. If you run the integrated GigaTIFF
service on the same Compose network and want containers to talk directly, set:

```bash
export GIGATIFF_INTERNAL_BASE_URL=http://gigatiff-server:8080/iiif/3
./scripts/configure-endpoints.sh 127.0.0.1 127.0.0.1
```

PowerShell equivalent:

```powershell
.\scripts\configure-endpoints.ps1 `
  -PublicHost 127.0.0.1 `
  -BindAddr 127.0.0.1 `
  -GigaTiffInternalBaseUrl http://gigatiff-server:8080/iiif/3
```

### Keycloak

The clean Buildah stack imports realm `kramerius` automatically from:

```text
ops/keycloak/kramerius-realm.json
```

The imported realm contains:

- public client `krameriusClient`,
- roles `common_users`, `public_users`, `kramerius_admin` and `k4_admins`,
- disposable user `krameriusAdmin` with password `krameriusAdmin`.

The test realm deliberately uses longer local-development session limits than
the Keycloak defaults:

```text
Access token lifespan:       3600 seconds
SSO session idle timeout:    28800 seconds
SSO session max lifespan:    86400 seconds
Client session idle timeout: 28800 seconds
Client session max lifespan: 86400 seconds
Login code lifespan:         1800 seconds
```

This avoids repeated automatic logout during longer Admin UI import and metadata
editing sessions.

Kramerius reads its Keycloak client settings from:

```text
mnt/import/.kramerius4/keycloak.json
mnt/import/.kramerius4/configuration.properties
```

The expected values are:

```properties
keycloak.realm=kramerius
keycloak.clientId=krameriusClient
keycloak.tokenurl=http://keycloak.localhost:8990/realms/kramerius/protocol/openid-connect/token
```

For a LAN clean stack, the generated token URL uses the LAN host instead, for
example:

```properties
keycloak.tokenurl=http://10.0.120.30:28990/realms/kramerius/protocol/openid-connect/token
```

and:

```json
{
  "realm": "kramerius",
  "auth-server-url": "http://keycloak.localhost:8990/",
  "resource": "krameriusClient",
  "verify-token-audience": false,
  "bearer-only": true,
  "public-client": true
}
```

`keycloak.localhost` is intentional for local Docker use: it is resolvable from
both the host browser and the Kramerius container when the browser runs on the
same machine. For LAN deployments, the endpoint helper defaults
`KEYCLOAK_PUBLIC_HOST` to `KRAMERIUS_PUBLIC_HOST`, for example
`10.0.120.30`, so OAuth redirects are reachable from other computers.

Override `KEYCLOAK_PUBLIC_HOST` explicitly only when Keycloak should be exposed
through a different DNS name or reverse proxy.

### Development Compose Workflow

The plain Compose workflow is kept for development and debugging only. It is not
the preferred clean installation path.

Use it when iterating on Compose files or local configuration in the repository
checkout:

```bash
docker compose up -d --build
```

Watch startup:

```bash
docker compose ps
docker compose logs -f --tail=100 kramerius
```

The first start can take a while because databases and Solr cores need to
initialize.

For a fresh machine, also check that the process manager and both workers are
running. Imports can be scheduled from the admin client even when workers are not
yet polling correctly:

```bash
docker compose ps processManager curatorWorker publicWorker
docker compose logs --tail=100 processManager curatorWorker publicWorker
```

If you use the development workflow without `docker-compose.clean.yml`, create
or import the Keycloak realm manually or adapt the clean realm import override
for your local workflow.

## GigaTIFF Server

If you already run GigaTIFF elsewhere, keep it listening on the configured
`GIGATIFF_PORT`, default `18082`.

To run the integrated GigaTIFF image server next to Kramerius:

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.clean.yml \
  -f docker-compose.gigatiff.yml \
  up -d --build gigatiff-server
```

The integrated GigaTIFF compose uses:

- Dragonfly response cache.
- `jpeg2000-grok-ffi` server feature.
- cache namespace `gigatiff-server-response-v12-jp2-auto-fix`.
- OpenJPEG FFI for full-resolution JP2 tiles and Grok FFI for reduced JP2 tiles.

Check readiness:

```bash
curl "http://127.0.0.1:${GIGATIFF_PORT:-18082}/readyz"
curl "http://127.0.0.1:${GIGATIFF_PORT:-18082}/metrics"
```

## Optional Tools

Dockhand provides a lightweight Docker UI. Dashy provides a link dashboard.
Dashy browser links point to `127.0.0.1`, while its status checks use Docker
service names so they work from inside the Dashy container.

Run the tools from the clean stack directory so they join the same Compose
project and Docker network as Kramerius.

Start both:

```bash
docker compose -f docker-compose.tools.yml --profile tools up -d
```

If you want to start the clean stack, GigaTIFF and the tools in one command,
use:

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.clean.yml \
  -f docker-compose.gigatiff.yml \
  -f docker-compose.tools.yml \
  --profile tools up -d
```

Stop them:

```bash
docker compose -f docker-compose.tools.yml --profile tools down
```

Dashy config lives in:

```text
ops/dashy/conf.yml
```

Each Dashy item has two URLs:

- `url` is the browser-facing localhost URL opened when you click the item.
- `statusCheckUrl` is the container-facing URL used by Dashy health checks.

For example, the web client opens as `http://127.0.0.1:1234` in your browser,
but Dashy checks it from inside Docker as `http://web-client/`. If Dashy shows a
service as down while the browser link works, check that the service name in
`statusCheckUrl` matches the Compose service and that the tools were started
from this repo directory. Services from optional profiles, such as GigaTIFF, are
expected to show as down until that profile is running.

Dockhand gets the local compose stack registered automatically by
`dockhand-init`. The repo is mounted into the Dockhand container at:

```text
/workspace/gigatiff-kramerius
```

The registered stack points Dockhand at:

```text
/workspace/gigatiff-kramerius/docker-compose.yml
```

For the clean Buildah stack, add `docker-compose.clean.yml` in Dockhand when you
edit the registered stack.

If a `.env` file exists in the repository root, `dockhand-init` registers it as:

```text
/workspace/gigatiff-kramerius/.env
```

The Docker socket is mounted into Dockhand, so it should manage the local Docker
daemon directly. If Dockhand shows connection errors, first check:

```bash
docker compose -f docker-compose.tools.yml --profile tools logs dockhand-init
docker compose -f docker-compose.tools.yml --profile tools logs dockhand
```

`dockhand-init` is idempotent. Re-run it after changing stack paths or the `.env`
file:

```bash
docker compose -f docker-compose.tools.yml --profile tools up dockhand-init
```

If you deploy on a LAN host, update URLs in `ops/dashy/conf.yml` or regenerate
endpoint config first and adapt the dashboard manually.

Portainer is intentionally not part of this stack. Use Dockhand for this test
deployment to keep the operations surface small.

## Service URLs

With default localhost settings:

- Web client: `http://127.0.0.1:1234`
- Admin client: `http://127.0.0.1:1235`
- Kramerius API: `http://127.0.0.1:8088`
- Keycloak: `http://127.0.0.1:8990`
- Solr: `http://127.0.0.1:8983`
- GigaTIFF: `http://127.0.0.1:18082`
- Dockhand: `http://127.0.0.1:3000`
- Dashy: `http://127.0.0.1:18080`

For a LAN deployment, replace `127.0.0.1` with `KRAMERIUS_PUBLIC_HOST`.

Example ports used for the side-by-side ZimaBoard clean stack:

- Web client: `http://10.0.120.30:2234`
- Admin client: `http://10.0.120.30:2235`
- Kramerius API: `http://10.0.120.30:28088`
- Keycloak: `http://10.0.120.30:28990`
- Solr: `http://10.0.120.30:28983`

## Import Test Data

Put NDK import packages into:

```text
mnt/import/.kramerius4/convert
```

Generated conversion output is written under:

```text
mnt/imageserver/iip-data
```

Those directories are ignored by Git.

The import configuration is set for IIIF Image API 3 URLs:

```properties
convert.useImageServer=true
convert.imageServerTilesURLPrefix=http://host.docker.internal:18082/iiif/3
convert.imageServerImagesURLPrefix=http://host.docker.internal:18082/iiif/3
convert.imageServerSuffix.removeFilenameExtensions=false
convert.imageServerSuffix.tiles=
convert.imageServerSuffix.big=/full/max/0/default.jpg
convert.imageServerSuffix.thumb=/full/,128/0/default.jpg
convert.imageServerSuffix.preview=/full/,700/0/default.jpg
convert.imageServerDirectory=/mnt/imageserver/iip-data
convert.imageServerDirectorySubfolders=true
```

`convert.imageServerSuffix.tiles` must stay empty. Kramerius appends
`/info.json` itself when proxying IIIF tiles. If the stored `tiles-url` already
contains `/info.json`, Kramerius will request `.../info.json/info.json` and the
viewer will fail.

When an import finishes, check the follow-up index process as well as the import
process. A successful conversion can still be followed by a failed reindex if
Solr rejects a field:

```bash
docker compose logs --tail=200 curatorWorker
docker compose logs --tail=200 solr
```

If the admin client process list fails with `JSONObject["owner"] not a string.`,
run the owner normalization helper before retrying the process view:

```bash
./scripts/normalize-process-owners.sh
```

## Post-Install Public Access

After the first Kramerius boot and before testing public full-image access, run:

```bash
./scripts/grant-public-read.sh
```

PowerShell equivalent:

```powershell
.\scripts\grant-public-read.ps1
```

This applies `ops/sql/grant-public-read.sql`, granting root `a_read` to
`common_users` if it is missing. Without it, anonymous users may see thumbnails
but receive 403 for `IMG_FULL` or IIIF `info.json`.

## Local Fixes and Compatibility Notes

This test stack contains a few deliberate local fixes. They are part of the
reproducible setup, not accidental generated state.

### Solr 10 schema

The Solr configuration under:

```text
mnt/containers/solr/data
```

is tracked in Git on purpose. Do not replace it with a freshly generated empty
Solr core.

The file:

```text
mnt/containers/solr/data/MUST_BE_SYNC_WITH_PROJECT.txt
```

documents that the local Solr config should stay in sync with the upstream
Kramerius Solr 9.x installation profile:

```text
https://github.com/ceskaexpedice/kramerius/tree/master/installation/solr-9.x
```

The most important core for the web client is:

```text
mnt/containers/solr/data/search/conf/managed-schema
```

It includes fields used by the Kramerius/CDK web client detail and periodical
views, for example:

- `pid`
- `model`
- `accessibility`
- `root.pid`
- `own_parent.pid`
- `date.str`
- `date.min`
- `part.number.str`
- `issue.type.code`
- `licenses`
- `contains_licenses`
- `licenses.facet`

It also includes fields emitted by the Kramerius 7.2 indexer and by the
upstream Solr 9.x profile, for example:

- `authors.aut.facet`
- `authors.aut.identifiers`
- `coords.is_point`
- `date_instant.year`
- `subject_names_personal.search`
- `subject_names_corporate.facet`
- `subject_temporals.search`
- `subtype`

It also keeps copy rules used by license facets:

```xml
<copyField source="contains_licenses" dest="licenses.facet"/>
<copyField source="licenses" dest="licenses.facet"/>
<copyField source="licenses_of_ancestors" dest="licenses.facet"/>
```

If the schema is incomplete, the web client can load the root object but fail on
children/facet queries with HTTP 500 responses from Kramerius. A typical failing
query asks Solr for fields such as `date.str`, `own_parent.pid`,
`issue.type.code`, `licenses` or sorts by `date.min`. Import or reindex jobs can
also fail with Solr `unknown field` errors for newer indexer fields such as
`authors.aut.facet` or `authors.aut.identifiers`.

When changing Solr schema files:

1. Stop Kramerius and Solr.
2. Keep `mnt/containers/solr/data/*/conf/managed-schema` under version control.
3. Remove generated Solr indexes only if you want a clean reindex.
4. Start Solr and Kramerius again.
5. Reindex or reimport affected objects.

For a quick schema sanity check:

```bash
grep -n 'own_parent.pid\|date.str\|licenses.facet\|authors.aut.identifiers\|subject_names_personal.search' \
  mnt/containers/solr/data/search/conf/managed-schema
```

The Czech Hunspell dictionary files referenced by `managed-schema` are tracked
with the Solr config so a fresh Solr core can start without missing analyzer
resources.

The `logs` core configuration is tracked as well. Kramerius writes access and
DNNT statistics there when documents and pages are opened. Its schema keeps
`date.str` as a string, year fields as integers and an `*_str` dynamic field for
Solr's schemaless copy-field processor. Without this, page access can still work
but Kramerius logs repeated Solr 500 errors such as:

```text
copyField dest :'date.str_str' is not an explicit field and doesn't match a dynamicField.
```

### Public `IMG_FULL` access

`ops/sql/grant-public-read.sql` is an idempotent local test helper. It grants
root `a_read` to `common_users`.

This fixes the local-test situation where thumbnails are visible, but anonymous
users are still denied full images and IIIF `info.json` with HTTP 403.

Apply it after the first boot:

```bash
./scripts/grant-public-read.sh
```

### Process manager owner JSON compatibility

Kramerius admin client expects process `owner` values to be strings. Local or
manual process calls can leave older rows with `owner` as `NULL` or empty, which
can surface in the admin client as:

```text
JSONObject["owner"] not a string.
```

Normalize existing rows after a clean rebuild or after manual process-manager
API calls:

```bash
./scripts/normalize-process-owners.sh
```

PowerShell equivalent:

```powershell
.\scripts\normalize-process-owners.ps1
```

### IIIF image URL suffixes

`mnt/import/.kramerius4/migration.properties` stores image-server URL suffixes.
The important values are:

```properties
convert.imageServerSuffix.tiles=
convert.imageServerSuffix.big=/full/max/0/default.jpg
convert.imageServerSuffix.thumb=/full/,128/0/default.jpg
convert.imageServerSuffix.preview=/full/,700/0/default.jpg
```

`convert.imageServerSuffix.tiles` must stay empty because Kramerius appends
`/info.json` when proxying IIIF tile metadata. If `/info.json` is stored in the
datastream already, requests can become `.../info.json/info.json`.

### Legacy IIP rewrite rules

`rewrite.config` maps old IIP-style requests to GigaTIFF IIIF Image API 3 URLs.
This lets Kramerius paths that still call `/fcgi-bin/iipsrv.fcgi` resolve to the
same JP2 files served by GigaTIFF.

Examples:

```text
FIF=...&HEI=128&CVT=jpeg  -> /iiif/3/.../full/,128/0/default.jpg
FIF=...&HEI=700&CVT=jpeg  -> /iiif/3/.../full/,700/0/default.jpg
FIF=...&CVT=jpeg          -> /iiif/3/.../full/max/0/default.jpg
iiif=.../info.json        -> /iiif/3/.../info.json
```

Run `scripts/configure-endpoints.*` again after changing the public host,
because it rewrites GigaTIFF URL prefixes in `rewrite.config`.

### Truncated thumbnail URLs

Some imported thumbnail URLs were observed to reach GigaTIFF as:

```text
/iiif/3/<identifier>/full/
```

instead of the complete:

```text
/iiif/3/<identifier>/full/,128/0/default.jpg
```

GigaTIFF contains a compatibility fallback for that truncated Kramerius
thumbnail form and treats it as a 128-pixel-high JPEG thumbnail. Without that
fallback, Kramerius reports thumbnail HTTP 500 errors because GigaTIFF correctly
rejects the incomplete IIIF URL with HTTP 400.

### Web client favicon and proxy behavior

The web client image is built through `Dockerfile.web-client-gigatiff` and uses:

```text
web-client-entrypoint.sh
web-client-nginx.conf
public/favicon.svg
public/local-config
ops/web-client/gigatiff-square.css
ops/web-client/gigatiff-login-shortcut.js
```

The entrypoint injects local runtime URLs and replaces the upstream favicon with
the GigaTIFF SVG. The nginx config proxies `/search/` to Kramerius and serves
legacy favicon paths from the same SVG to avoid stale browser icon references.

The entrypoint also injects a small GigaTIFF UI override. It keeps the current
web client functional, but makes the local test build visually sharper by
removing most rounded corners and by adding a visible login fallback button when
the upstream header does not render one. The fallback follows the upstream CDK
flow: from regular pages it opens `/pages/terms?returnUrl=...`, and from the
terms page it starts OAuth login through `/auth/login`.

### Web client auth bridge

The Kramerius web client v3 beta expects these same-origin routes:

```text
/auth/login
/auth/token
/auth/logout
```

Kramerius 7.2.1 exposes a different authentication facade, so the stack runs a
small `auth-shim` service built from `Dockerfile.auth-shim`. The web-client
nginx configuration proxies both `/auth/*` and
`/search/api/client/v7.0/auth/*` to this shim.

The shim:

- redirects `/auth/login` to the configured Keycloak realm,
- exchanges `code` for tokens through the internal Keycloak URL,
- refreshes tokens through the same Keycloak token endpoint,
- redirects `/auth/logout` to Keycloak logout,
- exposes `/auth/healthz` for quick checks.

The public redirect target is controlled by:

```env
KEYCLOAK_PUBLIC_HOST=10.0.120.30
KEYCLOAK_PORT=8990
WEB_CLIENT_PORT=1234
```

For a LAN deployment, the expected quick check is:

```bash
curl http://127.0.0.1:1234/auth/healthz
curl -D - -o /dev/null "http://127.0.0.1:1234/auth/login?redirect_uri=http%3A%2F%2F10.0.120.30%3A1234%2Fauth%2Fcallback"
```

## Admin Client Notes

The stack expects `../kramerius-admin-client` to exist before `docker compose up`.

The admin build uses:

```text
ops/admin-client/Dockerfile.gigatiff
```

It injects local GigaTIFF and Kramerius URLs into:

```text
assets/shared/globals.js
```

If the public host or ports change, rerun `scripts/configure-endpoints.*` and
rebuild the admin client:

```bash
docker compose up -d --build admin-client
```

## Troubleshooting

Check stack status:

```bash
docker compose ps
docker compose logs --tail=100 kramerius
```

Check Keycloak:

```bash
docker compose ps keycloak_eduid
curl http://127.0.0.1:8990
```

Check web-client login bridge:

```bash
docker compose ps auth-shim web-client
curl http://127.0.0.1:1234/auth/healthz
curl -D - -o /dev/null "http://127.0.0.1:1234/auth/login?redirect_uri=http%3A%2F%2F127.0.0.1%3A1234%2Fauth%2Fcallback"
curl -fsS http://127.0.0.1:1234/ | grep -E 'gigatiff-square|gigatiff-login-shortcut'
```

Check GigaTIFF:

```bash
curl http://127.0.0.1:18082/readyz
curl http://127.0.0.1:18082/metrics
```

If login redirects still use `keycloak.localhost` from a LAN browser, or the web
client login button sends users to an unreachable host, rerun the endpoint
helper with the LAN host and restart Keycloak, Kramerius, auth-shim and the web
client:

```bash
./scripts/configure-endpoints.sh 10.0.120.30 0.0.0.0
docker compose -f docker-compose.yml -f docker-compose.clean.yml up -d keycloak_eduid kramerius auth-shim web-client admin-client
```

For the side-by-side ZimaBoard clean stack, keep the alternate ports in `.env`
when rerunning the helper.

Use one browser hostname consistently during login. Mixing `127.0.0.1`,
`localhost`, `keycloak.localhost` and a LAN IP in the same login flow can leave
stale Keycloak cookies and produce:

```text
Cookie not found. Please make sure cookies are enabled in your browser.
```

If that happens, close old login tabs, clear cookies for the Keycloak host you
are using, rerun `scripts/configure-endpoints.*` with the intended public hosts,
and rebuild/restart `web-client`, `admin-client`, `keycloak_eduid` and
`kramerius`.

If the web client still shows MZK/CDK data, verify the runtime config served by
the local nginx container:

```bash
curl http://127.0.0.1:1234/local-config/libraries.json
curl http://127.0.0.1:1234/local-config/gigatiff/config-main.json
```

The browser console should report that configuration was loaded for library
`gigatiff`, and API calls should go to `http://127.0.0.1:8088`, or to your
configured `KRAMERIUS_PUBLIC_HOST`. If not, rerun `scripts/configure-endpoints.*`,
rebuild `web-client`, and hard-refresh the browser.

If thumbnails load but the main image returns 403, apply:

```bash
./scripts/grant-public-read.sh
```

If IIIF `info.json` returns 500 and logs show a URL ending in
`info.json/info.json`, verify:

```properties
convert.imageServerSuffix.tiles=
```

Then re-import the affected object or patch existing Akubra FOXML datastreams.

If small thumbnails return 500 and Kramerius logs show a GigaTIFF URL ending in
`/full/`, make sure GigaTIFF includes the compatibility fallback for truncated
Kramerius thumbnail URLs.

## Upgrades

Treat upgrades as clean rebuilds unless you intentionally want to preserve
runtime databases and imported documents.

Recommended upgrade flow:

```bash
cd /home/bezverec/services/gigatiff-kramerius-stack-src
git pull --ff-only
./scripts/prepare-clean-stack.sh /home/bezverec/services/gigatiff-kramerius-new
cd /home/bezverec/services/gigatiff-kramerius-new
./scripts/configure-endpoints.sh 10.0.120.30 0.0.0.0
./scripts/build-clean-images.sh
docker compose \
  -f docker-compose.yml \
  -f docker-compose.clean.yml \
  -f docker-compose.gigatiff.yml \
  up -d
docker compose \
  -f docker-compose.yml \
  -f docker-compose.clean.yml \
  --profile bootstrap run --rm clean-bootstrap
```

For side-by-side testing, use alternate ports as shown in `Default Install`.
After the new stack is verified, switch external routing or bookmarks to the new
ports. Keep the previous stack directory until the new one is confirmed.

When changing Kramerius, Solr, Keycloak or admin-client versions:

- update `versions.toml`,
- update image tags in the Compose files,
- rebuild the Buildah images,
- republish GHCR images when the tested bundle changes,
- run `docker compose config --quiet`,
- run `clean-bootstrap`,
- check Solr logs for schema/index incompatibilities,
- reimport or reindex test documents if the Solr schema changed.

Do not copy old `mnt/containers/*` database or Solr index directories into a
clean upgrade unless you are explicitly testing an in-place data migration.

## Stop and Cleanup

Stop containers without deleting data:

```bash
docker compose -f docker-compose.yml -f docker-compose.clean.yml down
docker compose -f docker-compose.gigatiff.yml down
docker compose -f docker-compose.tools.yml --profile tools down
```

Runtime data lives under:

```text
mnt/
logs/
temp/
cache/
```

Delete those directories only when you intentionally want a fresh test instance.

## Local Test Credentials

These credentials are disposable and must not be reused in production:

- PostgreSQL Kramerius: `fedoraAdmin/fedoraAdmin`
- PostgreSQL process manager: `process/process`
- Keycloak admin: `keycloakAdmin/keycloakAdmin`
- Example Keycloak/Kramerius admin user: `krameriusAdmin/krameriusAdmin`

For production-like testing, replace all passwords, restrict bind addresses and
review every public port before exposing the stack.
