# Kramerius test stack for GigaTIFF

This repository contains the local test deployment files for running Kramerius 7.2.1 against a GigaTIFF IIIF image server on localhost.

It intentionally contains configuration and installation scaffolding only. Runtime databases, Solr indexes, logs, imported NDK packages, image payloads and generated caches are not tracked.

## What is included

- `docker-compose.yml` for the local Kramerius stack
- Kramerius Tomcat configuration: `server.xml`, `rewrite.config`, `logging.properties`
- `.kramerius4` configuration under `mnt/import/.kramerius4`
- Solr 10 core configuration under `mnt/containers/solr/data`
- local web client runtime configuration under `public/local-config`
- a local wrapper for `trinera/cdk-client:3.0.14-beta`

## Main services

- Kramerius API: `http://127.0.0.1:8088`
- web client: `http://127.0.0.1:1234`
- admin client, optional profile: `http://127.0.0.1:1235`
- process manager: `http://127.0.0.1:8082`
- Solr: `http://127.0.0.1:8983`
- Keycloak: `http://keycloak.localhost:8990`

The stack uses PostgreSQL 18.4 for Kramerius and the process manager, Solr 10.0.0, Kramerius 7.2.1, and process-manager 1.5.

## Requirements

- Docker with Docker Compose
- GigaTIFF image server running separately on `http://127.0.0.1:18082`
- optional admin client checkout at `../kramerius-admin-client` when using the `admin` profile

The migration configuration expects the IIIF server at:

```text
http://127.0.0.1:18082/iiif/3
```

## Start

Start the core Kramerius test stack:

```powershell
docker compose up -d --build
```

Start with the admin client as well:

```powershell
docker compose --profile admin up -d --build
```

Show service status:

```powershell
docker compose ps
```

Stop the stack:

```powershell
docker compose down
```

## Import workspace

Put NDK import packages into:

```text
mnt/import/.kramerius4/import
```

The repository keeps only `.gitkeep` placeholders for import and conversion directories. Imported packages, converted JP2 files and Akubra/Fedora object store data are deliberately ignored.

## Web client notes

The web client service builds a small local wrapper over `trinera/cdk-client:3.0.14-beta`.

The wrapper:

- serves `public/local-config` as runtime configuration
- proxies `/search/` to the local Kramerius container
- forces the beta client runtime to use `gigatiff` instead of falling back to MZK
- clears stale `CDK_DEV_*` and `cdk-cache:*` browser localStorage entries before Angular boots
- disables browser caching for local JS/config responses

The active client config is:

```text
public/local-config/gigatiff/config-main.json
```

## Solr notes

The tracked Solr tree contains core configuration only. Index directories such as `data/index`, transaction logs, snapshots and ZooKeeper runtime state are ignored.

The included schemas are aligned with this local Kramerius 7.2.1 / Solr 10 test setup, including the fields needed by the current import/indexing flow.

## Local credentials

The compose file contains local-only development credentials for disposable containers, for example:

- `fedoraAdmin/fedoraAdmin`
- `process/process`
- `keycloakAdmin/keycloakAdmin`

Do not reuse these values outside this local test stack.

