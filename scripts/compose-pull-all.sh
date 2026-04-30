#!/bin/bash
# Script to pull latest images for all homelab stacks
set -e

cd "$(dirname "$0")/.."

# Always use --env-file .env for all stacks if present
if [ -f .env ]; then
  ENV_FILE_ARG="--env-file .env"
else
  ENV_FILE_ARG=""
fi

USE_VPN=$(grep -E '^USE_VPN=' .env 2>/dev/null | head -1 | cut -d= -f2-)

# Pull both compose files when VPN is enabled (gluetun + deunhealth images)
if [ "${USE_VPN}" = "true" ]; then
  ARR_COMPOSE="-f dockerfiles/arr/compose.yaml -f dockerfiles/arr/compose.vpn.yaml"
else
  ARR_COMPOSE="-f dockerfiles/arr/compose.yaml"
fi

echo "Pulling core images..."
docker compose $ENV_FILE_ARG -f dockerfiles/core/compose.yaml pull

echo "Pulling arr images..."
docker compose $ENV_FILE_ARG $ARR_COMPOSE pull

echo "Pulling media images..."
docker compose $ENV_FILE_ARG -f dockerfiles/media/compose.yaml pull

echo "Pulling productivity images..."
docker compose $ENV_FILE_ARG -f dockerfiles/productivity/compose.yaml pull

echo "Pulling immich images..."
docker compose $ENV_FILE_ARG -f dockerfiles/immich/compose.yaml -f dockerfiles/immich/compose.override.yaml pull

echo "Pulling monitoring images..."
docker compose $ENV_FILE_ARG -f dockerfiles/monitoring/compose.yaml pull

echo "Pulling documents images..."
docker compose $ENV_FILE_ARG -f dockerfiles/documents/compose.yaml pull

echo "Pulling tools images..."
docker compose $ENV_FILE_ARG -f dockerfiles/tools/compose.yaml pull

echo "Pulling personal images..."
docker compose $ENV_FILE_ARG -f dockerfiles/personal/compose.yaml pull

echo "Pulling entertainment images..."
docker compose $ENV_FILE_ARG -f dockerfiles/entertainment/compose.yaml pull

echo "Pulling home images..."
docker compose $ENV_FILE_ARG -f dockerfiles/home/compose.yaml pull

echo "All images pulled!"
