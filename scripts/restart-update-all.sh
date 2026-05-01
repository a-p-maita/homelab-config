#!/usr/bin/env bash
# restart-update-all.sh - Full homelab restart, update and reconfigure
#
# Usage:
#   ./scripts/restart-update-all.sh            # restart + pull images + reconfigure
#   ./scripts/restart-update-all.sh --backup   # also dump databases first
#
# Steps:
#   1. (optional) Backup databases
#   2. Git pull - apply any config changes from remote
#   3. Bring all stacks down
#   4. Pull latest images
#   5. Force-sync homepage config from templates
#   6. Bring all stacks up
#   7. Configure Uptime Kuma monitors
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$ROOT"

# Colours -----------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ts()   { echo -e "${CYAN}[$(date '+%H:%M:%S')]${RESET} $*"; }
ok()   { echo -e "${GREEN}  [ok]${RESET} $*"; }
warn() { echo -e "${YELLOW}  [!]${RESET} $*"; }
sep()  { echo -e "${BOLD}${CYAN}--------------------------------------------------${RESET}"; }

sep
echo -e "${BOLD}  Homelab - Full Restart & Update${RESET}"
echo -e "  $(date '+%A %d %B %Y - %H:%M:%S')"
sep

# 1. Optional: backup databases -----------------------------------------------
if [[ "${1:-}" == "--backup" ]]; then
  ts "Backing up databases..."
  if "${SCRIPT_DIR}/backup-dbs.sh"; then
    ok "DB backups complete"
  else
    warn "DB backup failed - continuing anyway (check ${ROOT}/backups/)"
  fi
  sep
fi

# 2. Git: pull latest config ---------------------------------------------------
ts "Checking for config updates (git pull)..."
GIT_OUT=$(git pull --ff-only 2>&1) || true
if echo "$GIT_OUT" | grep -q 'Already up to date'; then
  ok "Git config is already up to date"
else
  ok "Config updated from remote"
  echo "$GIT_OUT" | sed 's/^/    /'
fi
# Fix root-owned git objects that Docker operations sometimes create
docker run --rm -v "${ROOT}/.git:/repo" alpine:3.21 \
  sh -c "chown -R $(id -u):$(id -g) /repo/objects 2>/dev/null" 2>/dev/null || true
sep

# 3. Bring everything down ----------------------------------------------------
ts "Bringing down all stacks..."
"${SCRIPT_DIR}/down-all.sh"
ok "All stacks down"
sep

# 4. Pull latest images --------------------------------------------------------
ts "Pulling latest container images..."
"${SCRIPT_DIR}/compose-pull-all.sh"
ok "All images up to date"
sep

# 5. Force-sync homepage config templates ------------------------------------
ts "Syncing homepage config from templates..."
HOMEPAGE_DATA="${ROOT}/data/homepage/config"
mkdir -p "$HOMEPAGE_DATA"
for f in services.yaml settings.yaml widgets.yaml bookmarks.yaml docker.yaml; do
  if [ -f "${ROOT}/config/homepage/${f}" ]; then
    cp -f "${ROOT}/config/homepage/${f}" "${HOMEPAGE_DATA}/${f}"
    ok "  config/homepage/${f}"
  fi
done
sep

# 6. Bring everything up ------------------------------------------------------
ts "Bringing all stacks up..."
"${SCRIPT_DIR}/up-all.sh"
ok "All stacks up"
sep

# 7. Configure Uptime Kuma monitors -------------------------------------------
ts "Configuring Uptime Kuma monitors..."
if "${SCRIPT_DIR}/setup-uptime-kuma.sh"; then
  ok "Uptime Kuma monitors configured"
else
  warn "Uptime Kuma setup failed - check manually at http://100.106.40.5:20201"
fi

# Done ------------------------------------------------------------------------
sep
echo -e "${GREEN}${BOLD}  [ok] All done - homelab is up to date${RESET}"
echo -e "  Finished at $(date '+%H:%M:%S')"
echo -e "  Dashboard: ${CYAN}http://100.106.40.5:20200${RESET}  |  ${CYAN}https://homepage.andreasmaita.com${RESET}"
sep