#!/bin/bash
# Script to bring up all homelab stacks with correct env and data directories
set -e

cd "$(dirname "$0")"

# Ensure homelab-data subdirs exist
mkdir -p ./homelab-data/audiobooks ./homelab-data/podcasts ./homelab-data/audiobookshelf/config ./homelab-data/audiobookshelf/metadata ./homelab-data/qbittorrent-downloads ./homelab-data/dufs ./homelab-data/forgejo ./homelab-data/immich_db ./homelab-data/immich_upload ./homelab-data/qbittorrent ./homelab-data/ryot/data ./homelab-data/ryot/db ./homelab-data/syncthing/config ./homelab-data/syncthing/data

# Ensure the shared external network exists (stacks declare it external so it must pre-exist)
docker network create homelab_net 2>/dev/null || true

# Always use --env-file .env for all stacks if present
if [ -f .env ]; then
  ENV_FILE_ARG="--env-file .env"
else
  ENV_FILE_ARG=""
fi

echo "Bringing up core..."
docker compose $ENV_FILE_ARG -f core/compose.yaml up -d

echo "Bringing up media..."
docker compose $ENV_FILE_ARG -f media/compose.yaml up -d

echo "Bringing up productivity..."
docker compose $ENV_FILE_ARG -f productivity/compose.yaml up -d

echo "Bringing up immich..."
docker compose $ENV_FILE_ARG -f immich/compose.yaml -f immich/compose.override.yaml up -d

echo "All stacks are up"
