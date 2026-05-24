FIRST RUN (Minimal-Interaction) — Homelab
========================================

Goal: make the homelab usable after a single copy of `.env` and a couple of commands. This document assumes a single laptop with a 1TB SSD (no cloud backups, no RAID).

Prerequisites

- A Linux host with Docker and Docker Compose (v2) installed.
- The repo cloned at `~/homelab-config` and the machine has the 1TB SSD mounted for `DATA_ROOT`.
- Optional: Tailscale installed for private access, or Cloudflare account for Tunnel.

Quick checklist (one-liners)

```bash
# 1) Copy template and make sure DATA_ROOT points to your 1TB SSD
cp .env.example .env
# Edit .env: set DATA_ROOT, TUNNEL_TOKEN, PUID, PGID, and PUBLIC_DOMAIN/DOMAIN if used
# 2) Generate secrets (safe to re-run)
./scripts/generate-secrets.sh
# 3) Start infra (proxy, auth, homepage)
make infra-up
# 4) Wait for Authelia onboarding (open auth.<your-domain>), finish device trust
# 5) Start remaining stacks
make all-up
# 6) (Optional) Run an initial backup (host-based restic script)
#    Ensure RESTIC_* vars are set in .env first if you use Restic locally
make backup
```

Where to put IPs and domain names (central, single-change approach)

- Use `./.env` as the single source of truth for host-level variables (DATA_ROOT, PUID/PGID, TUNNEL_TOKEN, and any domain or IP overrides).
- Recommended keys to add or set in `.env`:
  - `DOMAIN=andreasmaita.com` (base public domain)
  - `TAILSCALE_IP=100.106.40.5` (tailscale-controlled IP; optional)
  - `PUBLIC_HOSTNAME_BASE=homepage` (optional shorthand)

How this works in practice

- Compose files use `${VAR}` expansion at deploy time. If you want `nextcloud.${DOMAIN}` everywhere, update Compose labels and envs to use `nextcloud.${DOMAIN}` instead of hard-coded hostnames. That change centralizes hostnames to `.env`.
- To change a single hostname or IP at runtime:
  1. Edit `.env` (or run `make set-domain DOMAIN=your.new.domain` / `make set-ip TAILSCALE_IP=X.Y.Z.W`).
  2. Run `make homepage-sync` to restart the homepage container and pick up any changed links.
  3. Run `make infra-up` to apply proxy/auth-related changes.

Caveats & recommendation

- Centralizing names in `.env` is convenient for a single-host homelab and is acceptable here.
- Downsides: many Compose files must reference `${DOMAIN}` or `${TAILSCALE_IP}` to benefit from one-line changes — if they contain literal hostnames, you must replace them. This is a one-time repo edit and is recommended for portability.
- Prefer DNS names (MagicDNS for Tailscale or Cloudflare DNS) over hardcoded IPs. IPs can change (e.g., Tailscale nodes re-register), while DNS names remain stable.

Why not a single global "IP replace" script?

- It is possible to write a script that finds and replaces hostnames across files, but that risks breaking hand-edited lines. The safer approach is to update compose files once to use `${DOMAIN}` and then maintain `.env` as the single control point.

Authelia onboarding notes

- When you first visit Authelia, use an email you control for the initial admin user.
- Complete device trust on the browser you will use to manage the homelab to avoid 401 loops.

Hardware constraints & backup note

- This setup assumes a single laptop with a 1TB SSD. Backups should be to an external drive or network share attached to this laptop (no cloud backups in this plan unless you later add them).
- Use the included `scripts/backup.sh` which uses Restic and supports S3/B2 if you later change your mind; otherwise adapt it to `rsync` to an external disk.

Troubleshooting quick commands

```bash
# View infra logs
docker compose --env-file .env -f stacks/infrastructure/compose.yaml logs -f
# Check Authelia logs
docker logs -f authelia
# Check Traefik dashboard (if enabled by labels)
# Restart homepage after editing config
make homepage-sync
```

If you'd like, I can:

- Add a short script to automatically convert literal hostnames in compose files to `${DOMAIN}` (dry-run first).
- Perform that conversion for the critical infra services (Traefik, Nextcloud, Immich, Forgejo) now.

Purge to Minimal Repo (safe, manual)
-----------------------------------

If you want to reduce `~/homelab-config` to only the minimal files (`.env`, `.env.example`, `.gitignore`, `plan.md`, `README.md`) while preserving your media at `~/data/media`, follow these manual, safe steps. This will NOT be executed automatically — you must run the commands yourself.

1) Stop running containers (recommended):

```bash
# From the repo root — stops and removes containers started by the repository
./scripts/down-all.sh || docker compose down --remove-orphans || true
```

1) Verify your media backup exists (you said it's at `~/data/media`):

```bash
ls -la ~/data/media
# Optional: create a compressed snapshot (safe, stored in backups/ and ignored by git)
make backup-media
```

1) Create a minimal snapshot of config files (stored in `backups/`):

```bash
make snapshot-minimal
ls backups | tail -n 5
```

1) Dry-run the purge to see what would be removed:

```bash
make prune-repo
```

1) If the dry-run looks correct, execute the purge (RECOMMENDED: ensure `backups/` contains the snapshots):

```bash
# This will remove all top-level files/dirs in the repo except .git, .env, .env.example, .gitignore, plan.md, README.md, and backups/
make prune-repo CONFIRM=YES
```

1) Optional: if you want a truly fresh repository with no git history, remove `.git` after verifying the minimal snapshot:

```bash
# Only run if you're certain
rm -rf .git
git init
git add .
git commit -m "Initial minimal homelab-config"
```

Notes & safety

- The `make prune-repo` target performs a conservative dry-run by default; you must provide `CONFIRM=YES` to execute deletion.
- The `backups/` folder is preserved and listed in `.gitignore` so snapshots are not committed.
- If you later want to restore the full repo, extract the tar in `backups/minimal-YYYY-MM-DD.tar.gz` or the media tarball.

If you'd like, I can run the dry-run for you now and show the list of files that would be removed (I will not delete anything). Say "dry-run" and I'll run `make prune-repo` and show the output.
