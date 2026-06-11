#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT_DIR/.env"
  set +a
fi

ADMIN_CLIENT_DIR="${ADMIN_CLIENT_DIR:-${ROOT_DIR}/../kramerius-admin-client}"
TAG_SUFFIX="${TAG_SUFFIX:-clean}"
PUSH_TO_DOCKER="${PUSH_TO_DOCKER:-1}"

WEB_IMAGE="localhost/gigatiff-kramerius-web-client:${TAG_SUFFIX}"
AUTH_SHIM_IMAGE="localhost/gigatiff-kramerius-auth-shim:${TAG_SUFFIX}"
ADMIN_IMAGE="localhost/gigatiff-kramerius-admin-client:${TAG_SUFFIX}"
BOOTSTRAP_IMAGE="localhost/gigatiff-kramerius-bootstrap:${TAG_SUFFIX}"

if ! command -v buildah >/dev/null 2>&1; then
  echo "buildah is required" >&2
  exit 1
fi

if [ ! -d "$ADMIN_CLIENT_DIR" ]; then
  echo "admin client checkout not found: $ADMIN_CLIENT_DIR" >&2
  echo "Set ADMIN_CLIENT_DIR or clone https://github.com/ceskaexpedice/kramerius-admin-client.git next to the runtime directory." >&2
  exit 1
fi

echo "Building $WEB_IMAGE"
buildah bud \
  -t "$WEB_IMAGE" \
  -f "$ROOT_DIR/Dockerfile.web-client-gigatiff" \
  "$ROOT_DIR"

echo "Building $AUTH_SHIM_IMAGE"
buildah bud \
  -t "$AUTH_SHIM_IMAGE" \
  -f "$ROOT_DIR/Dockerfile.auth-shim" \
  "$ROOT_DIR"

echo "Building $ADMIN_IMAGE"
buildah bud \
  -t "$ADMIN_IMAGE" \
  -f "$ROOT_DIR/ops/admin-client/Dockerfile.gigatiff" \
  --build-arg "KRAMERIUS_PUBLIC_HOST=${KRAMERIUS_PUBLIC_HOST:-127.0.0.1}" \
  --build-arg "WEB_CLIENT_PORT=${WEB_CLIENT_PORT:-1234}" \
  --build-arg "ADMIN_CLIENT_PORT=${ADMIN_CLIENT_PORT:-1235}" \
  --build-arg "KRAMERIUS_API_PORT=${KRAMERIUS_API_PORT:-8088}" \
  "$ADMIN_CLIENT_DIR"

echo "Building $BOOTSTRAP_IMAGE"
buildah bud \
  -t "$BOOTSTRAP_IMAGE" \
  -f "$ROOT_DIR/Containerfile.clean-bootstrap" \
  "$ROOT_DIR"

if [ "$PUSH_TO_DOCKER" = "1" ]; then
  echo "Publishing images to the local Docker daemon"
  buildah push "$WEB_IMAGE" "docker-daemon:$WEB_IMAGE"
  buildah push "$AUTH_SHIM_IMAGE" "docker-daemon:$AUTH_SHIM_IMAGE"
  buildah push "$ADMIN_IMAGE" "docker-daemon:$ADMIN_IMAGE"
  buildah push "$BOOTSTRAP_IMAGE" "docker-daemon:$BOOTSTRAP_IMAGE"
fi

echo "Clean images are ready:"
echo "  $WEB_IMAGE"
echo "  $AUTH_SHIM_IMAGE"
echo "  $ADMIN_IMAGE"
echo "  $BOOTSTRAP_IMAGE"
