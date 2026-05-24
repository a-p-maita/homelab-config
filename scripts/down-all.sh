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

for dir in stacks/*; do
  [ -d "$dir" ] || continue
  stack_name="$(basename "$dir")"
  echo "Bringing down ${stack_name}..."
  if [ -f "$dir/compose.db.yaml" ]; then
    docker compose $ENV_FILE_ARG -f "$dir/compose.db.yaml" down --remove-orphans || true
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
    docker compose $ENV_FILE_ARG "${files[@]}" down --remove-orphans || true
  fi

done

echo "All stacks are down!"
