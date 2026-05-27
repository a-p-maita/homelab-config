# Makefile to manage docker compose stacks

SHELL := /bin/bash
STACK_DIR := stacks
STACKS ?= trackers

.PHONY: all-up all-down all-reset all-prune system-prune stack-up stack-down stack-restart stack-reset stack-prune stack-up-% stack-down-% stack-restart-% stack-reset-% stack-prune-% service-up service-down service-restart service-reset service-prune service-up-% service-down-% service-restart-% service-reset-% service-prune-% status

# Run compose up for every selected stack compose file under $(STACK_DIR)
all-up:
	for stack in $(STACKS); do \
		if [ -f "$(STACK_DIR)/$$stack/compose.yaml" ]; then \
			echo "Starting $$stack"; \
			docker compose -f "$(STACK_DIR)/$$stack/compose.yaml" up -d; \
		fi; \
	done

# Bring down every selected stack
all-down:
	for stack in $(STACKS); do \
		if [ -f "$(STACK_DIR)/$$stack/compose.yaml" ]; then \
			echo "Stopping $$stack"; \
			docker compose -f "$(STACK_DIR)/$$stack/compose.yaml" down; \
		fi; \
	done

# Restart all selected stacks from scratch
all-restart:
	for stack in $(STACKS); do \
		if [ -f "$(STACK_DIR)/$$stack/compose.yaml" ]; then \
			echo "Restarting $$stack"; \
			docker compose -f "$(STACK_DIR)/$$stack/compose.yaml" restart; \
		fi; \
	done

# Prune stopped containers, unused networks, images, and volumes
all-prune:
	$(MAKE) all-down
	docker system prune -af --volumes

system-prune: all-prune

# Reset one stack by name: make stack-reset stack=apps
stack-reset:
	@set -e; \
	if [ -z "$(stack)" ]; then \
		echo 'Error: stack variable is required. Example: make stack-reset stack=apps'; exit 1; \
	fi; \
	if [ ! -f "$(STACK_DIR)/$(stack)/compose.yaml" ]; then \
		echo "Error: $(STACK_DIR)/$(stack)/compose.yaml not found"; exit 1; \
	fi; \
	@echo "Resetting stack $(stack)"; \
	docker compose -f "$(STACK_DIR)/$(stack)/compose.yaml" down; \
	docker compose -f "$(STACK_DIR)/$(stack)/compose.yaml" up -d; \
	docker compose -f "$(STACK_DIR)/$(stack)/compose.yaml" ps

# Prune one stack by name: make stack-prune stack=apps
stack-prune:
	@set -e; \
	if [ -z "$(stack)" ]; then \
		echo 'Error: stack variable is required. Example: make stack-prune stack=apps'; exit 1; \
	fi; \
	if [ ! -f "$(STACK_DIR)/$(stack)/compose.yaml" ]; then \
		echo "Error: $(STACK_DIR)/$(stack)/compose.yaml not found"; exit 1; \
	fi; \
	@echo "Pruning stack $(stack)"; \
	docker compose -f "$(STACK_DIR)/$(stack)/compose.yaml" down; \
	docker compose -f "$(STACK_DIR)/$(stack)/compose.yaml" rm -f; \
	docker system prune -af --volumes

# Start one stack by name: make stack-up stack=apps
stack-up:
	@set -e; \
	if [ -z "$(stack)" ]; then \
		echo 'Error: stack variable is required. Example: make stack-up stack=apps'; exit 1; \
	fi; \
	if [ ! -f "$(STACK_DIR)/$(stack)/compose.yaml" ]; then \
		echo "Error: $(STACK_DIR)/$(stack)/compose.yaml not found"; exit 1; \
	fi; \
	docker compose -f "$(STACK_DIR)/$(stack)/compose.yaml" up -d; \
	docker compose -f "$(STACK_DIR)/$(stack)/compose.yaml" ps

# Stop one stack by name: make stack-down stack=apps
stack-down:
	@set -e; \
	if [ -z "$(stack)" ]; then \
		echo 'Error: stack variable is required. Example: make stack-down stack=apps'; exit 1; \
	fi; \
	if [ ! -f "$(STACK_DIR)/$(stack)/compose.yaml" ]; then \
		echo "Error: $(STACK_DIR)/$(stack)/compose.yaml not found"; exit 1; \
	fi; \
	docker compose -f "$(STACK_DIR)/$(stack)/compose.yaml" down

stack-restart:
	@set -e; \
	if [ -z "$(stack)" ]; then \
		echo 'Error: stack variable is required. Example: make stack-restart stack=apps'; exit 1; \
	fi; \
	if [ ! -f "$(STACK_DIR)/$(stack)/compose.yaml" ]; then \
		echo "Error: $(STACK_DIR)/$(stack)/compose.yaml not found"; exit 1; \
	fi; \
	docker compose -f "$(STACK_DIR)/$(stack)/compose.yaml" restart; \
	docker compose -f "$(STACK_DIR)/$(stack)/compose.yaml" ps

# Convenience pattern targets: make stack-up-apps
stack-up-%:
	$(MAKE) stack-up stack=$*
stack-down-%:
	$(MAKE) stack-down stack=$*
stack-restart-%:
	$(MAKE) stack-restart stack=$*
stack-reset-%:
	$(MAKE) stack-reset stack=$*
stack-prune-%:
	$(MAKE) stack-prune stack=$*

