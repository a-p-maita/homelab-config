#!/bin/bash
# Script to bring up all homelab stacks with correct env and data directories
set -e

cd "$(dirname "$0")/.."

# Ensure homelab-data subdirs exist
mkdir -p \
  ./homelab-data/audiobooks \
  ./homelab-data/podcasts \
  ./homelab-data/audiobookshelf/config \
  ./homelab-data/audiobookshelf/metadata \
  ./homelab-data/qbittorrent-downloads \
  ./homelab-data/qbittorrent/config \
  ./homelab-data/jackett/config \
  ./homelab-data/jackett/downloads \
  ./homelab-data/audiobookbay-downloader \
  ./homelab-data/forgejo \
  ./homelab-data/immich_db \
  ./homelab-data/immich_upload \
  ./homelab-data/yamtrack \
  ./homelab-data/yamtrack/redis \
  ./homelab-data/crosswatch \
  ./homelab-data/homepage/config \
  ./homelab-data/uptime-kuma \
  ./homelab-data/music \
  ./homelab-data/navidrome/data \
  ./homelab-data/lidarr/config \
  ./homelab-data/slskd \
  ./homelab-data/paperless/redis \
  ./homelab-data/paperless/db \
  ./homelab-data/paperless/data \
  ./homelab-data/paperless/media \
  ./homelab-data/paperless/consume \
  ./homelab-data/paperless/export \
  ./homelab-data/paperless/gpt-prompts \
  ./homelab-data/stirling-pdf/configs \
  ./homelab-data/stirling-pdf/logs \
  ./homelab-data/kiwix \  ./homelab-data/code-server/config \
  ./homelab-data/libreoffice/config \
  ./homelab-data/vaultwarden \
  ./homelab-data/actual-budget \
  ./homelab-data/joplin/db \
  ./homelab-data/job-ops \
  ./homelab-data/meshcentral/data \
  ./homelab-data/meshcentral/user-files \
  ./homelab-data/meshcentral/backups \
  ./homelab-data/mealie \
  ./homelab-data/lubelogger/data \
  ./homelab-data/lubelogger/documents \
  ./homelab-data/lubelogger/images \
  ./homelab-data/lubelogger/translations \
  ./homelab-data/lubelogger/keys \
  ./homelab-data/monica/db \
  ./homelab-data/monica/storage \
  ./homelab-data/jellyfin/config \
  ./homelab-data/jellyfin/cache \
  ./homelab-data/romm/db \
  ./homelab-data/romm/library \
  ./homelab-data/romm/assets \
  ./homelab-data/romm/config \
  ./homelab-data/home-assistant

# Ensure the shared external network exists (stacks declare it external so it must pre-exist)
docker network create homelab_net 2>/dev/null || true

# Seed Homepage config from template if not already present (containers never started yet)
if [ ! -f ./homelab-data/homepage/config/services.yaml ]; then
  cp config-templates/homepage/services.yaml ./homelab-data/homepage/config/services.yaml
  echo "Seeded Homepage services.yaml from config-templates."
fi

# Create empty kiwix library XML if not present (kiwix-serve exits on startup without it)
if [ ! -f ./homelab-data/kiwix/library.xml ]; then
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<library version="20110515"/>\n' \
    > ./homelab-data/kiwix/library.xml
  echo "Created empty kiwix library.xml."
fi

# Always use --env-file .env for all stacks if present
if [ -f .env ]; then
  ENV_FILE_ARG="--env-file .env"
else
  ENV_FILE_ARG=""
fi

echo "Bringing up core..."
docker compose $ENV_FILE_ARG -f dockerfiles/core/compose.yaml up -d

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
