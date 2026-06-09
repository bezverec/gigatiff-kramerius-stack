#!/usr/bin/env bash
set -euo pipefail

public_host="${1:-127.0.0.1}"
bind_addr="${2:-127.0.0.1}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

web_port="${WEB_CLIENT_PORT:-1234}"
admin_port="${ADMIN_CLIENT_PORT:-1235}"
api_port="${KRAMERIUS_API_PORT:-8088}"
keycloak_host="${KEYCLOAK_PUBLIC_HOST:-keycloak.localhost}"
keycloak_port="${KEYCLOAK_PORT:-8990}"
gigatiff_port="${GIGATIFF_PORT:-18082}"
gigatiff_internal_base="${GIGATIFF_INTERNAL_BASE_URL:-http://host.docker.internal:${gigatiff_port}/iiif/3}"

cat > "$root/.env" <<EOF
KRAMERIUS_BIND_ADDR=$bind_addr
KRAMERIUS_PUBLIC_HOST=$public_host
WEB_CLIENT_PORT=$web_port
ADMIN_CLIENT_PORT=$admin_port
KRAMERIUS_API_PORT=$api_port
KEYCLOAK_PUBLIC_HOST=$keycloak_host
KEYCLOAK_PORT=$keycloak_port
SOLR_PORT=8983
PROCESS_MANAGER_PORT=8082
CURATOR_WORKER_PORT=8084
PUBLIC_WORKER_PORT=8086
KRAMERIUS_DB_PORT=15432
PROCESS_DB_PORT=25432
GIGATIFF_PORT=$gigatiff_port
GIGATIFF_INTERNAL_BASE_URL=$gigatiff_internal_base
GIGATIFF_SOURCE_DIR=../gigatiff
GIGATIFF_CACHE_NAMESPACE=gigatiff-server-response-v12-jp2-auto-fix
DOCKHAND_PORT=3000
DASHY_PORT=18080
EOF

python3 - "$root" "$public_host" "$web_port" "$admin_port" "$api_port" "$keycloak_host" "$keycloak_port" "$gigatiff_port" "$gigatiff_internal_base" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
host, web_port, admin_port, api_port, keycloak_host, keycloak_port, gigatiff_port, gigatiff_internal_base = sys.argv[2:]

def set_prop(path, key, value):
    lines = path.read_text(encoding="utf-8").splitlines()
    prefix = f"{key}="
    out = []
    found = False
    for line in lines:
        if line.startswith(prefix):
            out.append(prefix + value)
            found = True
        else:
            out.append(line)
    if not found:
        out.append(prefix + value)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")

migration = root / "mnt/import/.kramerius4/migration.properties"
giga_base = f"http://{host}:{gigatiff_port}/iiif/3"
set_prop(migration, "convert.imageServerTilesURLPrefix", gigatiff_internal_base)
set_prop(migration, "convert.imageServerImagesURLPrefix", gigatiff_internal_base)
set_prop(migration, "convert.imageServerSuffix.removeFilenameExtensions", "false")
set_prop(migration, "convert.imageServerSuffix.tiles", "")

rewrite = root / "rewrite.config"
rewrite.write_text(
    __import__("re").sub(r"http://[^/\s]+:18082/iiif/3", giga_base, rewrite.read_text(encoding="utf-8")),
    encoding="utf-8",
)

configuration = root / "mnt/import/.kramerius4/configuration.properties"
set_prop(configuration, "client", f"http://{host}:{web_port}/")

keycloak = root / "mnt/import/.kramerius4/keycloak.json"
keycloak_json = json.loads(keycloak.read_text(encoding="utf-8"))
keycloak_json["auth-server-url"] = f"http://{keycloak_host}:{keycloak_port}/"
keycloak.write_text(json.dumps(keycloak_json, indent=2) + "\n", encoding="utf-8")

config_path = root / "public/local-config/gigatiff/config-main.json"
config = json.loads(config_path.read_text(encoding="utf-8"))
config["app"]["name"] = {"cs": "GigaTIFF", "en": "GigaTIFF"}
config["app"]["logo"] = "/favicon.svg"
config["app"]["adminClientUrl"] = f"http://{host}:{admin_port}"
config["api"]["baseUrl"] = f"http://{host}:{api_port}"
config_path.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

libraries_path = root / "public/local-config/libraries.json"
libraries = json.loads(libraries_path.read_text(encoding="utf-8"))
for library in libraries:
    library["name"] = "GigaTIFF"
    library["name_en"] = "GigaTIFF"
    library["new_client_url"] = f"http://{host}:{web_port}"
    library["url"] = f"http://{host}:{web_port}"
    library["logo"] = "/favicon.svg"
libraries_path.write_text(json.dumps(libraries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY

printf 'Configured Kramerius test stack for http://%s:%s\n' "$public_host" "$web_port"
