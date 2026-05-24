SHELL := /bin/bash
.PHONY: infra-up all-up generate-secrets backup-data hardening-scan

infra-up:
	@echo "Validating infra compose..."
	docker compose --env-file .env -f stacks/infrastructure/compose.yaml config --quiet
	@echo "Bringing infra up (detached)"
	docker compose --env-file .env -f stacks/infrastructure/compose.yaml up -d

all-up:
	@echo "Bringing up all stacks (cloud -> services -> media -> arr -> home)"
	docker compose --env-file .env -f stacks/cloud/compose.yaml up -d
	docker compose --env-file .env -f stacks/services/compose.yaml up -d
	docker compose --env-file .env -f stacks/media/compose.yaml up -d
	docker compose --env-file .env -f stacks/arr/compose.yaml up -d
	docker compose --env-file .env -f stacks/home/compose.yaml up -d

generate-secrets:
	./scripts/generate-secrets.sh

backup-data:
	@echo "Backing up ${DATA_ROOT} to /mnt/backup/homelab-data (update target as needed)"
	rsync -a --delete ${DATA_ROOT} /mnt/backup/homelab-data

hardening-scan:
	python3 scripts/harden_compose.py --output backups/compose-hardening-suggestions.txt
