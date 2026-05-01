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
  ARR_COMPOSE="-f stacks/arr/compose.yaml -f stacks/arr/compose.vpn.yaml"
else
  ARR_COMPOSE="-f stacks/arr/compose.yaml"
fi

echo "Pulling infrastructure images..."
docker compose $ENV_FILE_ARG -f stacks/infrastructure/compose.yaml pull

echo "Pulling arr images..."
docker compose $ENV_FILE_ARG $ARR_COMPOSE pull

echo "Pulling media images..."
docker compose $ENV_FILE_ARG -f stacks/media/compose.yaml pull

echo "Pulling cloud images..."
docker compose $ENV_FILE_ARG -f stacks/cloud/compose.yaml -f stacks/cloud/compose.override.yaml pull

echo "Pulling services-db images..."
docker compose $ENV_FILE_ARG -f stacks/services/compose.db.yaml pull

echo "Pulling services images..."
docker compose $ENV_FILE_ARG -f stacks/services/compose.yaml pull

echo "Pulling home images..."
docker compose $ENV_FILE_ARG -f stacks/home/compose.yaml pull

echo "All images pulled!"
