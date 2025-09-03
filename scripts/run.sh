#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Start Valhalla using docker-compose
exec docker compose up -d
