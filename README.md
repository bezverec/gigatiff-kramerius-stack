# Kramerius 7.2.1 Test Stack for GigaTIFF

This repository contains a reproducible local or LAN test deployment for
Kramerius 7.2.1 connected to the GigaTIFF IIIF image server.

It tracks configuration and installation scaffolding only. Runtime databases,
Akubra object-store data, Solr indexes, imported NDK packages, generated JP2
files, logs, caches and temporary files are intentionally ignored.

## What This Stack Starts

- Kramerius 7.2.1 API and workers.
- PostgreSQL databases for Kramerius, Keycloak and the process manager.
- Solr 10 with user-managed cores.
- Keycloak for OAuth2 authentication.
- Kramerius web client with GigaTIFF branding.
- Kramerius admin client.
- Optional GigaTIFF IIIF image server with Dragonfly response cache.
- Optional Dockhand and Dashy helper tools.

## Repository Layout

- `docker-compose.yml` - core Kramerius, Solr, Keycloak, workers, web client and admin client.
- `docker-compose.gigatiff.yml` - optional integrated GigaTIFF image server and Dragonfly cache.
- `docker-compose.tools.yml` - optional Dockhand and Dashy tools.
- `mnt/import/.kramerius4` - Kramerius runtime configuration mounted into API and workers.
- `mnt/containers/solr/data` - Solr core configuration only, not generated indexes.
- `public/local-config` - web-client runtime configuration.
- `public/favicon.svg` - GigaTIFF favicon mounted into the web client.
- `ops/admin-client` - Docker build wrapper for the required admin client.
- `ops/dashy/conf.yml` - Dashy dashboard configuration.
- `ops/sql/grant-public-read.sql` - local test permission helper for public IMG_FULL access.
- `scripts/configure-endpoints.*` - helpers for switching between localhost and LAN URLs.
- `scripts/grant-public-read.*` - helpers for applying the public read permission SQL.

## Prerequisites

Install:

- Docker with Compose v2.
- Git.
- PowerShell 7 or a POSIX shell, depending on which helper scripts you use.

Clone the required repositories side by side:

```bash
mkdir services
cd services
git clone https://github.com/bezverec/gigatiff.git
git clone https://github.com/bezverec/kramerius-test.git
git clone https://github.com/ceskaexpedice/kramerius-admin-client.git
cd kramerius-test
```

Expected layout:

```text
services/
  gigatiff/
  kramerius-test/
  kramerius-admin-client/
```

The admin client checkout is required because `docker-compose.yml` builds it
from `../kramerius-admin-client`.

## Step 1: Configure Host URLs

Copy or generate `.env` before starting the stack.

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

## Step 2: Start Keycloak First

Start Keycloak and its database:

```bash
docker compose up -d keycloakPostgres_eduid keycloak_eduid
```

Wait until Keycloak is healthy:

```bash
docker compose ps keycloak_eduid
```

Open Keycloak:

```text
http://127.0.0.1:8990
```

On a LAN host, replace `127.0.0.1` with your `KRAMERIUS_PUBLIC_HOST`.

Default Keycloak admin credentials for this test stack:

```text
username: keycloakAdmin
password: keycloakAdmin
```

## Step 3: Create the Keycloak Realm

In the Keycloak admin console:

1. Create realm `kramerius`.
2. Create client `krameriusClient`.
3. Set client type to public:
   - Client authentication: off.
   - Standard flow: on.
   - Direct access grants: on.
4. Configure valid redirect URIs:
   - Localhost: `http://127.0.0.1:1234/*`
   - LAN example: `http://10.0.120.30:1234/*`
   - Admin client, if used through browser redirects: `http://127.0.0.1:1235/*`
5. Configure web origins:
   - Localhost: `http://127.0.0.1:1234`
   - LAN example: `http://10.0.120.30:1234`
   - Or use `+` for a quick disposable test setup.
6. Create roles:
   - `common_users`
   - `public_users`
   - `kramerius_admin`
   - `k4_admins`
7. Create user `krameriusAdmin`.
8. Set password `krameriusAdmin` and disable temporary password.
9. Assign the roles above to `krameriusAdmin`.

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