# Start a specific service by scanning all stacks: make service-up service=audiobookshelf
service-up:
	@set -e; \
	if [ -z "$(service)" ]; then \
		printf 'Error: service variable is required. Example: make service-up service=audiobookshelf\n'; exit 1; \
	fi; \
	service_lc="$(service)"; \
	service_lc="$$(printf '%s' "$$service_lc" | tr '[:upper:]' '[:lower:]')"; \
	for stack in $(STACKS); do \
		compose="$(STACK_DIR)/$$stack/compose.yaml"; \
		if [ -f "$${compose}" ]; then \
			services="$$(docker compose -f "$${compose}" config --services 2>/dev/null | tr '[:upper:]' '[:lower:]')"; \
			if printf '%s\n' "$$services" | grep -xq "$$service_lc"; then \
				echo "Starting service $(service) in $$stack"; \
				docker compose -f "$${compose}" up -d "$(service)"; \
				docker compose -f "$${compose}" ps "$(service)"; \
				exit 0; \
			fi; \
		fi; \
	done; \
	printf 'Error: service $(service) not found in any stack\n'; exit 1

# Stop a specific service by scanning all stacks
service-down:
	@set -e; \
	if [ -z "$(service)" ]; then \
		printf 'Error: service variable is required. Example: make service-down service=audiobookshelf\n'; exit 1; \
	fi; \
	service_lc="$(service)"; \
	service_lc="$$(printf '%s' "$$service_lc" | tr '[:upper:]' '[:lower:]')"; \
	for stack in $(STACKS); do \
		compose="$(STACK_DIR)/$$stack/compose.yaml"; \
		if [ -f "$${compose}" ]; then \
			services="$$(docker compose -f "$${compose}" config --services 2>/dev/null | tr '[:upper:]' '[:lower:]')"; \
			if printf '%s\n' "$$services" | grep -xq "$$service_lc"; then \
				echo "Stopping service $(service) in $$stack"; \
				docker compose -f "$${compose}" stop "$(service)"; \
				docker compose -f "$${compose}" ps "$(service)"; \
				exit 0; \
			fi; \
		fi; \
	done; \
	printf 'Error: service $(service) not found in any stack\n'; exit 1

service-restart:
	@set -e; \
	if [ -z "$(service)" ]; then \
		printf 'Error: service variable is required. Example: make service-restart service=audiobookshelf\n'; exit 1; \
	fi; \
	service_lc="$(service)"; \
	service_lc="$$(printf '%s' "$$service_lc" | tr '[:upper:]' '[:lower:]')"; \
	for stack in $(STACKS); do \
		compose="$(STACK_DIR)/$$stack/compose.yaml"; \
		if [ -f "$${compose}" ]; then \
			services="$$(docker compose -f "$${compose}" config --services 2>/dev/null | tr '[:upper:]' '[:lower:]')"; \
			if printf '%s\n' "$$services" | grep -xq "$$service_lc"; then \
				echo "Restarting service $(service) in $$stack"; \
				docker compose -f "$${compose}" restart "$(service)"; \
				docker compose -f "$${compose}" ps "$(service)"; \
				exit 0; \
			fi; \
		fi; \
	done; \
	printf 'Error: service $(service) not found in any stack\n'; exit 1

service-reset:
	@set -e; \
	if [ -z "$(service)" ]; then \
		printf 'Error: service variable is required. Example: make service-reset service=audiobookshelf\n'; exit 1; \
	fi; \
	service_lc="$(service)"; \
	service_lc="$$(printf '%s' "$$service_lc" | tr '[:upper:]' '[:lower:]')"; \
	for stack in $(STACKS); do \
		compose="$(STACK_DIR)/$$stack/compose.yaml"; \
		if [ -f "$${compose}" ]; then \
			services="$$(docker compose -f "$${compose}" config --services 2>/dev/null | tr '[:upper:]' '[:lower:]')"; \
			if printf '%s\n' "$$services" | grep -xq "$$service_lc"; then \
				echo "Resetting service $(service) in $$stack"; \
				docker compose -f "$${compose}" stop "$(service)"; \
				docker compose -f "$${compose}" up -d "$(service)"; \
				docker compose -f "$${compose}" ps "$(service)"; \
				exit 0; \
			fi; \
		fi; \
	done; \
	printf 'Error: service $(service) not found in any stack\n'; exit 1

service-prune:
	@set -e; \
	if [ -z "$(service)" ]; then \
		printf 'Error: service variable is required. Example: make service-prune service=audiobookshelf\n'; exit 1; \
	fi; \
	service_lc="$(service)"; \
	service_lc="$$(printf '%s' "$$service_lc" | tr '[:upper:]' '[:lower:]')"; \
	for stack in $(STACKS); do \
		compose="$(STACK_DIR)/$$stack/compose.yaml"; \
		if [ -f "$${compose}" ]; then \
			services="$$(docker compose -f "$${compose}" config --services 2>/dev/null | tr '[:upper:]' '[:lower:]')"; \
			if printf '%s\n' "$$services" | grep -xq "$$service_lc"; then \
				echo "Pruning service $(service) in $$stack"; \
				docker compose -f "$${compose}" stop "$(service)"; \
				docker compose -f "$${compose}" rm -f "$(service)"; \
				exit 0; \
			fi; \
		fi; \
	done; \
	printf 'Error: service $(service) not found in any stack\n'; exit 1
service-up-%:
	$(MAKE) service-up service=$*
service-down-%:
	$(MAKE) service-down service=$*
service-restart-%:
	$(MAKE) service-restart service=$*
service-reset-%:
	$(MAKE) service-reset service=$*
service-prune-%:
	$(MAKE) service-prune service=$*

# Print component status
status:
	for stack in $(STACKS); do \
		if [ -f "$(STACK_DIR)/$$stack/compose.yaml" ]; then \
			echo "==== $$stack ====\"; \
			docker compose -f "$(STACK_DIR)/$$stack/compose.yaml" ps; \
		fi; \
	done
