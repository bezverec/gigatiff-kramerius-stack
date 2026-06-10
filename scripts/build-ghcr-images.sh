#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT_DIR/.env"
  set +a
fi

read_version() {
  python3 - "$ROOT_DIR/versions.toml" "$1" "$2" <<'PY'
import pathlib
import sys
import tomllib

data = tomllib.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(data[sys.argv[2]][sys.argv[3]])
PY
}

ADMIN_CLIENT_DIR="${ADMIN_CLIENT_DIR:-${ROOT_DIR}/../kramerius-admin-client}"
GIGATIFF_SOURCE_DIR="${GIGATIFF_SOURCE_DIR:-${ROOT_DIR}/../gigatiff}"
STACK_VERSION="${STACK_VERSION:-$(read_version stack version)}"
GIGATIFF_SERVER_VERSION="${GIGATIFF_SERVER_VERSION:-$(read_version core gigatiff_server_version)}"
GHCR_NAMESPACE="${GHCR_NAMESPACE:-$(read_version ghcr namespace)}"
PUSH_TO_DOCKER="${PUSH_TO_DOCKER:-1}"
PUSH_TO_GHCR="${PUSH_TO_GHCR:-0}"

WEB_IMAGE="${GHCR_NAMESPACE}/$(read_version ghcr web_client_image):${STACK_VERSION}"
ADMIN_IMAGE="${GHCR_NAMESPACE}/$(read_version ghcr admin_client_image):${STACK_VERSION}"
BOOTSTRAP_IMAGE="${GHCR_NAMESPACE}/$(read_version ghcr bootstrap_image):${STACK_VERSION}"
GIGATIFF_IMAGE="${GHCR_NAMESPACE}/$(read_version ghcr gigatiff_server_image):${GIGATIFF_SERVER_VERSION}"

if ! command -v buildah >/dev/null 2>&1; then
  echo "buildah is required" >&2
  exit 1
fi

if [ ! -d "$ADMIN_CLIENT_DIR" ]; then
  echo "admin client checkout not found: $ADMIN_CLIENT_DIR" >&2
  echo "Set ADMIN_CLIENT_DIR or clone https://github.com/ceskaexpedice/kramerius-admin-client.git next to the runtime directory." >&2
  exit 1
fi

if [ ! -d "$GIGATIFF_SOURCE_DIR" ]; then
  echo "GigaTIFF checkout not found: $GIGATIFF_SOURCE_DIR" >&2
  echo "Set GIGATIFF_SOURCE_DIR or clone https://github.com/bezverec/gigatiff.git next to the runtime directory." >&2
  exit 1
fi

echo "Building $WEB_IMAGE"
buildah bud \
  -t "$WEB_IMAGE" \
  --label "org.opencontainers.image.source=$(read_version stack repository)" \
  --label "org.opencontainers.image.version=$STACK_VERSION" \
  -f "$ROOT_DIR/Dockerfile.web-client-gigatiff" \
  "$ROOT_DIR"

echo "Building $ADMIN_IMAGE"
buildah bud \
  -t "$ADMIN_IMAGE" \
  --label "org.opencontainers.image.source=$(read_version stack repository)" \
  --label "org.opencontainers.image.version=$STACK_VERSION" \
  -f "$ROOT_DIR/ops/admin-client/Dockerfile.gigatiff" \
  "$ADMIN_CLIENT_DIR"

echo "Building $BOOTSTRAP_IMAGE"
buildah bud \
  -t "$BOOTSTRAP_IMAGE" \
  --label "org.opencontainers.image.source=$(read_version stack repository)" \
  --label "org.opencontainers.image.version=$STACK_VERSION" \
  -f "$ROOT_DIR/Containerfile.clean-bootstrap" \
  "$ROOT_DIR"

echo "Building $GIGATIFF_IMAGE"
buildah bud \
  -t "$GIGATIFF_IMAGE" \
  --build-arg "GIGATIFF_BUILD_GROK=${GIGATIFF_BUILD_GROK:-1}" \
  --build-arg "GIGATIFF_BUILD_JOBS=${GIGATIFF_BUILD_JOBS:-2}" \
  --build-arg "GIGATIFF_SERVER_FEATURES=${GIGATIFF_SERVER_FEATURES:-jpeg2000-grok-ffi}" \
  --label "org.opencontainers.image.source=$(read_version core gigatiff_repository)" \
  --label "org.opencontainers.image.version=$GIGATIFF_SERVER_VERSION" \
  -f "$GIGATIFF_SOURCE_DIR/Dockerfile" \
  "$GIGATIFF_SOURCE_DIR"

if [ "$PUSH_TO_DOCKER" = "1" ]; then
  echo "Publishing images to the local Docker daemon"
  buildah push "$WEB_IMAGE" "docker-daemon:$WEB_IMAGE"
  buildah push "$ADMIN_IMAGE" "docker-daemon:$ADMIN_IMAGE"
  buildah push "$BOOTSTRAP_IMAGE" "docker-daemon:$BOOTSTRAP_IMAGE"
  buildah push "$GIGATIFF_IMAGE" "docker-daemon:$GIGATIFF_IMAGE"
fi

if [ "$PUSH_TO_GHCR" = "1" ]; then
  echo "Publishing images to GHCR"
  buildah push "$WEB_IMAGE"
  buildah push "$ADMIN_IMAGE"
  buildah push "$BOOTSTRAP_IMAGE"
  buildah push "$GIGATIFF_IMAGE"
fi

echo "GHCR images are ready:"
echo "  $WEB_IMAGE"
echo "  $ADMIN_IMAGE"
echo "  $BOOTSTRAP_IMAGE"
echo "  $GIGATIFF_IMAGE"
