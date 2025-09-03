#!/usr/bin/env sh
set -eu

DATA_DIR="${DATA_DIR:-/data}"
PBF_URL="${PBF_URL:-https://download.geofabrik.de/north-america/us-northeast-latest.osm.pbf}"
WORKERS="${WORKERS:-1}"
PORT="${PORT:-8002}"

mkdir -p "$DATA_DIR/valhalla_tiles" "$DATA_DIR/valhalla"

# config (points to admins/timezones + packed tiles)
valhalla_build_config \
  --mjolnir-tile-dir "$DATA_DIR/valhalla_tiles" \
  --mjolnir-tile-extract "$DATA_DIR/valhalla_tiles.tar" \
  --mjolnir-timezone "$DATA_DIR/valhalla/timezones.sqlite" \
  --mjolnir-admin "$DATA_DIR/valhalla/admin.sqlite" \
  > "$DATA_DIR/valhalla.json"

# fetch pbf (force ipv4 + retries; fallback to http/https toggle if needed)
curl -4L --fail --connect-timeout 20 --retry 3 --retry-delay 3 \
  -H "User-Agent: valhalla-railway" \
  "$PBF_URL" -o "$DATA_DIR/region.osm.pbf" \
|| curl -4L --fail --connect-timeout 20 --retry 3 --retry-delay 3 \
  -H "User-Agent: valhalla-railway" \
  "${PBF_URL/http:/https:}" -o "$DATA_DIR/region.osm.pbf" \
|| curl -4L --fail --connect-timeout 20 --retry 3 --retry-delay 3 \
  -H "User-Agent: valhalla-railway" \
  "${PBF_URL/https:/http:}" -o "$DATA_DIR/region.osm.pbf"

# build admins/timezones first (reduces warnings)
valhalla_build_timezones > "$DATA_DIR/valhalla/timezones.sqlite"
valhalla_build_admins --config "$DATA_DIR/valhalla.json" "$DATA_DIR/region.osm.pbf"

# build + pack tiles (first deploy only; persists on volume)
if [ ! -s "$DATA_DIR/valhalla_tiles.tar" ]; then
  valhalla_build_tiles -c "$DATA_DIR/valhalla.json" "$DATA_DIR/region.osm.pbf"
  valhalla_build_extract -c "$DATA_DIR/valhalla.json" -v
fi

exec valhalla_service "$DATA_DIR/valhalla.json" "$WORKERS" 0.0.0.0 "$PORT"
