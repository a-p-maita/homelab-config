#!/usr/bin/env bash
# backup-dbs.sh — dump all postgres databases before any overhaul phase
# Run from the homelab-config directory root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/../backups"
mkdir -p "$BACKUP_DIR"

echo "[backup] Starting DB dumps to ${BACKUP_DIR} ..."

docker exec immich-postgres    pg_dumpall -h 127.0.0.1 -U postgres   > "${BACKUP_DIR}/immich-$(date -I).sql"
echo "[backup] immich done"

docker exec paperless-postgres pg_dumpall -h 127.0.0.1 -U a-p-maita > "${BACKUP_DIR}/paperless-$(date -I).sql"
echo "[backup] paperless done"

docker exec joplin-postgres    pg_dumpall -h 127.0.0.1 -U a-p-maita > "${BACKUP_DIR}/joplin-$(date -I).sql"
echo "[backup] joplin done"

echo "[backup] DB dumps complete → ${BACKUP_DIR}"