and:

```json
{
  "realm": "kramerius",
  "auth-server-url": "http://127.0.0.1:8990/",
  "resource": "krameriusClient",
  "public-client": true
}
```

The endpoint helper rewrites `auth-server-url` for LAN deployments.

## Step 4: Start the Core Stack

Start Kramerius, Solr, workers, web client and admin client:

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

## Step 5: Start GigaTIFF

If you already run GigaTIFF elsewhere, keep it listening on the configured
`GIGATIFF_PORT`, default `18082`.

To run the integrated GigaTIFF image server next to Kramerius:

```bash
docker compose -f docker-compose.yml -f docker-compose.gigatiff.yml up -d --build gigatiff-server
```

The integrated GigaTIFF compose uses:

- Dragonfly response cache.
- `jpeg2000-grok-ffi` server feature.
- cache namespace `gigatiff-server-response-v12-jp2-auto-fix`.
- OpenJPEG FFI for full-resolution JP2 tiles and Grok FFI for reduced JP2 tiles.

Check readiness:

```bash
curl http://127.0.0.1:18082/readyz
curl http://127.0.0.1:18082/metrics
```

## Step 6: Start Optional Tools

Dockhand provides a lightweight Docker UI. Dashy provides a link dashboard.

Start both:

```bash
docker compose -f docker-compose.tools.yml --profile tools up -d
```

Stop them:

```bash
docker compose -f docker-compose.tools.yml --profile tools down
```

Dashy config lives in:

```text
ops/dashy/conf.yml
```

If you deploy on a LAN host, update URLs in `ops/dashy/conf.yml` or regenerate
endpoint config first and adapt the dashboard manually.

Portainer is intentionally not part of this stack. Use Dockhand for this test
deployment to keep the operations surface small.

## Step 7: Open the Services

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

## Step 8: Import Test Data

Put NDK import packages into:

```text
mnt/import/.kramerius4/import
```

Generated conversion output is written under:

```text
mnt/import/.kramerius4/convert
mnt/imageserver/iip-data
```

Those directories are ignored by Git.

The import configuration is set for IIIF Image API 3 URLs:

```properties
convert.useImageServer=true
convert.imageServerTilesURLPrefix=http://127.0.0.1:18082/iiif/3
convert.imageServerImagesURLPrefix=http://127.0.0.1:18082/iiif/3
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

## Step 9: Grant Public Full-Image Access

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

It also keeps copy rules used by license facets:

```xml
<copyField source="contains_licenses" dest="licenses.facet"/>
<copyField source="licenses" dest="licenses.facet"/>
<copyField source="licenses_of_ancestors" dest="licenses.facet"/>
```

If the schema is incomplete, the web client can load the root object but fail on
children/facet queries with HTTP 500 responses from Kramerius. A typical failing
query asks Solr for fields such as `date.str`, `own_parent.pid`,
`issue.type.code`, `licenses` or sorts by `date.min`.

When changing Solr schema files:

1. Stop Kramerius and Solr.
2. Keep `mnt/containers/solr/data/*/conf/managed-schema` under version control.
3. Remove generated Solr indexes only if you want a clean reindex.
4. Start Solr and Kramerius again.
5. Reindex or reimport affected objects.

For a quick schema sanity check:

```bash
grep -n 'own_parent.pid\|date.str\|licenses.facet' \
  mnt/containers/solr/data/search/conf/managed-schema
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
```

The entrypoint injects local runtime URLs and replaces the upstream favicon with
the GigaTIFF SVG. The nginx config proxies `/search/` to Kramerius and serves
legacy favicon paths from the same SVG to avoid stale browser icon references.

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

Check GigaTIFF:

```bash
curl http://127.0.0.1:18082/readyz
curl http://127.0.0.1:18082/metrics
```

If login redirects point to `keycloak.localhost` or `127.0.0.1` from a LAN
client, rerun:

```bash
./scripts/configure-endpoints.sh 10.0.120.30 0.0.0.0
docker compose up -d --build web-client admin-client keycloak_eduid kramerius
```

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

## Stop and Cleanup

Stop containers without deleting data:

```bash
docker compose down
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
