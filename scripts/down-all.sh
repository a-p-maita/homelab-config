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
  ARR_COMPOSE="-f stacks/arr/compose.yaml -f stacks/arr/compose.vpn.yaml"
else
  ARR_COMPOSE="-f stacks/arr/compose.yaml"
fi

echo "Bringing down home..."
docker compose $ENV_FILE_ARG -f stacks/home/compose.yaml down --remove-orphans

echo "Bringing down services..."
docker compose $ENV_FILE_ARG -f stacks/services/compose.yaml down --remove-orphans

echo "Bringing down services-db..."
docker compose $ENV_FILE_ARG -f stacks/services/compose.db.yaml down --remove-orphans

echo "Bringing down cloud..."
docker compose $ENV_FILE_ARG -f stacks/cloud/compose.yaml -f stacks/cloud/compose.override.yaml down --remove-orphans

echo "Bringing down media..."
docker compose $ENV_FILE_ARG -f stacks/media/compose.yaml down --remove-orphans

echo "Bringing down arr..."
docker compose $ENV_FILE_ARG $ARR_COMPOSE down --remove-orphans

echo "Bringing down infrastructure..."
docker compose $ENV_FILE_ARG -f stacks/infrastructure/compose.yaml down --remove-orphans

echo "All stacks are down!"
