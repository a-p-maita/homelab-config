#!/usr/bin/env bash
# backup.sh — Restic offsite backup + git config push
# Cron: 0 3 * * * /path/to/homelab-config/scripts/backup.sh
# Requires: restic installed on host, .env populated with RESTIC_* and S3 vars
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

# shellcheck source=/dev/null
source "$ENV_FILE"

export RESTIC_REPOSITORY="s3:https://s3.us-west-004.backblazeb2.com/homelab-backup"
export RESTIC_PASSWORD="${RESTIC_BACKUP_PASSWORD}"
export AWS_ACCESS_KEY_ID="${RESTIC_S3_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${RESTIC_S3_SECRET}"

echo "[backup] Starting Restic backup ..."

restic backup \
  "${DATA_ROOT}/vaultwarden" \
  "${DATA_ROOT}/paperless" \
  "${DATA_ROOT}/immich_upload" \
  "${DATA_ROOT}/forgejo" \
  "${DATA_ROOT}/joplin" \
  "${DATA_ROOT}/actual-budget" \
  "${DATA_ROOT}/home-assistant" \
  --tag homelab \
  --exclude="*.log" \
  --exclude="*.tmp"

restic forget --prune \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12

echo "[backup] Restic done"

# Commit and push config changes
cd "${SCRIPT_DIR}/.."
git add -A
git diff-index --quiet HEAD || (git commit -m "auto: config backup $(date -I)" && git push)
echo "[backup] Git push done"
