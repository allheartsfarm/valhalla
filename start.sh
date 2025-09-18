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

# Ensure the service listens on the desired PORT by updating config
if [ -n "${PORT:-}" ]; then
  if command -v jq >/dev/null 2>&1; then
    tmpcfg="$(mktemp)"
    jq --arg p "$PORT" '.httpd.service.listen = "tcp://0.0.0.0:\($p)"' "$DATA_DIR/valhalla.json" > "$tmpcfg" && mv "$tmpcfg" "$DATA_DIR/valhalla.json" || true
  else
    # Fallback: replace any 0.0.0.0:<port> in listen entry
    sed -i.bak -E "s#(\"listen\"\s*:\s*\"tcp://0.0.0.0:)\d+#\1$PORT#" "$DATA_DIR/valhalla.json" || true
  fi
fi

# Optional: increase auto.max_locations without full config overlay
# Set AUTO_MAX_LOCATIONS=100 (or desired value) in the environment (e.g., Railway UI)
if [ -n "${AUTO_MAX_LOCATIONS:-}" ]; then
  # Sanitize to a number in case the UI included quotes
  AUTO_MAX_LOCATIONS_NUM=$(printf "%s" "$AUTO_MAX_LOCATIONS" | tr -cd '0-9')
  if [ -z "$AUTO_MAX_LOCATIONS_NUM" ]; then
    echo "Warning: AUTO_MAX_LOCATIONS is not numeric ('$AUTO_MAX_LOCATIONS'). Skipping." >&2
  else
    echo "Setting service_limits.auto.max_locations=$AUTO_MAX_LOCATIONS_NUM"
    if command -v jq >/dev/null 2>&1; then
      tmpcfg="$(mktemp)"
      jq --arg n "$AUTO_MAX_LOCATIONS_NUM" \
        '.service_limits.auto.max_locations = ($n|tonumber)
         | .service_limits.optimized_route = (.service_limits.optimized_route // {})
         | .service_limits.optimized_route.max_locations = ($n|tonumber)'
        "$DATA_DIR/valhalla.json" > "$tmpcfg" \
        && mv "$tmpcfg" "$DATA_DIR/valhalla.json" || true
    else
      # awk fallback: specifically target service_limits.auto and optimized_route blocks
      tmpcfg="$(mktemp)"
      awk -v newval="$AUTO_MAX_LOCATIONS_NUM" '
        BEGIN{in_service=0;in_auto=0;in_opt=0;brace=0}
        {
          line=$0
          # Track entry into service_limits object
          if(in_service==0 && line ~ /\"service_limits\"[[:space:]]*:[[:space:]]*{/){ in_service=1; brace=1 }
          else if(in_service==1){
            # Update brace depth within service_limits
            if(index(line, "{")>0) brace+=gsub(/\{/,"{")
            if(index(line, "}")>0) brace-=gsub(/\}/,"}")
            if(line ~ /\"auto\"[[:space:]]*:[[:space:]]*{/){ in_auto=1 }
            if(line ~ /\"optimized_route\"[[:space:]]*:[[:space:]]*{/){ in_opt=1 }
            if(in_auto==1 && line ~ /\"max_locations\"[[:space:]]*:[[:space:]]*[0-9]+/){
              sub(/\"max_locations\"[[:space:]]*:[[:space:]]*[0-9]+/, "\"max_locations\": " newval, line)
            }
            if(in_opt==1 && line ~ /\"max_locations\"[[:space:]]*:[[:space:]]*[0-9]+/){
              sub(/\"max_locations\"[[:space:]]*:[[:space:]]*[0-9]+/, "\"max_locations\": " newval, line)
            }
            # exit sub-objects crudely when encountering a closing brace on its own level
            if(in_auto==1 && line ~ /}/){ in_auto=0 }
            if(in_opt==1 && line ~ /}/){ in_opt=0 }
            if(brace<=0){ in_service=0 }
          }
          print line
        }
      ' "$DATA_DIR/valhalla.json" > "$tmpcfg" && mv "$tmpcfg" "$DATA_DIR/valhalla.json" || true
    fi
  fi
fi

# Start service: only pass CONFIG and optional CONCURRENCY
exec valhalla_service "$DATA_DIR/valhalla.json" "$WORKERS"
