#!/usr/bin/env bash
# generate-secrets.sh — populate auto-generated .env secrets on first setup
# Safe to run multiple times: skips keys already set
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[error] .env not found at ${ENV_FILE}. Copy .env.example to .env first."
  exit 1
fi

set_if_empty() {
  local key="$1" value="$2"
  # Set if the key is absent or set to empty
  if grep -qE "^${key}=$" "$ENV_FILE" 2>/dev/null || ! grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    if grep -qE "^${key}=" "$ENV_FILE" 2>/dev/null; then
      sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
      echo "${key}=${value}" >> "$ENV_FILE"
    fi
    echo "[generated] ${key}"
  else
    echo "[skip]      ${key} already set"
  fi
}

set_if_empty "AUTHELIA_SESSION_SECRET" "$(openssl rand -hex 32)"
set_if_empty "AUTHELIA_STORAGE_KEY"    "$(openssl rand -hex 32)"
set_if_empty "GRAFANA_PASSWORD"        "$(openssl rand -base64 16 | tr -d '=')"
set_if_empty "RESTIC_BACKUP_PASSWORD"  "$(openssl rand -hex 32)"

echo ""
echo "[done] Fill in manually (require external account registration):"
echo "  RESTIC_S3_KEY_ID   — Backblaze B2 application key ID"
echo "  RESTIC_S3_SECRET   — Backblaze B2 application key"
echo "  CF_API_TOKEN       — Cloudflare API token (DNS edit, for Caddy ACME)"
echo "  TUNNEL_TOKEN       — Cloudflare Tunnel token"
