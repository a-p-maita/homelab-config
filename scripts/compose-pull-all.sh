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

echo "Pulling core images..."
docker compose $ENV_FILE_ARG -f core/compose.yaml pull

echo "Pulling media images..."
docker compose $ENV_FILE_ARG -f media/compose.yaml pull

echo "Pulling productivity images..."
docker compose $ENV_FILE_ARG -f productivity/compose.yaml pull

echo "Pulling immich images..."
docker compose $ENV_FILE_ARG -f immich/compose.yaml -f immich/compose.override.yaml pull

echo "Pulling monitoring images..."
docker compose $ENV_FILE_ARG -f monitoring/compose.yaml pull

echo "All images pulled!"
