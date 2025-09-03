#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Stop Valhalla container(s)
exec docker compose down
