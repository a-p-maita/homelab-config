#!/bin/bash
# Script to bring up all homelab stacks with correct env and data directories
set -e

cd "$(dirname "$0")/.."

# ── Read DATA_ROOT from .env ──────────────────────────────────────────────────
DATA_ROOT=$(grep -E '^DATA_ROOT=' .env 2>/dev/null | head -1 | cut -d= -f2- | sed "s/^['\"]//; s/['\"]$//")
if [ -z "$DATA_ROOT" ]; then
  echo "ERROR: DATA_ROOT not set in .env"
  exit 1
fi
PUID=$(grep -E '^PUID=' .env 2>/dev/null | head -1 | cut -d= -f2-)
PGID=$(grep -E '^PGID=' .env 2>/dev/null | head -1 | cut -d= -f2-)
USE_VPN=$(grep -E '^USE_VPN=' .env 2>/dev/null | head -1 | cut -d= -f2-)

echo "DATA_ROOT: $DATA_ROOT"
echo "USE_VPN:   ${USE_VPN:-false}"

# ── Migrate legacy data dirs to new media/ layout (idempotent) ────────────────
if [ -d "./data/audiobooks" ] && [ ! -d "${DATA_ROOT}/media/audiobooks" ]; then
  echo "Migrating data/audiobooks → ${DATA_ROOT}/media/audiobooks ..."
  mkdir -p "${DATA_ROOT}/media"
  mv "./data/audiobooks" "${DATA_ROOT}/media/audiobooks"
fi
if [ -d "./data/music" ] && [ ! -d "${DATA_ROOT}/media/music" ]; then
  echo "Migrating data/music → ${DATA_ROOT}/media/music ..."
  mkdir -p "${DATA_ROOT}/media"
  mv "./data/music" "${DATA_ROOT}/media/music"
fi
if [ -d "./data/podcasts" ] && [ ! -d "${DATA_ROOT}/media/podcasts" ]; then
  echo "Migrating data/podcasts → ${DATA_ROOT}/media/podcasts ..."
  mkdir -p "${DATA_ROOT}/media"
  mv "./data/podcasts" "${DATA_ROOT}/media/podcasts"
fi
# Remove empty legacy download dir (was never used for actual data)
if [ -d "./data/qbittorrent-downloads" ]; then
  rmdir --ignore-fail-on-non-empty "./data/qbittorrent-downloads"
fi

# ── Ensure all required data directories exist ────────────────────────────────
mkdir -p \
  "${DATA_ROOT}/media/audiobooks" \
  "${DATA_ROOT}/media/podcasts" \
  "${DATA_ROOT}/media/music" \
  "${DATA_ROOT}/media/movies" \
  "${DATA_ROOT}/media/tv" \
  "${DATA_ROOT}/media/books" \
  "${DATA_ROOT}/torrents/movies" \
  "${DATA_ROOT}/torrents/tv" \
  "${DATA_ROOT}/torrents/music" \
  "${DATA_ROOT}/torrents/books" \
  "${DATA_ROOT}/torrents/incomplete" \
  ./data/audiobookshelf/config \
  ./data/audiobookshelf/metadata \
  ./data/qbittorrent/config \
  ./data/jackett/config \
  ./data/jackett/downloads \
  ./data/audiobookbay-downloader \
  ./data/prowlarr/config \
  ./data/radarr/config \
  ./data/sonarr/config \
  ./data/readarr/config \
  ./data/lidarr/config \
  ./data/gluetun \
  ./data/forgejo \
  ./data/immich_db \
  ./data/immich_upload \
  ./data/yamtrack \
  ./data/yamtrack/redis \
  ./data/crosswatch \
  ./data/homepage/config \
  ./data/uptime-kuma \
  ./data/navidrome/data \
  ./data/paperless/redis \
  ./data/paperless/db \
  ./data/paperless/data \
  ./data/paperless/media \
  ./data/paperless/consume \
  ./data/paperless/export \
  ./data/stirling-pdf/configs \
  ./data/stirling-pdf/logs \
  ./data/kiwix \
  ./data/vaultwarden \
  ./data/actual-budget \
  ./data/joplin/db \
  ./data/mealie \
  ./data/jellyfin/config \
  ./data/jellyfin/cache \
  ./data/seerr/config \
  ./data/home-assistant

# ── Fix ABS podcast write permissions ────────────────────────────────────────
# ABS needs to write episode files as the host user (PUID:PGID)
if [ -n "$PUID" ] && [ -n "$PGID" ]; then
  chown -R "${PUID}:${PGID}" "${DATA_ROOT}/media/podcasts" "${DATA_ROOT}/media/audiobooks" 2>/dev/null || true
fi

