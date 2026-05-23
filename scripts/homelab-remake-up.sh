#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Bring up the homelab stacks in a safe order.
# Use .env from repo root.

docker compose --env-file .env -f stacks/infrastructure/compose.yaml up -d
docker compose --env-file .env -f stacks/monitoring/compose.yaml up -d
docker compose --env-file .env -f stacks/cloud/compose.db.yaml -f stacks/cloud/compose.yaml -f stacks/cloud/compose.override.yaml up -d
docker compose --env-file .env -f stacks/services/compose.db.yaml up -d
docker compose --env-file .env -f stacks/services/compose.yaml up -d
docker compose --env-file .env -f stacks/media/compose.yaml up -d
docker compose --env-file .env -f stacks/arr/compose.yaml up -d
docker compose --env-file .env -f stacks/home/compose.yaml up -d

echo "All stacks started. Check docker ps and health with 'docker ps' or 'docker compose ps'."
