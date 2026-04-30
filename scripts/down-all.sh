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

USE_VPN=$(grep -E '^USE_VPN=' .env 2>/dev/null | head -1 | cut -d= -f2-)

# Arr stack compose files depend on USE_VPN flag
if [ "${USE_VPN}" = "true" ]; then
  ARR_COMPOSE="-f dockerfiles/arr/compose.yaml -f dockerfiles/arr/compose.vpn.yaml"
else
  ARR_COMPOSE="-f dockerfiles/arr/compose.yaml"
fi

echo "Bringing down home..."
docker compose $ENV_FILE_ARG -f dockerfiles/home/compose.yaml down

echo "Bringing down entertainment..."
docker compose $ENV_FILE_ARG -f dockerfiles/entertainment/compose.yaml down

echo "Bringing down personal..."
docker compose $ENV_FILE_ARG -f dockerfiles/personal/compose.yaml down

echo "Bringing down tools..."
docker compose $ENV_FILE_ARG -f dockerfiles/tools/compose.yaml down

echo "Bringing down documents..."
docker compose $ENV_FILE_ARG -f dockerfiles/documents/compose.yaml down

echo "Bringing down monitoring..."
docker compose $ENV_FILE_ARG -f dockerfiles/monitoring/compose.yaml down

echo "Bringing down immich..."
docker compose $ENV_FILE_ARG -f dockerfiles/immich/compose.yaml -f dockerfiles/immich/compose.override.yaml down

echo "Bringing down productivity..."
docker compose $ENV_FILE_ARG -f dockerfiles/productivity/compose.yaml down

echo "Bringing down media..."
docker compose $ENV_FILE_ARG -f dockerfiles/media/compose.yaml down

echo "Bringing down arr..."
docker compose $ENV_FILE_ARG $ARR_COMPOSE down

echo "Bringing down core..."
docker compose $ENV_FILE_ARG -f dockerfiles/core/compose.yaml down

echo "All stacks are down!"
