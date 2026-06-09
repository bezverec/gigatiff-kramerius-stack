# Kramerius 7.2.1 test stack for GigaTIFF

This repository contains a reproducible local/LAN test deployment for Kramerius
7.2.1 connected to the GigaTIFF IIIF image server.

The repository tracks configuration and installation scaffolding only. Runtime
databases, Akubra object store data, Solr indexes, imported NDK packages,
generated JP2 files, logs and caches are intentionally ignored.

## Layout

- `docker-compose.yml` - Kramerius, Solr, Keycloak, workers, web client, and admin client.
- `docker-compose.gigatiff.yml` - optional side-by-side GigaTIFF image server and Dragonfly cache.
- `docker-compose.tools.yml` - optional Dockhand and Dashy tools.
- `mnt/import/.kramerius4` - Kramerius runtime configuration used by the API and workers.
- `mnt/containers/solr/data` - Solr core configuration only, not indexes.
- `public/local-config` - GigaTIFF-branded web client runtime configuration.
- `ops/sql/grant-public-read.sql` - idempotent local test permission fix for public IMG_FULL access.
- `scripts/configure-endpoints.*` - helper to switch between localhost and LAN host URLs.

## Requirements

- Docker with Compose v2.
- For integrated GigaTIFF: a side-by-side `../gigatiff` checkout.
- A side-by-side `../kramerius-admin-client` checkout. The admin client is required by this test stack.

Recommended side-by-side layout:

```text
services/
  gigatiff/
  kramerius-test/
  kramerius-admin-client/
```

## Configure Host URLs

Local workstation:

```bash
./scripts/configure-endpoints.sh 127.0.0.1 127.0.0.1
```

LAN test server, for example ZimaBoard at `10.0.120.30`:

```bash
./scripts/configure-endpoints.sh 10.0.120.30 0.0.0.0
```

PowerShell equivalent:

```powershell
.\scripts\configure-endpoints.ps1 -PublicHost 10.0.120.30 -BindAddr 0.0.0.0
```

The helper updates `.env`, `keycloak.json`, web client config,
`migration.properties`, and `rewrite.config`.

## Start

Core Kramerius stack, including the web and admin clients, expecting an
external GigaTIFF server on port `18082`:

```bash
docker compose up -d --build
```

Core stack plus integrated GigaTIFF image server:

```bash
docker compose -f docker-compose.yml -f docker-compose.gigatiff.yml up -d --build
```

Optional Dockhand and Dashy:

```bash
docker compose -f docker-compose.tools.yml --profile tools up -d
```

Stop:

```bash
docker compose down
docker compose -f docker-compose.tools.yml --profile tools down
```

## Default URLs

With default localhost settings:

- Web client: `http://127.0.0.1:1234`
- Admin client: `http://127.0.0.1:1235`
- Kramerius API: `http://127.0.0.1:8088`
- Keycloak: `http://127.0.0.1:8990`
- Solr: `http://127.0.0.1:8983`
- GigaTIFF: `http://127.0.0.1:18082`
- Dockhand: `http://127.0.0.1:3000`
- Dashy: `http://127.0.0.1:18080`
- Portainer, if installed separately on the host: `https://127.0.0.1:9443`

## GigaTIFF Integration Notes

The import configuration is set for IIIF Image API 3 URLs:

```properties
convert.imageServerTilesURLPrefix=http://127.0.0.1:18082/iiif/3
convert.imageServerImagesURLPrefix=http://127.0.0.1:18082/iiif/3
convert.imageServerSuffix.removeFilenameExtensions=false
convert.imageServerSuffix.tiles=
```

`convert.imageServerSuffix.tiles` must stay empty. Kramerius appends
`/info.json` itself when proxying IIIF tiles. If the stored `tiles-url` already
contains `/info.json`, Kramerius will request `.../info.json/info.json` and the
viewer will fail.

The integrated GigaTIFF compose uses:

- Dragonfly response cache.
- `jpeg2000-grok-ffi` server feature.
- cache namespace `gigatiff-server-response-v12-jp2-auto-fix`.
- OpenJPEG FFI for full-resolution JP2 tiles and Grok FFI for reduced JP2 tiles.

## Import Workspace

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

After the first Kramerius boot and before testing public full-image access, run:

```bash
./scripts/grant-public-read.sh
```

or:

```powershell
.\scripts\grant-public-read.ps1
```

This applies `ops/sql/grant-public-read.sql`, granting root `a_read` to
`common_users` if it is missing. Without it, anonymous users may see thumbnails
but receive 403 for `IMG_FULL` / IIIF `info.json`.

## Admin Client

The stack expects `../kramerius-admin-client` to exist before `docker compose up`.

```bash
git clone https://github.com/ceskaexpedice/kramerius-admin-client.git ../kramerius-admin-client
docker compose up -d --build admin-client
```

The admin build uses `ops/admin-client/Dockerfile.gigatiff`, which injects local
GigaTIFF/Kramerius URLs into `assets/shared/globals.js`.

## Optional Tools

Dockhand is useful for inspecting containers through the Docker socket.

Dashy provides a simple URL dashboard. The default config is
`ops/dashy/conf.yml`; edit it if your public host or ports differ from the
defaults, or regenerate endpoint config first.

The Dashy Portainer entry is only a convenience link for an existing host
Portainer installation. The recommended Portainer URL is HTTPS on port `9443`;
do not point it at unrelated local services such as port `5050`.

## Troubleshooting

Check stack status:

```bash
docker compose ps
docker compose logs --tail=100 kramerius
```

Check GigaTIFF readiness:

```bash
curl http://127.0.0.1:18082/readyz
curl http://127.0.0.1:18082/metrics
```

If thumbnails load but the main image returns 403, apply:

```bash
./scripts/grant-public-read.sh
```

If IIIF `info.json` returns 500 and logs show a URL ending in
`info.json/info.json`, verify `convert.imageServerSuffix.tiles=` and re-import
or patch existing Akubra FOXML datastreams.

If browser redirects point to `127.0.0.1` from a LAN client, rerun
`scripts/configure-endpoints.*` with the LAN host and recreate the affected
containers.

## Local Credentials

These are disposable test credentials only:

- PostgreSQL Kramerius: `fedoraAdmin/fedoraAdmin`
- PostgreSQL process manager: `process/process`
- Keycloak admin: `keycloakAdmin/keycloakAdmin`
- Example Kramerius admin user, when created: `krameriusAdmin/krameriusAdmin`

Do not reuse these values outside this test stack.
