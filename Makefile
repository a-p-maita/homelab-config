
ENV_FILE=.env
MEDIA_SRC ?= $(HOME)/data/media
BACKUP_DIR ?= backups

.PHONY: init infra-up all-up pull restart backup db-backup down status homepage-sync set-domain set-ip snapshot-minimal backup-media prune-repo list-minimal

init:
	@test -f $(ENV_FILE) || cp .env.example $(ENV_FILE)
	@echo "[init] .env present; generating secrets (skips existing keys)"
	@./scripts/generate-secrets.sh

infra-up:
	@docker compose --env-file $(ENV_FILE) -f stacks/infrastructure/compose.yaml up -d

all-up:
	@echo "[all-up] Starting infra, dbs, and app stacks (may take several minutes)"
	@docker compose --env-file $(ENV_FILE) -f stacks/infrastructure/compose.yaml up -d
	@docker compose --env-file $(ENV_FILE) -f stacks/cloud/compose.db.yaml up -d || true
	@docker compose --env-file $(ENV_FILE) -f stacks/cloud/compose.yaml up -d || true
	@docker compose --env-file $(ENV_FILE) -f stacks/services/compose.db.yaml up -d || true
	@docker compose --env-file $(ENV_FILE) -f stacks/services/compose.yaml up -d || true
	@docker compose --env-file $(ENV_FILE) -f stacks/media/compose.yaml up -d || true
	@docker compose --env-file $(ENV_FILE) -f stacks/arr/compose.yaml up -d || true
	@docker compose --env-file $(ENV_FILE) -f stacks/monitoring/compose.yaml up -d || true
	@docker compose --env-file $(ENV_FILE) -f stacks/home/compose.yaml up -d || true

pull:
	@echo "[pull] Pulling images for all stacks (infrastructure first)"
	@docker compose --env-file $(ENV_FILE) -f stacks/infrastructure/compose.yaml pull || true
	@docker compose --env-file $(ENV_FILE) -f stacks/cloud/compose.yaml pull || true
	@docker compose --env-file $(ENV_FILE) -f stacks/services/compose.yaml pull || true
	@docker compose --env-file $(ENV_FILE) -f stacks/media/compose.yaml pull || true

restart:
	@echo "[restart] Running restart-update-all.sh (full restart + pull)"
	@./scripts/restart-update-all.sh

backup:
	@echo "[backup] Running host backup (restic)"
	@./scripts/backup.sh

db-backup:
	@echo "[db-backup] Dumping databases to ./backups"
	@./scripts/backup-dbs.sh

down:
	@echo "[down] Bringing all stacks down"
	@./scripts/down-all.sh

status:
	@docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

homepage-sync:
	@echo "[homepage-sync] (re)starting homepage container to pick up config changes"
	@docker compose --env-file $(ENV_FILE) -f stacks/infrastructure/compose.yaml up -d homepage || true

set-domain:
	@if [ -z "$(DOMAIN)" ]; then echo "Usage: make set-domain DOMAIN=example.com"; exit 1; fi
	@if grep -q '^DOMAIN=' $(ENV_FILE) 2>/dev/null; then \
		sed -i -E 's/^DOMAIN=.*/DOMAIN=$(DOMAIN)/' $(ENV_FILE); \
	else \
		echo "DOMAIN=$(DOMAIN)" >> $(ENV_FILE); \
	fi
	@echo "[set-domain] DOMAIN set to $(DOMAIN) in $(ENV_FILE). Run 'make homepage-sync' and 'make infra-up' if needed."

set-ip:
	@if [ -z "$(TAILSCALE_IP)" ]; then echo "Usage: make set-ip TAILSCALE_IP=100.106.40.5"; exit 1; fi
	@if grep -q '^TAILSCALE_IP=' $(ENV_FILE) 2>/dev/null; then \
		sed -i -E 's/^TAILSCALE_IP=.*/TAILSCALE_IP=$(TAILSCALE_IP)/' $(ENV_FILE); \
	else \
		echo "TAILSCALE_IP=$(TAILSCALE_IP)" >> $(ENV_FILE); \
	fi
	@echo "[set-ip] TAILSCALE_IP set to $(TAILSCALE_IP) in $(ENV_FILE). Run 'make homepage-sync' and 'make infra-up' if needed."

# Snapshot minimal tracked files (safe, creates backups/minimal-YYYY-MM-DD.tar.gz)
snapshot-minimal:
	@mkdir -p $(BACKUP_DIR)
	@sh -c 'files=""; for f in .env .env.example .gitignore plan.md README.md; do [ -f "$$f" ] && files="$$files $$f"; done; if [ -z "$$files" ]; then echo "[snapshot-minimal] no files found to archive"; else tar czf $(BACKUP_DIR)/minimal-$(shell date +%F).tar.gz $$files && echo "[snapshot-minimal] created $(BACKUP_DIR)/minimal-$(shell date +%F).tar.gz"; fi'

# Backup media directory (default: $(HOME)/data/media) into backups/media-YYYY-MM-DD.tar.gz
backup-media:
	@mkdir -p $(BACKUP_DIR)
	@if [ ! -d "$(MEDIA_SRC)" ]; then echo "[backup-media] MEDIA_SRC not found: $(MEDIA_SRC)"; exit 1; fi
	@tar czf $(BACKUP_DIR)/media-$(shell date +%F).tar.gz -C "$(MEDIA_SRC)" . && echo "[backup-media] created $(BACKUP_DIR)/media-$(shell date +%F).tar.gz"

# Dry-run shows what would be removed; to execute: make prune-repo CONFIRM=YES
prune-repo:
	@echo "[prune-repo] DRY RUN: files/dirs that would be removed (keeping .env, .env.example, .gitignore, plan.md, README.md, backups/)"
	@find . -maxdepth 1 -mindepth 1 -not -name '.git' -not -name '.gitignore' -not -name '.env' -not -name '.env.example' -not -name 'plan.md' -not -name 'README.md' -not -name 'backups' -print
	@if [ "$(CONFIRM)" != "YES" ]; then echo "To actually purge, run: make prune-repo CONFIRM=YES"; exit 0; fi
	@$(MAKE) snapshot-minimal || true
	@echo "[prune-repo] Removing non-essential files..."
	@find . -maxdepth 1 -mindepth 1 -not -name '.git' -not -name '.gitignore' -not -name '.env' -not -name '.env.example' -not -name 'plan.md' -not -name 'README.md' -not -name 'backups' -exec rm -rf {} +
	@echo "[prune-repo] Done. Repository reduced to minimal files (keep backups/ to restore if needed)."

list-minimal:
	@echo "Files preserved:"
	@ls -1 . | grep -E '(^\.git$$|^\.gitignore$$|^\.env$$|^\.env\.example$$|^plan\.md$$|^README\.md$$|^backups$$)' || true
