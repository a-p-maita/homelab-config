#!/bin/bash
# Script to bring down all homelab stacks
set -e

cd "$(dirname "$0")/.."

# Always use --env-file .env for all stacks if present
if [ -f .env ]; then
  ENV_FILE_ARG="--env-file .env"
else
  ENV_FILE_ARG=""
fi

echo "Bringing down monitoring..."
docker compose $ENV_FILE_ARG -f dockerfiles/monitoring/compose.yaml down

echo "Bringing down immich..."
docker compose $ENV_FILE_ARG -f dockerfiles/immich/compose.yaml -f dockerfiles/immich/compose.override.yaml down

echo "Bringing down productivity..."
docker compose $ENV_FILE_ARG -f dockerfiles/productivity/compose.yaml down

echo "Bringing down media..."
docker compose $ENV_FILE_ARG -f dockerfiles/media/compose.yaml down

echo "Bringing down core..."
docker compose $ENV_FILE_ARG -f dockerfiles/core/compose.yaml down

echo "All stacks are down!"
