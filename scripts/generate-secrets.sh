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

set_if_empty "AUTHELIA_JWT_SECRET"           "$(openssl rand -hex 64)"
set_if_empty "AUTHELIA_SESSION_SECRET"       "$(openssl rand -hex 32)"
set_if_empty "AUTHELIA_STORAGE_ENCRYPTION_KEY" "$(openssl rand -hex 32)"
set_if_empty "DB_PASSWORD"                   "$(openssl rand -hex 32)"
set_if_empty "NEXTCLOUD_DB_PASSWORD"         "$(openssl rand -hex 32)"
set_if_empty "NEXTCLOUD_REDIS_PASSWORD"      "$(openssl rand -hex 32)"
set_if_empty "PAPERLESS_SECRET_KEY"          "$(openssl rand -hex 32)"
set_if_empty "PAPERLESS_DB_PASSWORD"         "$(openssl rand -hex 32)"
set_if_empty "JOPLIN_DB_PASSWORD"            "$(openssl rand -hex 32)"
set_if_empty "YAMTRACK_SECRET"               "$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
set_if_empty "RESTIC_BACKUP_PASSWORD"        "$(openssl rand -hex 32)"

# Monica APP_KEY requires the base64: prefix (Laravel requirement)
set_if_empty "MONICA_APP_KEY"                "base64:$(openssl rand -base64 32 | tr -d '\n')"

echo ""
echo "[done] Fill in manually (require external account registration or first-run setup):"
echo "  TUNNEL_TOKEN          — Cloudflare Tunnel token (dash.cloudflare.com → Zero Trust)"
echo "  OPENVPN_USER          — ProtonVPN OpenVPN/IKEv2 username"
echo "  OPENVPN_PASSWORD      — ProtonVPN OpenVPN/IKEv2 password"
echo "  RESTIC_S3_KEY_ID      — Backblaze B2 application key ID"
echo "  RESTIC_S3_SECRET      — Backblaze B2 application key secret"
echo "  NEXTCLOUD_ADMIN_PASSWORD, PAPERLESS_ADMIN_PASSWORD, MEALIE_DEFAULT_PASSWORD"
echo "  UPTIMEKUMA_PASS       — set AFTER Uptime Kuma first-run wizard"
echo "  VAULTWARDEN_ADMIN_TOKEN — Argon2 hash (optional; run: docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp)"
