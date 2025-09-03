# Valhalla Docker
# Valhalla Docker


Minimal repo to run the Valhalla routing service via Docker Compose.
Minimal repo to run the Valhalla routing service via Docker Compose.


## Prerequisites
## Prerequisites
- Docker and Docker Compose installed
- Docker and Docker Compose installed


## Structure
## Structure
- `docker-compose.yml`: Service definition for Valhalla
- `docker-compose.yml`: Service definition for Valhalla
- `scripts/`: Helper scripts to start/stop the service
- `scripts/`: Helper scripts to start/stop the service
- `data/`: Mounted into the container at `/data` (must contain `valhalla.json` and Valhalla tiles)
- `data/`: Mounted into the container at `/data` (must contain `valhalla.json` and Valhalla tiles)


## Quick Start
## Quick Start
1. Prepare Valhalla data under `./data`:
1. Prepare Valhalla data under `./data`:
   - `valhalla.json` config file
   - `valhalla.json` config file
   - Tile data directory (e.g., `tiles/`) referenced by `valhalla.json`
   - Tile data directory (e.g., `tiles/`) referenced by `valhalla.json`
2. Start the service:
2. Start the service:
   ```sh
   ```sh
   ./scripts/run.sh
   ./scripts/run.sh
   ```
   ```
3. Access the API:
3. Access the API:
   - `http://localhost:8002/route?json={"locations":[{"lat":40.7484,"lon":-73.9857},{"lat":40.7306,"lon":-73.9352}],"costing":"auto"}`
   - `http://localhost:8002/route?json={"locations":[{"lat":40.7484,"lon":-73.9857},{"lat":40.7306,"lon":-73.9352}],"costing":"auto"}`
4. Stop the service:
4. Stop the service:
   ```sh
   ```sh
   ./scripts/stop.sh
   ./scripts/stop.sh
   ```
   ```


## Building Tiles (outline)
## Building Tiles (outline)
This repo does not include a full tile-build pipeline. Typical workflow using the Valhalla image:
This repo does not include a full tile-build pipeline. Typical workflow using the Valhalla image:


- Download an OSM extract (e.g., from Geofabrik) to `./data/extract.osm.pbf`.
- Download an OSM extract (e.g., from Geofabrik) to `./data/extract.osm.pbf`.
- Generate a configuration and build tiles inside the container, mounting `./data` to `/data`.
- Generate a configuration and build tiles inside the container, mounting `./data` to `/data`.


Example commands to run manually (adjust to your needs):
Example commands to run manually (adjust to your needs):
```sh
```sh
# Generate a base config (writes /data/valhalla.json)
# Generate a base config (writes /data/valhalla.json)
docker run --rm -v "$PWD/data:/data" ghcr.io/valhalla/valhalla:latest \
docker run --rm -v "$PWD/data:/data" ghcr.io/valhalla/valhalla:latest \
  valhalla_build_config --mjolnir-tile-dir /data/tiles --additional-data /data \
  valhalla_build_config --mjolnir-tile-dir /data/tiles --additional-data /data \
  > data/valhalla.json
  > data/valhalla.json


# Build tiles from your extract
# Build tiles from your extract
docker run --rm -v "$PWD/data:/data" ghcr.io/valhalla/valhalla:latest \
docker run --rm -v "$PWD/data:/data" ghcr.io/valhalla/valhalla:latest \
  valhalla_build_tiles -c /data/valhalla.json /data/extract.osm.pbf
  valhalla_build_tiles -c /data/valhalla.json /data/extract.osm.pbf


# (Optional) Build admin and timezone data if desired
# (Optional) Build admin and timezone data if desired
# docker run --rm -v "$PWD/data:/data" ghcr.io/valhalla/valhalla:latest \
# docker run --rm -v "$PWD/data:/data" ghcr.io/valhalla/valhalla:latest \
#   valhalla_build_admins -c /data/valhalla.json
#   valhalla_build_admins -c /data/valhalla.json
# docker run --rm -v "$PWD/data:/data" ghcr.io/valhalla/valhalla:latest \
# docker run --rm -v "$PWD/data:/data" ghcr.io/valhalla/valhalla:latest \
#   valhalla_build_timezones -c /data/valhalla.json
#   valhalla_build_timezones -c /data/valhalla.json
```
```


Once `data/valhalla.json` and tiles exist, `docker-compose up` will run the service.

## Tile Build Script (northeast default)
Use the helper to download an extract and build tiles locally using the Docker image. Defaults to US Northeast.

- Build for northeast (default):
  ```sh
  ./scripts/build-tiles.sh
  ```
- Build for a named region or a direct URL:
  ```sh
  ./scripts/build-tiles.sh new-england
  ./scripts/build-tiles.sh https://download.geofabrik.de/north-america/us-northeast-latest.osm.pbf
  ```

Tiles and config are written under `./data`. Then start with `./scripts/run.sh`.

## Deploying to Railway (optional)
If you plan to run Valhalla on Railway, use a tiny repo with a `start.sh` and `Dockerfile` so the platform runs your startup logic reliably. Your local compose setup here is enough for local use; Railway-specific files are only needed if deploying there. I can scaffold a minimal Railway repo configured for US Northeast on request.

Once `data/valhalla.json` and tiles exist, `docker-compose up` will run the service.


## Notes
## Notes
- The compose file exposes port `8002` by default (override with `VALHALLA_PORT` in `.env`).
- The compose file exposes port `8002` by default (override with `VALHALLA_PORT` in `.env`).
- `data/` is `.gitignore`’d to avoid committing large files.
- `data/` is `.gitignore`’d to avoid committing large files.


