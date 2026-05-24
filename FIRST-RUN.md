# FIRST-RUN — Minimal, safe onboarding

Prereqs

- Docker Engine & Docker Compose v2.
- `DATA_ROOT` mounted and writable (default: /home/a-p-maita/homelab-data).
- `DOMAIN` DNS pointed (for Cloudflare Tunnel / Traefik routing).

Quick checklist

1. Copy example and (optionally) generate secrets

```bash
cp .env.example .env
# edit .env: set DATA_ROOT, DOMAIN, PUBLIC_HOSTNAME_BASE
./scripts/generate-secrets.sh   # conservative: will NOT overwrite existing .env
```

1. Bring up infra (proxy, auth, tunnel)

```bash
docker compose -f stacks/infrastructure/compose.yaml config --quiet
docker compose -f stacks/infrastructure/compose.yaml up -d
```

1. Authelia onboarding

- Visit <https://auth.${DOMAIN}> (or the hostname you set) and complete initial user setup and 2FA.

1. Bring up data-backed services in order (cloud → services → media → arr → home)

```bash
docker compose -f stacks/cloud/compose.yaml up -d
docker compose -f stacks/services/compose.yaml up -d
docker compose -f stacks/media/compose.yaml up -d
docker compose -f stacks/arr/compose.yaml up -d
docker compose -f stacks/home/compose.yaml up -d
```

1. Verify health & monitoring

- `docker compose ps`, `docker logs <service>`, check UptimeKuma / Homepage.

1. Backups & safety

- Take a Restic snapshot or simple rsync of `${DATA_ROOT}` to an external drive before any destructive change.

1. Hardening & pinning

- Run `python3 scripts/harden_compose.py --output backups/compose-hardening-suggestions.txt` and review `backups/hardening-snippets/`.
- Pin images and add healthchecks before trusting auto-updates.

Rollbacks

```bash
# restore .env
cp backups/.env.bak.<timestamp> .env
# bring infra down and up
docker compose -f stacks/infrastructure/compose.yaml down && docker compose -f stacks/infrastructure/compose.yaml up -d
```

Notes

- Do NOT commit `.env` or any rendered secret files. Keep `infisical-mapping.json` tracked (it contains no secret values).
- For secret rotation and live changes, follow the migration templates in `backups/` and get explicit approval before running destructive steps.
