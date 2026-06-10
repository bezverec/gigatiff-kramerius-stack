#!/usr/bin/env bash
set -euo pipefail

public_host="${1:-127.0.0.1}"
bind_addr="${2:-127.0.0.1}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stack_dir_name="$(basename "$root")"

web_port="${WEB_CLIENT_PORT:-1234}"
admin_port="${ADMIN_CLIENT_PORT:-1235}"
api_port="${KRAMERIUS_API_PORT:-8088}"
debug_port="${KRAMERIUS_DEBUG_PORT:-5005}"
ajp_port="${KRAMERIUS_AJP_PORT:-8009}"
if [ -n "${KEYCLOAK_PUBLIC_HOST:-}" ]; then
    keycloak_host="$KEYCLOAK_PUBLIC_HOST"
elif [ "$public_host" = "127.0.0.1" ] || [ "$public_host" = "localhost" ]; then
    keycloak_host="keycloak.localhost"
else
    keycloak_host="$public_host"
fi
keycloak_port="${KEYCLOAK_PORT:-8990}"
solr_port="${SOLR_PORT:-8983}"
lock_port_1="${LOCK_SERVER_PORT_1:-5701}"
lock_port_2="${LOCK_SERVER_PORT_2:-5702}"
lock_port_3="${LOCK_SERVER_PORT_3:-5703}"
process_manager_port="${PROCESS_MANAGER_PORT:-8082}"
curator_worker_port="${CURATOR_WORKER_PORT:-8084}"
public_worker_port="${PUBLIC_WORKER_PORT:-8086}"
kramerius_db_port="${KRAMERIUS_DB_PORT:-15432}"
process_db_port="${PROCESS_DB_PORT:-25432}"
gigatiff_port="${GIGATIFF_PORT:-18082}"
dockhand_port="${DOCKHAND_PORT:-3000}"
dashy_port="${DASHY_PORT:-18080}"
gigatiff_internal_base="${GIGATIFF_INTERNAL_BASE_URL:-http://host.docker.internal:${gigatiff_port}/iiif/3}"

cat > "$root/.env" <<EOF
KRAMERIUS_BIND_ADDR=$bind_addr
KRAMERIUS_PUBLIC_HOST=$public_host
WEB_CLIENT_PORT=$web_port
ADMIN_CLIENT_PORT=$admin_port
KRAMERIUS_API_PORT=$api_port
KRAMERIUS_DEBUG_PORT=$debug_port
KRAMERIUS_AJP_PORT=$ajp_port
KEYCLOAK_PUBLIC_HOST=$keycloak_host
KEYCLOAK_PORT=$keycloak_port
SOLR_PORT=$solr_port
LOCK_SERVER_PORT_1=$lock_port_1
LOCK_SERVER_PORT_2=$lock_port_2
LOCK_SERVER_PORT_3=$lock_port_3
PROCESS_MANAGER_PORT=$process_manager_port
CURATOR_WORKER_PORT=$curator_worker_port
PUBLIC_WORKER_PORT=$public_worker_port
KRAMERIUS_DB_PORT=$kramerius_db_port
PROCESS_DB_PORT=$process_db_port
GIGATIFF_PORT=$gigatiff_port
GHCR_NAMESPACE=ghcr.io/bezverec
STACK_VERSION=stack-0.1.2
GIGATIFF_SERVER_VERSION=0.3.0
GIGATIFF_INTERNAL_BASE_URL=$gigatiff_internal_base
GIGATIFF_SOURCE_DIR=../gigatiff
GIGATIFF_CACHE_NAMESPACE=gigatiff-server-response-v12-jp2-auto-fix
ADMIN_CLIENT_DOCKERFILE=../${stack_dir_name}/ops/admin-client/Dockerfile.gigatiff
DOCKHAND_PORT=$dockhand_port
DASHY_PORT=$dashy_port
EOF

python3 - "$root" "$public_host" "$web_port" "$admin_port" "$api_port" "$keycloak_host" "$keycloak_port" "$gigatiff_port" "$gigatiff_internal_base" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
host, web_port, admin_port, api_port, keycloak_host, keycloak_port, gigatiff_port, gigatiff_internal_base = sys.argv[2:]

def read_text(path):
    return path.read_text(encoding="utf-8-sig")

def set_prop(path, key, value):
    lines = read_text(path).splitlines()
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
    __import__("re").sub(r"http://[^/\s]+:18082/iiif/3", giga_base, read_text(rewrite)),
    encoding="utf-8",
)

configuration = root / "mnt/import/.kramerius4/configuration.properties"
set_prop(configuration, "client", f"http://{host}:{web_port}/")
set_prop(configuration, "keycloak.realm", "kramerius")
set_prop(configuration, "keycloak.clientId", "krameriusClient")
set_prop(configuration, "keycloak.tokenurl", f"http://{keycloak_host}:{keycloak_port}/realms/kramerius/protocol/openid-connect/token")

keycloak = root / "mnt/import/.kramerius4/keycloak.json"
keycloak_json = json.loads(read_text(keycloak))
keycloak_json["auth-server-url"] = f"http://{keycloak_host}:{keycloak_port}/"
keycloak.write_text(json.dumps(keycloak_json, indent=2) + "\n", encoding="utf-8")

config_path = root / "public/local-config/gigatiff/config-main.json"
config = json.loads(read_text(config_path))
config["app"]["name"] = {"cs": "GigaTIFF", "en": "GigaTIFF"}
config["app"]["logo"] = "/favicon.svg"
config["app"]["adminClientUrl"] = f"http://{host}:{admin_port}"
config["api"]["baseUrl"] = f"http://{host}:{api_port}"
config_path.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

libraries_path = root / "public/local-config/libraries.json"
libraries = json.loads(read_text(libraries_path))

if isinstance(libraries, dict):
    library_items = [libraries]
else:
    library_items = libraries

for library in library_items:
    library["name"] = "GigaTIFF"
    library["name_en"] = "GigaTIFF"
    library["new_client_url"] = f"http://{host}:{web_port}"
    library["url"] = f"http://{host}:{web_port}"
    library["logo"] = "/favicon.svg"
libraries_path.write_text(json.dumps(libraries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY

printf 'Configured Kramerius test stack for http://%s:%s\n' "$public_host" "$web_port"
