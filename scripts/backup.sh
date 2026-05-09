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
  "${DATA_ROOT}" \
  "${SCRIPT_DIR}/../config" \
  "${SCRIPT_DIR}/../.env" \
  --tag homelab \
  --exclude="*.log" \
  --exclude="*.tmp" \
  --exclude="${DATA_ROOT}/media" \
  --exclude="${DATA_ROOT}/torrents" \
  --exclude="${DATA_ROOT}/**/cache" \
  --exclude="${DATA_ROOT}/**/Cache" \
  --exclude="${DATA_ROOT}/immich_upload/encoded-video" \
  --exclude="${DATA_ROOT}/immich_upload/thumbs" \
  --exclude="${DATA_ROOT}/immich_upload/profile" \
  --exclude="${DATA_ROOT}/downloads" \
  --exclude="${DATA_ROOT}/audiobookbay-downloader/audiobooks" \
  --exclude="${DATA_ROOT}/audiobookbay-downloader/listenbrainz" \
  --exclude="${DATA_ROOT}/audiobookshelf/metadata/cache" \
  --exclude="${DATA_ROOT}/komga/artemis" \
  --exclude="${DATA_ROOT}/jellyfin/cache" \
  --exclude="${DATA_ROOT}/jellyfin/metadata" \
  --exclude="${DATA_ROOT}/jellyfin/transcoding-temp" \
  --exclude="${DATA_ROOT}/**/*.hprof" \
  --exclude="${DATA_ROOT}/home-assistant/home-assistant_v2.db"


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