# ── Patch existing qBittorrent config (critical: sed runs even if file exists) ─
QBT_CONF="./data/qbittorrent/config/qBittorrent/qBittorrent.conf"
if [ -f "$QBT_CONF" ]; then
  echo "Patching existing qBittorrent.conf paths ..."
  sed -i \
    's|/downloads/incomplete/|/data/torrents/incomplete/|g; s|/downloads/|/data/torrents/|g' \
    "$QBT_CONF"
fi

# ── Force-update qBittorrent categories (always sync from template) ───────────
QBT_CAT_DIR="./data/qbittorrent/config/qBittorrent"
mkdir -p "$QBT_CAT_DIR"
cp config-templates/qbittorrent/categories.json "${QBT_CAT_DIR}/categories.json"
echo "Updated qBittorrent categories.json from template."

# ── Seed configs from templates if not yet present ───────────────────────────
if [ ! -f "$QBT_CONF" ]; then
  mkdir -p "$(dirname "$QBT_CONF")"
  cp config-templates/qbittorrent/qBittorrent.conf "$QBT_CONF"
  echo "Seeded qBittorrent.conf from config-templates."
fi
if [ ! -f ./data/homepage/config/services.yaml ]; then
  cp config-templates/homepage/services.yaml ./data/homepage/config/services.yaml
  echo "Seeded Homepage services.yaml from config-templates."
fi
if [ ! -f ./data/homepage/config/settings.yaml ]; then
  cp config-templates/homepage/settings.yaml ./data/homepage/config/settings.yaml
  echo "Seeded Homepage settings.yaml from config-templates."
fi
if [ ! -f ./data/homepage/config/docker.yaml ]; then
  cp config-templates/homepage/docker.yaml ./data/homepage/config/docker.yaml
  echo "Seeded Homepage docker.yaml from config-templates."
fi
if [ ! -f ./data/homepage/config/widgets.yaml ]; then
  cp config-templates/homepage/widgets.yaml ./data/homepage/config/widgets.yaml
  echo "Seeded Homepage widgets.yaml from config-templates."
fi
if [ ! -f ./data/homepage/config/bookmarks.yaml ]; then
  cp config-templates/homepage/bookmarks.yaml ./data/homepage/config/bookmarks.yaml
  echo "Seeded Homepage bookmarks.yaml from config-templates."
fi
if [ ! -f ./data/stirling-pdf/configs/settings.yml ]; then
  cp config-templates/stirling-pdf/settings.yml ./data/stirling-pdf/configs/settings.yml
  echo "Seeded Stirling PDF settings.yml from config-templates."
fi
if [ ! -f ./data/crosswatch/config.json ]; then
  cp config-templates/crosswatch/config.json ./data/crosswatch/config.json
  echo "Seeded CrossWatch config.json from config-templates."
fi

# ── Ensure the shared external network exists ─────────────────────────────────
docker network create homelab_net 2>/dev/null || true

# ── Always use --env-file .env for all stacks ─────────────────────────────────
if [ -f .env ]; then
  ENV_FILE_ARG="--env-file .env"
else
  ENV_FILE_ARG=""
fi

# ── Arr stack: compose files depend on USE_VPN flag ──────────────────────────
if [ "${USE_VPN}" = "true" ]; then
  ARR_COMPOSE="-f dockerfiles/arr/compose.yaml -f dockerfiles/arr/compose.vpn.yaml"
  echo "VPN mode enabled — arr stack will use gluetun."
else
  ARR_COMPOSE="-f dockerfiles/arr/compose.yaml"
  echo "VPN mode disabled — arr stack running without VPN."
fi

echo "Bringing up core..."
docker compose $ENV_FILE_ARG -f dockerfiles/core/compose.yaml up -d

echo "Bringing up arr..."
docker compose $ENV_FILE_ARG $ARR_COMPOSE up -d

echo "Bringing up media..."
docker compose $ENV_FILE_ARG -f dockerfiles/media/compose.yaml up -d

echo "Bringing up productivity..."
docker compose $ENV_FILE_ARG -f dockerfiles/productivity/compose.yaml up -d

echo "Bringing up immich..."
docker compose $ENV_FILE_ARG -f dockerfiles/immich/compose.yaml -f dockerfiles/immich/compose.override.yaml up -d

echo "Bringing up monitoring..."
docker compose $ENV_FILE_ARG -f dockerfiles/monitoring/compose.yaml up -d

echo "Bringing up documents..."
docker compose $ENV_FILE_ARG -f dockerfiles/documents/compose.yaml up -d

echo "Bringing up tools..."
docker compose $ENV_FILE_ARG -f dockerfiles/tools/compose.yaml up -d

echo "Bringing up personal..."
docker compose $ENV_FILE_ARG -f dockerfiles/personal/compose.yaml up -d

echo "Bringing up entertainment..."
docker compose $ENV_FILE_ARG -f dockerfiles/entertainment/compose.yaml up -d

echo "Bringing up home..."
docker compose $ENV_FILE_ARG -f dockerfiles/home/compose.yaml up -d

echo "All stacks are up"
