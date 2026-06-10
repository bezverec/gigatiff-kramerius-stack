#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-}"

if [ -z "$DEST" ]; then
  echo "Usage: $0 /path/to/clean/kramerius-test" >&2
  exit 1
fi

if [ -e "$DEST" ] && [ "$(find "$DEST" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)" != "0" ]; then
  echo "Destination exists and is not empty: $DEST" >&2
  exit 1
fi

mkdir -p "$DEST"

if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$ROOT_DIR" ls-files -z --cached --others --exclude-standard \
    | tar -C "$ROOT_DIR" --null -T - -cf - \
    | tar -xf - -C "$DEST"
else
  echo "This script expects a git checkout so it can copy only Git-managed files." >&2
  exit 1
fi

mkdir -p \
  "$DEST/logs/kramerius" \
  "$DEST/logs/solr" \
  "$DEST/logs/processmanager" \
  "$DEST/logs/curatorworker" \
  "$DEST/logs/publicworker" \
  "$DEST/temp" \
  "$DEST/cache/gigatiff" \
  "$DEST/mnt/imageserver/iip-data" \
  "$DEST/mnt/imageserver/audioserver" \
  "$DEST/mnt/import/.kramerius4/import" \
  "$DEST/mnt/import/.kramerius4/convert"

chmod -R a+rwX \
  "$DEST/logs" \
  "$DEST/temp" \
  "$DEST/cache" \
  "$DEST/mnt/containers/solr/data" \
  "$DEST/mnt/imageserver" \
  "$DEST/mnt/import/.kramerius4/import" \
  "$DEST/mnt/import/.kramerius4/convert"

if [ ! -f "$DEST/.env" ] && [ -f "$DEST/.env.example" ]; then
  cp "$DEST/.env.example" "$DEST/.env"
fi

find "$DEST/mnt/imageserver" -type f -print -quit | grep -q . && {
  echo "Refusing clean bundle: image server payload files were copied." >&2
  exit 1
}

find "$DEST/mnt/import/.kramerius4/import" -type f ! -name '.gitkeep' -print -quit | grep -q . && {
  echo "Refusing clean bundle: import payload files were copied." >&2
  exit 1
}

find "$DEST/mnt/import/.kramerius4/convert" -type f ! -name '.gitkeep' -print -quit | grep -q . && {
  echo "Refusing clean bundle: convert payload files were copied." >&2
  exit 1
}

echo "Clean stack prepared at $DEST"
echo "Next:"
echo "  cd $DEST"
echo "  ./scripts/configure-endpoints.sh 10.0.120.30 0.0.0.0"
echo "  ./scripts/build-clean-images.sh"
echo "  docker compose -f docker-compose.yml -f docker-compose.clean.yml up -d"
echo "  docker compose -f docker-compose.yml -f docker-compose.clean.yml run --rm clean-bootstrap"
