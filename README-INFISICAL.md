Infisical mapping and bootstrap — README

Purpose
-------

This document explains how to use `infisical-mapping.json` to centralize secrets in Infisical and render them at deploy time. The repository tracks only the mapping (keys → secret names); no secret values are committed.

Prerequisites
-------------

- An Infisical account and a project (e.g., `homelab`).
- `infisical` CLI installed and authenticated (use `infisical login`).
- You have a local (trusted) copy of `.env` for bootstrap values (host-level values only).

Files
-----

- `infisical-mapping.json` — mapping of `.env` keys to Infisical secret paths (tracked).

Recommended flow
----------------

1) REVIEW `infisical-mapping.json` and add any missing keys (do NOT add values here).

2) Add secret values to Infisical (preferred via the Infisical UI or CLI). Example CLI concept (UI often easier for first-time use):

```bash
# login interactively
infisical login

# (example) push mapping metadata and values from a rendered file (this is a template; adapt to your workflow)
# NOTE: do NOT commit .env.rendered to git
infisical push --path infisical-mapping.json --values-from .env.rendered
```

1) Render secrets at deploy time (creates `.env.rendered`, do NOT commit):

```bash
infisical render --project homelab --output .env.rendered
```

1) (Optional preferred) Create Docker secrets from the rendered `.env` and update Compose to use `_FILE` semantics:

```bash
# example: create paperless DB secret from rendered .env
echo -n "$(grep '^PAPERLESS_DB_PASS=' .env.rendered | cut -d'=' -f2-)" | docker secret create paperless_db_pass -

# then in your compose: PAPERLESS_DB_PASS_FILE=/run/secrets/paperless_db_pass
```

1) Deploy using the rendered `.env` or Docker secrets. Example (validate first):

```bash
# validate infra compose
docker compose -f stacks/infrastructure/compose.yaml config --quiet
# bring infra up
docker compose -f stacks/infrastructure/compose.yaml up -d
```

Security & best practices
-------------------------

- NEVER commit `.env.rendered` or any file containing secret values.
- Keep `infisical-mapping.json` under version control — it documents which keys map to which secret names.
- Use concise secret names (e.g., `paperless/db/password`) and consistent naming across projects.
- When rotating secrets, update Infisical secrets first, then render and update Docker secrets / `.env` references.
- Keep an audit ledger outside the repo (e.g., `backups/env-rotate-log.txt`) that records old→new mapping by hash only (no plaintext secrets).

Troubleshooting
---------------

- If `infisical render` fails, verify your CLI auth (`infisical whoami`), project name, and mapping keys.
- If services fail after secret rotation, consult service-specific migration docs — some apps require in-app password updates after DB password changes.

What I added
------------

- `infisical-mapping.json` — mapping file (tracked)
- `README-INFISICAL.md` — this guide

Next recommended step
---------------------

If you'd like, I can now convert the `backups/env-migration-commands.sh` templates into concrete, non-executing command templates for each reuse group (exact `docker secret create` commands, `sed` lines, and a dry-run plan). Say "Do A" to proceed with that, or say "Do C" to open a minimal infra hardening PR instead.
