
SHELL := /bin/zsh

# Generic docker compose wrapper (run from project root)
COMPOSE := docker compose --env-file .env
DEFAULT_STACK ?= stacks/infrastructure/compose.yaml

.PHONY: infra-up all-up generate-secrets backup-data hardening-scan \
        compose compose-config compose-up service-up logs help

infra-up:
	@echo "Validating infra compose..."
	$(COMPOSE) -f stacks/infrastructure/compose.yaml config --quiet
	@echo "Bringing infra up (detached)"
	$(COMPOSE) -f stacks/infrastructure/compose.yaml up -d $(EXTRA)

all-up:
	@echo "Bringing up all stacks (cloud -> services -> media -> arr -> home)"
	$(COMPOSE) -f stacks/cloud/compose.yaml up -d $(EXTRA)
	$(COMPOSE) -f stacks/services/compose.yaml up -d $(EXTRA)
	$(COMPOSE) -f stacks/media/compose.yaml up -d $(EXTRA)
	$(COMPOSE) -f stacks/arr/compose.yaml up -d $(EXTRA)
	$(COMPOSE) -f stacks/home/compose.yaml up -d $(EXTRA)

backup-data:
	@echo "Backing up ${DATA_ROOT} to /mnt/backup/homelab-data (update target as needed)"
	rsync -a --delete ${DATA_ROOT} /mnt/backup/homelab-data


# Generic compose wrapper
compose:
	@STACK=$(if $(STACK),$(STACK),$(DEFAULT_STACK)); \
	ARGS="$(COMPOSE_ARGS)"; \
	echo "Running: $(COMPOSE) -f $$STACK $$ARGS"; \
	$(COMPOSE) -f $$STACK $$ARGS

compose-config:
	@STACK=$(if $(STACK),$(STACK),$(DEFAULT_STACK)); \
	echo "Validating: $(COMPOSE) -f $$STACK config --quiet"; \
	$(COMPOSE) -f $$STACK config --quiet

# Bring up default or specified stack (allows extra args via COMPOSE_ARGS)
compose-up:
	@STACK=$(if $(STACK),$(STACK),$(DEFAULT_STACK)); \
	ARGS="$(if $(COMPOSE_ARGS),$(COMPOSE_ARGS),up -d)"; \
	echo "Running: $(COMPOSE) -f $$STACK $$ARGS"; \
	$(COMPOSE) -f $$STACK $$ARGS

# Start an individual service by name: make service-up SERVICE=authelia
service-up:
	@if [ -z "$(SERVICE)" ]; then echo "Service name required: make service-up SERVICE=<name>"; exit 1; fi; \
	STACK=$(if $(STACK),$(STACK),$(DEFAULT_STACK)); \
	echo "Starting service $(SERVICE) in $$STACK"; \
	$(COMPOSE) -f $$STACK up -d $(SERVICE)

# Tail logs for a service using the compose file: make logs SERVICE=authelia
logs:
	@SRV=$(if $(SERVICE),$(SERVICE),authelia); \
	STACK=$(if $(STACK),$(STACK),$(DEFAULT_STACK)); \
	echo "Tailing logs for $$SRV (compose file $$STACK)"; \
	$(COMPOSE) -f $$STACK logs -f $$SRV

help:
	@echo "Makefile helpers:"; \
	@echo "  make compose STACK=stacks/infrastructure/compose.yaml COMPOSE_ARGS='up -d authelia'"; \
	@echo "  make compose-config STACK=..."; \
	@echo "  make compose-up STACK=... COMPOSE_ARGS='up -d'"; \
	@echo "  make service-up SERVICE=authelia"; \

# Generic stack helpers: list, up, down, validate any compose file under stacks/
.PHONY: stack-list stack-up stack-down stack-validate stacks-validate

stack-list:
	@echo "Compose files under stacks/:"; \
	@find stacks -type f -name 'compose.yaml' | sort

# Usage: make stack-up STACK=stacks/arr/compose.yaml [SERVICE=<name>]
stack-up:
	@if [ -n "$(STACK)" ]; then \
		echo "Bringing up compose: $(STACK)"; \
		$(COMPOSE) -f $(STACK) up -d $(SERVICE); \
	else \
		echo "Bringing up all stacks under stacks/"; \
		for f in $(shell find stacks -type f -name 'compose.yaml' | sort); do \
			echo "Up: $$f"; \
			$(COMPOSE) -f $$f up -d $(SERVICE); \
		done; \
	fi

# Usage: make stack-down STACK=stacks/mail/compose.yaml [SERVICE=<name>]
stack-down:
	@if [ -n "$(STACK)" ]; then \
		echo "Taking down compose: $(STACK)"; \
		$(COMPOSE) -f $(STACK) down; \
	else \
		echo "Taking down all stacks under stacks/"; \
		for f in $(shell find stacks -type f -name 'compose.yaml' | sort); do \
			echo "Down: $$f"; \
			$(COMPOSE) -f $$f down; \
		done; \
	fi

# Validate a single stack or all stacks
stack-validate:
	@if [ -n "$(STACK)" ]; then \
		echo "Validating compose: $(STACK)"; \
		$(COMPOSE) -f $(STACK) config --quiet; \
	else \
		echo "Validating all stacks under stacks/"; \
		for f in $(shell find stacks -type f -name 'compose.yaml' | sort); do \
			echo "Validate: $$f"; \
			$(COMPOSE) -f $$f config --quiet || exit 1; \
		done; \
	fi
