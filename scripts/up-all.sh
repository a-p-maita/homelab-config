#!/bin/bash
# Script to bring up all homelab stacks with correct env and data directories
set -euo pipefail

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
  ./data/recyclarr/config \
  ./data/home-assistant

# ── Fix ABS podcast write permissions ────────────────────────────────────────
if [ -n "$PUID" ] && [ -n "$PGID" ]; then
  chown -R "${PUID}:${PGID}" "${DATA_ROOT}/media/podcasts" "${DATA_ROOT}/media/audiobooks" 2>/dev/null || true
fi

# ── Patch existing qBittorrent config (critical: sed runs even if file exists) ─
QBT_CONF="./data/qbittorrent/config/qBittorrent/qBittorrent.conf"
if [ -f "$QBT_CONF" ]; then
  echo "Patching existing qBittorrent.conf paths ..."
  sed -i 's|/downloads/incomplete/|/data/torrents/incomplete/|g; s|/downloads/|/data/torrents/|g' "$QBT_CONF"
fi

# ── Force-update qBittorrent categories (always sync from template) ───────────
QBT_CAT_DIR="./data/qbittorrent/config/qBittorrent"
mkdir -p "$QBT_CAT_DIR"
cp config/qbittorrent/categories.json "${QBT_CAT_DIR}/categories.json"
echo "Updated qBittorrent categories.json from template."

# ── Seed configs from templates if not yet present ───────────────────────────
if [ ! -f "$QBT_CONF" ]; then
  mkdir -p "$(dirname "$QBT_CONF")"
  cp config/qbittorrent/qBittorrent.conf "$QBT_CONF"
  echo "Seeded qBittorrent.conf from config-templates."
fi
for f in services.yaml settings.yaml docker.yaml widgets.yaml bookmarks.yaml; do
  if [ ! -f "./data/homepage/config/$f" ] && [ -f "./config/homepage/$f" ]; then
    cp "./config/homepage/$f" "./data/homepage/config/$f"
    echo "Seeded Homepage $f from config templates."
  fi
done
if [ ! -f ./data/stirling-pdf/configs/settings.yml ] && [ -f ./config/stirling-pdf/settings.yml ]; then
  mkdir -p ./data/stirling-pdf/configs
  cp config/stirling-pdf/settings.yml ./data/stirling-pdf/configs/settings.yml
  echo "Seeded Stirling PDF settings.yml from config-templates."
fi
if [ ! -f ./data/crosswatch/config.json ] && [ -f ./config/crosswatch/config.json ]; then
  cp config/crosswatch/config.json ./data/crosswatch/config.json
  echo "Seeded CrossWatch config.json from config-templates."
fi
if [ ! -f ./data/recyclarr/config/recyclarr.yml ] && [ -f ./config/recyclarr/recyclarr.yml ]; then
  mkdir -p ./data/recyclarr/config
  cp config/recyclarr/recyclarr.yml ./data/recyclarr/config/recyclarr.yml
  echo "Seeded Recyclarr recyclarr.yml from config-templates."
fi
if [ ! -f ./data/recyclarr/config/configs/hd-bluray-web.yml ] && [ -f ./config/recyclarr/configs/hd-bluray-web.yml ]; then
  mkdir -p ./data/recyclarr/config/configs
  cp config/recyclarr/configs/hd-bluray-web.yml ./data/recyclarr/config/configs/hd-bluray-web.yml
  cp config/recyclarr/configs/web-1080p.yml ./data/recyclarr/config/configs/web-1080p.yml
  echo "Seeded Recyclarr profile configs from config-templates."
fi

# ── Ensure the shared external network exists ─────────────────────────────────
docker network create homelab_net 2>/dev/null || true

# ── Always use --env-file .env for all stacks ─────────────────────────────────
if [ -f .env ]; then
  ENV_FILE_ARG="--env-file .env"
else
  ENV_FILE_ARG=""
fi

failures=()

up_stack() {
  local name="$1"; shift
  echo "Bringing up ${name}..."
  if ! docker compose $ENV_FILE_ARG "$@" up -d --remove-orphans; then
    failures+=("$name")
    echo "WARNING: ${name} failed" >&2
  fi
}

for dir in stacks/*; do
  [ -d "$dir" ] || continue
  stack_name="$(basename "$dir")"
  if [ -f "$dir/compose.db.yaml" ]; then
    up_stack "${stack_name}-db" -f "$dir/compose.db.yaml"
  fi

  files=()
  if [ -f "$dir/compose.yaml" ]; then
    files+=(-f "$dir/compose.yaml")
  fi
  if [ -f "$dir/compose.override.yaml" ]; then
    files+=(-f "$dir/compose.override.yaml")
  fi
  if [ "${USE_VPN}" = "true" ] && [ -f "$dir/compose.vpn.yaml" ]; then
    files+=(-f "$dir/compose.vpn.yaml")
  fi

  if [ ${#files[@]} -gt 0 ]; then
    up_stack "$stack_name" "${files[@]}"
  fi
done

if [ ${#failures[@]} -gt 0 ]; then
  echo "FAILED stacks: ${failures[*]}"
  exit 1
fi

echo "All stacks are up"
