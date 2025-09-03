#!/usr/bin/env bash
# Build Valhalla tiles for a region using Docker image
# Usage: ./scripts/build-tiles.sh [region|URL]
# - If argument looks like a URL (http/https), it is used directly
# - If argument is 'northeast', downloads the US Northeast extract from Geofabrik
# - Default region is 'northeast'

set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="${IMAGE:-ghcr.io/valhalla/valhalla:latest}"
DATA_DIR="${DATA_DIR:-$PWD/data}"
PBF_PATH="${PBF_PATH:-$DATA_DIR/extract.osm.pbf}"
TILE_DIR="${TILE_DIR:-$DATA_DIR/tiles}"
CONFIG_PATH="${CONFIG_PATH:-$DATA_DIR/valhalla.json}"
REGION_OR_URL="${1:-northeast}"

mkdir -p "$DATA_DIR" "$TILE_DIR"

resolve_url() {
  local arg="$1"
  if [[ "$arg" =~ ^https?:// ]]; then
    echo "$arg"
    return 0
  fi
  case "$arg" in
    northeast)
      # US Northeast (Geofabrik regional extract)
      echo "https://download.geofabrik.de/north-america/us-northeast-latest.osm.pbf"
      ;;
    new-england)
      # Alternate subregion
      echo "https://download.geofabrik.de/north-america/us/new-england-latest.osm.pbf"
      ;;
    mid-atlantic)
      echo "https://download.geofabrik.de/north-america/us/mid-atlantic-latest.osm.pbf"
      ;;
    *)
      echo "Unsupported region: $arg" >&2
      echo "Provide a full URL or one of: northeast, new-england, mid-atlantic" >&2
      exit 1
      ;;
  esac
}

URL="$(resolve_url "$REGION_OR_URL")"

echo "[1/4] Downloading extract to $PBF_PATH"
if [ -f "$PBF_PATH" ]; then
  echo "  - Already exists; skipping (delete to re-download)"
else
  curl -fL --progress-bar "$URL" -o "$PBF_PATH"
fi

echo "[2/4] Generating valhalla.json at $CONFIG_PATH"
if [ -f "$CONFIG_PATH" ]; then
  echo "  - Already exists; skipping (delete to regenerate)"
else
  docker run --rm -v "$DATA_DIR:/data" "$IMAGE" \
    sh -c "valhalla_build_config --mjolnir-tile-dir /data/tiles --additional-data /data > /data/valhalla.json"
fi

echo "[3/4] Building tiles into $TILE_DIR"
docker run --rm -v "$DATA_DIR:/data" "$IMAGE" \
  valhalla_build_tiles -c /data/valhalla.json /data/$(basename "$PBF_PATH")

# Optionally build admins and timezones (uncomment if needed)
# docker run --rm -v "$DATA_DIR:/data" "$IMAGE" valhalla_build_admins -c /data/valhalla.json
# docker run --rm -v "$DATA_DIR:/data" "$IMAGE" valhalla_build_timezones -c /data/valhalla.json

echo "[4/4] Done. Tiles at $TILE_DIR and config at $CONFIG_PATH"
echo "Start the service with: ./scripts/run.sh"
