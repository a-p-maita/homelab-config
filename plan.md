# Homelab Rebuild & Secure Deployment Plan

## Goals

- **Reproducible, minimal-interaction homelab**: All infra and apps deployed via Docker Compose, with secrets and config in `.env`/Cloudflare, and no manual terminal steps after initial setup.
- **Secure public access**: All public domains routed via Cloudflare Tunnel and protected by Authelia (2FA, device trust, SSO).
- **Portability**: Stack must run on any modern Linux (Debian, Arch, Ubuntu, etc.) with only Docker and Docker Compose required.
- **Data safety**: Only `/data` (media, documents, persistent app data) is critical; everything else is disposable and can be rebuilt.
- **Simplicity**: Avoid unnecessary complexity (e.g., Caddy if not needed, minimal custom scripts, no hand-edited configs).

---

## Assumptions & Host Constraints

- Single-host laptop: Ryzen 5 5500U, ~14GB RAM, ~1TB SSD (no RAID). These constraints drive low-memory, single-node choices.
- No cloud backups or managed K8s — all backups are local (Restic to an attached disk or external NAS you control).
- Persistent app data lives under `DATA_ROOT` (default: /home/a-p-maita/homelab-data) and must be preserved during any repo purge.
- The user prefers minimal interaction: Traefik + Authelia + Cloudflare Tunnel (no public host port exposure), and secrets managed in a secrets manager where practical.

## Files created during analysis & scaffolding

- `scripts/analyze_env.py` — env analyzer (detects duplicates, reused secrets, and generates `.env.optimized.example`).
- `evals/env-evals.json` — simple eval cases for the analyzer.
- `.env.optimized.example` — draft optimized example (secrets blanked).
- `backups/env-analysis-report.txt` — masked analysis report (sensitive values hashed).
- `backups/env-dedupe-plan.md` — step-by-step dedupe & migration plan.
- `scripts/prepare_env_migration.sh` — non-destructive scaffold to back up `.env` and generate migration command templates.

## 1. Architecture Overview

- **Reverse Proxy**: Use Traefik (recommended) for automatic HTTPS, routing, and integration with Authelia.
- **Authentication**: Authelia for all public-facing services, with device trust and 2FA. Use an email you control for onboarding.
- **Cloudflare Tunnel**: All public domains proxied via Cloudflare Tunnel (no direct port exposure).
- **Service Discovery**: Docker Compose labels for proxy and homepage dashboard.
- **Data**: All persistent data in `/data` (bind mount or named volume), gitignored.
- **Secrets**: All secrets auto-generated or managed in `.env` (never in Compose files).

---

## 2. Reverse Proxy & Auth Options

### Option A: Traefik + Authelia (Recommended)

- **Why**: Most widely used, best-documented for Cloudflare + Authelia, and supports Docker label-based config.
- **Pattern**: [Cloudflare Tunnel] → [Traefik] → [Authelia] → [Service]
- **Benefits**:
  - Native Docker integration (labels)
  - Dynamic config, easy to add/remove services
  - Well-supported Authelia middleware
  - Many community examples
- **References**:

## Mailserver & SMTP (self-hosted)

Recommendations:

- For production-grade self-hosted email, deploy `docker-mailserver` or
  `Mailu` (both are full-featured and actively maintained). This repo includes
  a minimal scaffold at `stacks/mail/compose.yaml` and helpers under
  `scripts/mail/` to generate DKIM keys.
- For testing or initial onboarding, keep Authelia's notifier startup checks
  disabled until SMTP is configured (`notifier.disable_startup_check: true`).

Steps:

1. Copy `backups/secrets/mailserver.env.example` → `backups/secrets/mailserver.env` and set `MAIL_DOMAIN` and `POSTMASTER_ADDRESS`.
2. Run `./scripts/mail/generate_dkim_keys.sh mail ${MAIL_DOMAIN}` and publish the printed TXT record to your DNS provider.
3. Start the mailserver: `docker compose -f stacks/mail/compose.yaml up -d`.
4. Create mail accounts per docker-mailserver docs and move any SMTP passwords into Docker secrets.

Notes:

- Sending mail directly from a home IP may be blocked or result in poor deliverability. Consider using an outbound relay (VPS or provider) if you need mail to reach arbitrary public inboxes.
- Keep private keys and passwords in `backups/secrets/` and out of git.

  - [Reddit: Cloudflare + Traefik + Authelia](https://www.reddit.com/r/selfhosted/comments/1pb819m/took_my_selfhosted_homelab_public_cloudflare/)
  - [Reddit: Traefik 401 instead of redirect](https://www.reddit.com/r/docker/comments/16tpdh8/traefic_giving_401_instead_of_redirecting_to/)

### Note: Caddy

Caddy is a capable reverse proxy and provides a simple configuration model and automatic HTTPS. For this homelab's minimal-interaction, reproducible approach we recommend Traefik because of its richer Docker label integration and broader Authelia community support. If you prefer Caddy for simplicity, test Authelia workflows thoroughly before committing it as the default.

### Option C: Nginx Proxy Manager (NPM) + Authelia

- **Why**: Easiest UI, but less flexible for advanced setups and less popular for Authelia SSO.

---

## 3. Device Trust & Onboarding

- **Authelia 401/Device Trust Issues**:
  - 401 Unauthorized is often due to device trust not being established (no valid email, onboarding not completed, or cookies blocked).
  - Use a real, working email for the first admin user (e.g., a ProtonMail or Gmail address you control).
  - If you lose device trust, you can reset Authelia by deleting the DB and re-onboarding.
  - See [Authelia onboarding best practices](https://www.authelia.com/integration/guides/securing-apps-with-basic-auth/).

---

## 4. Minimal Terminal Access

- **All config in Compose, .env, and homepage dashboard.**
- **No manual config edits after initial setup.**
- **All secrets auto-generated by script or on first run.**
- **All service onboarding (admin user, device trust) via web UI.**
- **Backups**: Only `/data` is backed up (media, documents, DBs).

---

## 5. Reproducibility & Portability

- **All stacks defined in Compose YAML, with .env for secrets/ports.**
- **No host-specific config (except DATA_ROOT).**
- **Restore by copying /data and .env to a new host and running `docker compose up -d` for all stacks.**
- **Cloudflare Tunnel token and DNS managed in Cloudflare dashboard.**

---

## 6. Migration/Remake Steps

Optimized minimal migration steps (single-host, safe, reversible):

1. **Snapshot & backup** — create a timestamped backup of `.env` and a Restic snapshot of `DATA_ROOT` (or `rsync` to an external disk).

2. **Analyze & plan** — run `scripts/analyze_env.py` and review `backups/env-analysis-report.txt`; run `bash scripts/prepare_env_migration.sh` to produce `backups/env-migration-commands.sh` (review before executing).

3. **Prepare minimal bootstrap `.env`** — keep only host-level values in tracked `.env.example` (`DATA_ROOT`, `DOMAIN`, `TUNNEL_TOKEN`, `PUID/PGID`, `USE_VPN`). Use `.env.optimized.example` as a reference. For secrets choose one of two flows:

- Quick flow: run `./scripts/generate-secrets.sh` (creates a local `.env` with generated secrets). Use this for fast provisioning but rotate shared passwords later.
- Managed flow (recommended): use a secrets manager (Infisical preferred for small homelabs) and render secrets at deploy time to `.env.rendered` or create Docker secrets from the rendered output.

1. **Bring up infra only**

```bash
docker compose -f stacks/infrastructure/compose.yaml config && \
  docker compose -f stacks/infrastructure/compose.yaml up -d
```

Start Traefik, Cloudflared, Authelia, homepage, and monitoring first. Complete Authelia onboarding with a real email and verify device trust before exposing other services.

1. **Migrate per-service secrets & rotate reused passwords**

- Review `backups/env-analysis-report.txt` and `backups/env-migration-commands.sh` for grouped reused values. For each reuse-group do a manual, service-aware rotation:

  1) Generate a new secret locally (example):

  ```bash
  openssl rand -base64 32
  # or: python3 -c "import secrets; print(secrets.token_urlsafe(32))"
  ```

  1) Preferred: create a Docker secret and update Compose to `_FILE` semantics:

  ```bash
  echo -n "<NEWSECRET>" | docker secret create paperless_db_pass -
  # then update compose: PAPERLESS_DB_PASS_FILE=/run/secrets/paperless_db_pass
  ```

  1) Quick (not recommended long-term): update `.env` in-place and restart the affected service(s):

  ```bash
  sed -i "s|^PAPERLESS_DB_PASS=.*|PAPERLESS_DB_PASS='<NEWSECRET>'|" .env
  docker compose -f stacks/services/compose.yaml up -d paperless
  ```

Notes:

- Do NOT run mass `sed` replacements blind — review each service's migration requirements (some apps need an in-app password change step or DB credentials re-provisioning).
- Keep a mapping of old→new for critical rotations in `backups/env-rotate-log.txt` (store only hashes, not cleartext).

1. **Bring up application stacks & verify**

```bash
docker compose -f stacks/media/compose.yaml up -d
docker compose -f stacks/services/compose.yaml up -d
```

Verify healthchecks (`docker compose ps`, `docker logs <service>`). Confirm monitoring (Uptime Kuma, Prometheus/Grafana) reports services healthy. Run a sample restore from the backups to validate the backup pipeline.

1. **Finalize (pinning, hardening, automation controls)**

- Pin images for critical services (Traefik, Authelia, DBs, Nextcloud) to semver tags or digests. Avoid `:latest`.
- Add `healthcheck` and resource limits to key Compose services. Add Watchtower opt-in labels and exclude stateful services from auto-update.
- Remove or archive unnecessary `scripts/` that replicate Compose behavior; keep only small, well-scoped helpers (`generate-secrets.sh`, `backup.sh`).

Rollback & safety commands (quick reference):

```bash
# restore .env from backup
cp backups/.env.bak.<timestamp> .env

# restart infra
docker compose -f stacks/infrastructure/compose.yaml down && \
  docker compose -f stacks/infrastructure/compose.yaml up -d

# restic restore (example)
# restic -r /mnt/backup/restic-repo restore latest --target /restore/target
```

---

## 7. Hardening pass (Compose hygiene)

- Detect `:latest` usage and list candidates for pinning:

```bash
grep -R "image:.*:latest\|image: .*:latest" -n stacks/ || true
```

- Pin images to tags or digests. Example workflow to capture digest:

```bash
docker pull traefik:2.10
docker inspect --format='{{index .RepoDigests 0}}' traefik:2.10
# set image: traefik@sha256:<digest> in compose file
```

- Add `healthcheck` blocks and basic `deploy.resources` (or `mem_limit`/`cpus` for compatibility) to critical services.
- Ensure DBs and caches are on internal networks only; do not publish DB ports publicly.
- Add `read_only: true` and `no-new-privileges: true` where supported for infra containers.
- Configure Watchtower labels as opt-in; do not enable auto-update for stateful services.

## 8. Secrets migration & Infisical bootstrap (recommended flow)

1. Create `infisical-mapping.json` mapping `.env` keys to Infisical secret names (example below). This file is tracked and contains only key names, not secret values.

```json
{
  "PAPERLESS_DB_PASS": "paperless/db/password",
  "NEXTCLOUD_DB_PASSWORD": "nextcloud/db/password",
  "AUTHELIA_JWT_SECRET": "authelia/jwt"
}
```

1. User flow (Infisical):

- Admin: `infisical login` (manual, secure)
- Push secrets once: `infisical push --path infisical-mapping.json --values-from .env.rendered`
- Render at deploy time:

```bash
infisical render --project homelab --output .env.rendered
# or: infisical render --project homelab --to /run/secrets/...
```

1. Create Docker secrets from rendered values when you prefer runtime secrets:

```bash
echo -n "$(grep '^PAPERLESS_DB_PASS=' .env.rendered | cut -d'=' -f2-)" | docker secret create paperless_db_pass -
```

Notes:

- Keep `infisical-mapping.json` tracked, but never commit `.env.rendered` or any secret-bearing files.
- The Infisical approach centralizes secrets and allows team-friendly rotation. It is the recommended path for minimal manual steps during deploy.

## 9. Validation & Testing Checklist

- Validate each compose file after edits:

```bash
docker compose -f stacks/infrastructure/compose.yaml config --quiet
docker compose -f stacks/services/compose.yaml config --quiet
```

- Verify running containers and health:

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
docker compose ps
```

- Confirm monitoring alerts are green (Uptime Kuma), and run a sample backup+restore of a small dataset from `DATA_ROOT`.
- Check Authelia onboarding and device trust operations (sign in, 2FA, device trust cookie). If 401 occurs, consult Authelia DB and web console.

## 10. Next recommended actionable steps (what I can do now)

Status: `FIRST-RUN.md` and `Makefile` have been added to the repo (see [FIRST-RUN.md](FIRST-RUN.md) and [Makefile](Makefile)). With those in place, the next safe actions are listed below.

Pick one and I will prepare the artifacts (I will not execute destructive commands without your explicit approval):

- A) Produce concrete, non-executing migration commands for each reuse-group (exact `docker secret create` examples, `_FILE` Compose snippets, and a dry-run plan). Good first step for manual review.
- B) Scaffold or review `infisical-mapping.json` and `README-INFISICAL.md` with exact `infisical` CLI commands to push/render secrets (no secret values will be stored in the repo).
- C) Draft a minimal hardening PR for infra compose files (pin Traefik/Authelia images to tags/digests, add `healthcheck` and basic resource limits, and opt-in Watchtower labels). Non-destructive; ready for review.
- D) Run compose validation (dry-run) for each stack and report problems (`docker compose -f <stack> config --quiet`). Requires Docker on this host — I will only run this if you confirm the environment is available.
- E) Run the hardening scanner and produce `backups/compose-hardening-suggestions.txt` and `backups/hardening-snippets/` for review.
- F) Produce `backups/env-rotate-log.txt` (migration ledger with old key → new secret-name hashes only) to plan an orderly rotation; no plaintext secrets stored.

Tell me which option to execute next and I'll prepare the artifacts or run the safe checks. I will not perform any secret rotations or destructive operations without `CONFIRM=YES` from you
---

## Appendix: Useful commands (copyable)

```bash
# Backup .env
cp .env backups/.env.bak.$(date +%F_%H%M%S)

# Run analyzer & regen migration templates
python3 scripts/analyze_env.py
bash scripts/prepare_env_migration.sh

# Validate compose files
docker compose -f stacks/infrastructure/compose.yaml config

# Create a Docker secret (example)
echo -n "<NEWSECRET>" | docker secret create my_service_db_pass -
```

Files created by the analyzer/migration scaffold:

- `backups/env-analysis-report.txt` (masked analysis)
- `backups/env-migration-commands.sh` (templates)
- `.env.optimized.example` (optimized example)
- `scripts/analyze_env.py`, `scripts/prepare_env_migration.sh`

---

If you'd like, I can now (choose one):

1) Produce concrete, reviewed non-executing command templates for each reuse-group (option A above).
2) Scaffold `infisical-mapping.json` + `README-INFISICAL.md` (option B).
3) Open a PR with a minimal hardening patch for infra compose files (option C).

Tell me which option, and I'll prepare the artifacts (I will not run any secret-rotation commands without explicit confirmation).

---

## 7. Recommendations from Community & Best Practices

- **Traefik + Authelia is the most common and best-documented for Cloudflare Tunnel setups.**
- **Caddy is simpler but can be trickier with Authelia (401 issues, plugin builds).**
- **Nginx Proxy Manager is easiest for beginners but less flexible for advanced SSO.**
- **Always use a real email for Authelia onboarding.**
- **Keep all persistent data in `/data` and back it up regularly.**
- **Use Docker labels for all routing and authentication config.**
- **Minimize custom scripts; prefer Compose labels and homepage dashboard for management.**

---

## 8. Service Inventory & Declarative Config

### 8.1 Service Inventory (Current Stack)

**Infrastructure & Routing**

- Cloudflared (Cloudflare Tunnel)
- Traefik or Caddy (reverse proxy)
- Authelia (2FA, SSO, device trust)
- Homepage (dashboard)
- Uptime Kuma (monitoring)
- Watchtower (image update notifications)
- Docker Socket Proxy (for secure label-based discovery)
- Dockge (stack manager, Tailscale-only)

**Media & Downloads**

- Audiobookshelf, Yamtrack, Navidrome, Feishin, Crosswatch, Komga, Calibre-Web, qBittorrent, Jackett, Lidarr, Radarr, Sonarr, Prowlarr, Bazarr, Wizarr, Autobrr, etc.

**Cloud & Productivity**

- Nextcloud, Immich, Paperless-NGX, Joplin, Vaultwarden, Actual Budget, Mealie, Draw.io, Excalidraw, IT-Tools, Forgejo, Monica

**Monitoring & Tools**

- Scrutiny

---

### 8.2 Declarative .env and .env.example

**.env (example, redact secrets for sharing):**

```env
TZ=Europe/London
DATA_ROOT=/home/youruser/homelab-data
TUNNEL_TOKEN=your_cloudflare_tunnel_token
CLOUDFLARED_PORT=20280
PUID=1000
PGID=1000
QBITTORRENT_WEBUI_USER=youruser
QBITTORRENT_WEBUI_PASS=yourpass
# ...all other service ports, API keys, and secrets...
```

**.env.example** should mirror `.env` with placeholders and comments for each value. Example:

```env
# .env.example
TZ=Europe/London
DATA_ROOT=/home/youruser/homelab-data
TUNNEL_TOKEN=your_cloudflare_tunnel_token
# ...
```

---

### 8.3 Compose & Config Management Best Practices (2025–2026)

- **Single repo, multiple compose files**: One repo, one `.env`, one `/data` directory, Compose files per stack (infra, media, cloud, services).
- **No custom scripts/templates**: Use only Compose, `.env`, and official images. Remove `scripts/` and `config/` templates unless absolutely necessary for a specific app.
- **Secrets**: Use `.env` for secrets (or Docker secrets for advanced setups, but `.env` is standard for selfhosters).
- **Homepage**: `gethomepage/homepage` is the most popular dashboard (r/selfhosted, 2025–2026). Use Docker labels for service discovery.
- **Backups**: Only `/data` and `.env` need to be backed up. Restore by `git clone`, copy `/data` and `.env`, then `docker compose up -d`.
- **Automation**: For CI/CD, consider Gitea/Forgejo Actions or GitHub Actions for auto-deploy, but manual `docker compose pull && up -d` is most common.

---

### 8.4 Community-Recommended Patterns (r/selfhosted, r/homelab, 2025–2026)

- **Reverse Proxy**: Traefik + Authelia + Cloudflare Tunnel is the most robust and documented. Caddy is simpler but less flexible for advanced auth.
- **Secrets**: `.env` is standard; Infisical or Vaultwarden for advanced needs.
- **Config**: All Compose and config files in git, `/data` for persistent app data.
- **No custom scripts**: Compose and Docker labels are sufficient for 99% of use cases.
- **Backups**: Only `/data` and `.env` are critical. Use Restic, Borg, or simple rsync.

---

### 8.5 Example Minimal Compose Stack (Infra)

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    environment:
      - TUNNEL_TOKEN=${TUNNEL_TOKEN}
    restart: unless-stopped
    networks: [proxy_net]
  traefik:
    image: traefik:latest
    command:
      - --providers.docker
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.cloudflare.acme.dnschallenge=true
      - --certificatesresolvers.cloudflare.acme.email=${CLOUDFLARE_EMAIL}
      - --certificatesresolvers.cloudflare.acme.storage=/letsencrypt/acme.json
    environment:
      - CF_DNS_API_TOKEN=${CF_API_TOKEN}
    ports:
      - 80:80
      - 443:443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    networks: [proxy_net]
  authelia:
    image: authelia/authelia:latest
    # ...env and volumes...
    networks: [proxy_net]
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    # ...env and volumes...
    networks: [proxy_net]
networks:
  proxy_net:
    external: true
```

---

### 8.6 Migration/Restore

- Backup `/data` and `.env`
- On new host: `git clone`, copy `/data` and `.env`, `docker compose up -d`
- All onboarding via web UI (Authelia, Nextcloud, etc.)

---

### 8.7 Remove/Replace

- **Remove**: All custom `scripts/` and `config/` templates unless required for a specific app.
- **Replace**: Use Compose labels, `.env`, and `/data` for all config and secrets.

---

### 8.8 References (2025–2026, r/selfhosted/r/homelab)

- [Awesome Docker Compose Examples (r/selfhosted)](https://www.reddit.com/r/selfhosted/comments/196gr2i/awesome_docker_compose_examples/)
- [Best Practice: Compose, .env, /data, no scripts (r/homelab)](https://www.reddit.com/r/homelab/comments/1fqny79/best_practices_for_a_docker_host_with_many/)
- [Homepage Dashboard (r/selfhosted)](https://www.reddit.com/r/selfhosted/comments/1fzsp2m/homepage_the_possibilities_are_endless/)
- [Secrets Management (r/selfhosted)](https://www.reddit.com/r/selfhosted/comments/165k242/docker_compose_how_do_you_manage_your_secrets/)
- [Backup/Restore (r/homelab)](https://www.reddit.com/r/homelab/comments/1q9hmfz/whats_the_best_way_to_backup_docker_containers/)

---

---

## 9. References

- [Reddit: Cloudflare + Traefik + Authelia](https://www.reddit.com/r/selfhosted/comments/1pb819m/took_my_selfhosted_homelab_public_cloudflare/)
- [Reddit: Traefik 401 instead of redirect](https://www.reddit.com/r/docker/comments/16tpdh8/traefic_giving_401_instead_of_redirecting_to/)
- [Authelia: Securing Apps with Basic Auth](https://www.authelia.com/integration/guides/securing-apps-with-basic-auth/)
- [Reddit: Caddy + Authelia 401 issues](https://www.reddit.com/r/selfhosted/comments/1ixnxlm/caddy_291_authelia_43819_401_unauthorized_for_all/)
- [Reddit: A better reverse proxy poll](https://www.reddit.com/r/selfhosted/comments/1respx4/a_better_reverse_proxy_poll/)
- [Reddit: Best reverse proxy approach](https://www.reddit.com/r/selfhosted/comments/14mcgz9/best_reverse_proxy_approach_cloudflare_tailscale/)
- [Reddit: Is someone using cloudflare instead of a traefik/caddy+SSO](https://www.reddit.com/r/selfhosted/comments/1nyvan5/is_someone_using_cloudflare_instead_of_a/)

---

## 10. Final Notes

- If you want the absolute minimum complexity and are comfortable with some manual config, Caddy is fine.
- For best support, flexibility, and future-proofing, Traefik + Authelia is recommended.
- Nginx Proxy Manager is a good fallback if you want a UI and don't need advanced SSO.
- Always test onboarding and device trust with a real email before exposing services.
- Document your `/data` structure and keep `.env` and Cloudflare credentials safe.

## 11. Hardware Constraints (Single-host)

- This plan targets a single laptop with a 1TB SSD as the only storage device. It intentionally avoids recommendations for cloud backups, multi-disk RAID, or network-attached storage (NAS).
- Backups should be local (external USB drive) or to a network share you control; use `scripts/backup.sh` (Restic) pointed at a local or directly attached repository. If you later add a secondary device, the plan can be extended.

---

## 11. Changelog (PR-style summary)

- Enumerated all current services by stack (infra, media, cloud, productivity, monitoring)
- Added declarative `.env` and `.env.example` guidance for easy setup and sharing
- Documented Compose/config/secrets/automation best practices (2025–2026, r/selfhosted/r/homelab consensus)
- Explicitly recommend removing custom scripts/templates in favor of Compose, `.env`, and `/data`
- Added references to top-rated Reddit threads and community guides

---

## 12. Verified Repositories & Container Images

Below are verified GitHub repositories and the container images used in this repo. I validated core infra and common apps against the Compose files; images are taken from `stacks/*/compose*.yaml`. Pin stable tags where noted.

### Infrastructure (verified)

- Cloudflared: <https://github.com/cloudflare/cloudflared> — image: `cloudflare/cloudflared:latest`
- Traefik: <https://github.com/traefik/traefik> — image: `traefik:latest`
- Caddy (optional): <https://github.com/caddyserver/caddy> — image: `caddy:latest` (or `lucaslorentz/caddy-docker-proxy:ci-alpine` for Docker label integration)
- Authelia: <https://github.com/authelia/authelia> — image: `authelia/authelia:latest`
- Homepage: <https://github.com/gethomepage/homepage> — image: `ghcr.io/gethomepage/homepage:latest`
- Uptime Kuma: <https://github.com/louislam/uptime-kuma> — image: `louislam/uptime-kuma:1`
- Watchtower: <https://github.com/containrrr/watchtower> — image: `containrrr/watchtower:latest` (exclude critical services)
- Docker Socket Proxy (tecnativa): <https://github.com/tecnativa/docker-socket-proxy> — image: `ghcr.io/tecnativa/docker-socket-proxy:latest`
- Dockge (stack manager): <https://github.com/louislam/dockge> — image: `louislam/dockge:1`

### Selected Media & App images (representative, verify others similarly)

- Audiobookshelf: <https://github.com/advplyr/audiobookshelf> — image: `ghcr.io/advplyr/audiobookshelf:latest`
- Yamtrack: <https://github.com/fuzzygrim/yamtrack> — image: `ghcr.io/fuzzygrim/yamtrack`
- Navidrome: <https://github.com/deluan/navidrome> — image: `deluan/navidrome:latest`
- Komga: <https://github.com/gotson/komga> — image: `gotson/komga:latest`
- Calibre-Web (LinuxServer): <https://github.com/linuxserver/docker-calibre-web> — image: `lscr.io/linuxserver/calibre-web:latest`
- qBittorrent (LinuxServer): <https://github.com/linuxserver/docker-qbittorrent> — image: `lscr.io/linuxserver/qbittorrent:latest`
- Jackett (LinuxServer): <https://github.com/linuxserver/docker-jackett> — image: `lscr.io/linuxserver/jackett:latest`
- Sonarr/Radarr/Lidarr/Prowlarr (LinuxServer): <https://github.com/linuxserver> — images: `lscr.io/linuxserver/sonarr`, `.../radarr`, `.../lidarr`, `.../prowlarr` (pin tags)
- Autobrr: <https://github.com/autobrr/autobrr> — image: `ghcr.io/autobrr/autobrr:latest`
- Immich: <https://github.com/immich-app/immich> — image: `ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}`
- Nextcloud: <https://github.com/nextcloud/server> — image: `nextcloud:stable-apache`
- Jellyfin: <https://github.com/jellyfin/jellyfin> — image: `jellyfin/jellyfin:latest`
- Paperless-NGX: <https://github.com/paperless-ngx/paperless-ngx> — image: `ghcr.io/paperless-ngx/paperless-ngx:latest`

### Monitoring & Tools

- Prometheus/Grafana: official repos and images (pin versions)
- Scrutiny (SMART): <https://github.com/AnalogJ/scrutiny> — image: `analogj/scrutiny`

### Notes & Verification

- I sourced image names from `stacks/*/compose*.yaml` in this repo. Core infra images above are verified against upstream repos. Some lesser-used or community images (e.g., `corentinth/it-tools`, `wizarrrr`, `profilarr`, `santiagosayshey/*`) are present in Compose files — I linked them to their DockerHub/GitHub if obvious; otherwise mark them below for manual verification.
- Action item: pin each image to a stable tag (not `:latest`) before production. Replace ambiguous images with official upstream images where possible.

---

## 13. Fixes, Best-Practice Changes, and How to Apply Them

- Prefer Traefik v2.x with Docker provider + Cloudflare DNS ACME and Authelia middleware. Example Traefik resolver config uses Cloudflare DNS API token (least privilege) and `--providers.docker` flags.
- Pin image tags to release versions or digest (`image: traefik:2.10.3` or `image: traefik@sha256:...`) for reproducibility.
- Move high-sensitivity secrets (DB passwords, tokens) from `.env` into Docker secrets or use a secrets manager (HashiCorp Vault, Infisical, Passbolt, or GitHub Secrets for CI).
- Add `healthcheck` and `deploy.resources` CPU/memory limits for each critical service. Use `depends_on` with `condition: service_healthy` where ordering matters.
- Use internal-only networks for DB and backend services (e.g., `backend: internal: true`) to prevent accidental exposure.
- Exclude critical services (Authelia, Cloudflared, Traefik, DBs) from auto-updates by Watchtower. Configure Watchtower with `--label-enable` and opt-in labels.
- Avoid duplicating passwords across services. Run `scripts/generate-secrets.sh` once and rotate; prefer generating secrets with `openssl rand -hex 32` and store in secrets manager.
- Replace `scripts/` heavy orchestration with `docker compose` workflows and a `Makefile` for common ops (pull, up, backup, restore). Keep `scripts/generate-secrets.sh` but limit its scope to non-sensitive defaults.
- For Nextcloud, set `OVERWRITEPROTOCOL`, `OVERWRITEHOST` and `trusted_domains` properly before first run and pin DB and Redis passwords; document `occ` commands to change values if necessary.
- Document a restore checklist in `FIRST-RUN.md` and `README.md`: restore `/data`, restore `.env` or secrets`, run`docker compose up -d stacks/infrastructure`, then others.

### Quick Commands (examples)

```bash
# Pin and pull all images used in stacks
docker compose -f stacks/infrastructure/compose.yaml pull
docker compose -f stacks/infrastructure/compose.yaml up -d

# Backup data (example using rsync)
rsync -a --delete /home/youruser/homelab-data /mnt/backup/homelab-data
```

---

## 14. Minimal-Interaction, Traefik-first Setup (Recommended)

Goal: the least manual post-install interaction — copy `.env`, run one command, finish a web-based onboarding step, and everything else runs automatically.

Recommended stack and tooling (minimal configuration overhead):

- Reverse proxy & routing: **Traefik v2.x** with Docker provider + Cloudflare DNS ACME (token) — no per-service TLS config; use Docker labels only.
- Public ingress: **cloudflared (Cloudflare Tunnel)** — keeps inbound network closed; Traefik handles routing + certificates.
- Auth: **Authelia** behind Traefik middleware for SSO/2FA (onboard once via web UI).
- Dashboard: **Homepage** for service discovery and quick links.
- Backups: **Backrest** (Restic UI) + Restic → Backblaze B2 (or any S3-compatible) for automated scheduled snapshots.
- Secrets (optional): **Infisical** self-hosted (if you want a central secrets UI/API); otherwise keep a single, gitignored `.env` and `scripts/generate-secrets.sh`.
- Auto-updates (optional): **Watchtower** in opt-in mode; label only non-critical services for auto-update.

Why this is low-effort:

- Traefik + Docker labels mean adding a service requires only 2–3 labels in its Compose entry.
- Cloudflared removes router/NAT/port-forwarding work and keeps your host off the public internet.
- Authelia needs one web onboarding step; thereafter logins are via web flow.
- Backrest provides a web UI for scheduled restic jobs — no CLI fiddling.

Minimal first-run (copy-paste):

```bash
cd /home/youruser/homelab-config
cp .env.example .env
./scripts/generate-secrets.sh   # auto-generate required secrets
# Start infra (proxy, auth, homepage, monitoring)
docker compose -f stacks/infrastructure/compose.yaml up -d
# Wait for Authelia onboarding, then bring up everything else
docker compose -f stacks/media/compose.yaml -f stacks/cloud/compose.yaml -f stacks/services/compose.yaml up -d
```

Low-friction update workflow (safe defaults):

- Pin images in `stacks/*/compose*.yaml` to release tags or digests (avoid `:latest`).
- Run Watchtower in opt-in mode and add `labels: - "com.centurylinklabs.watchtower.enable=true"` only to safe, stateless apps.
- For critical services (Authelia, Traefik, DBs), set `labels: - "com.centurylinklabs.watchtower.enable=false"` to exclude them.

Watchtower opt-in example (in `stacks/infrastructure/compose.yaml`):

```yaml
services:
  watchtower:
    image: containrrr/watchtower:1.7.1
    environment:
      - WATCHTOWER_LABEL_ENABLE=true
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=86400
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

Service label example (opt-in):

```yaml
services:
  some-statsless-app:
    image: ghcr.io/example/app:1.2.3
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  postgres-db:
    image: postgres:16-alpine
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

Backups (recommended minimal setup):

- Deploy `backrest` (Web UI for restic) and add a scheduled job to snapshot `/data` to Backblaze B2. Store `RESTIC_BACKUP_PASSWORD` in `.env` or Infisical.
- Verify snapshot and restore in the Backrest UI once.

Secrets handling (minimal options):

- Easiest: keep a single `.env` (gitignored) generated by `scripts/generate-secrets.sh`. Store backups of `.env` securely off-host.
- Better: self-host **Infisical** (official Docker Compose) and use its CLI to inject secrets into startup flows; small upfront work for central secret rotation.

Automation & GitOps options (if you want zero host logins):

- Use a small CI runner (GitHub Actions, Forgejo/Gitea runner) that SSHs into the host and runs `docker compose pull && docker compose up -d` when you merge to `main`. This removes manual `ssh && docker compose` steps; requires one-time runner setup.
- Simpler: Watchtower opt-in as above (less safe than CI-driven deployments but very low manual work).

References & example repos consulted (minimal-interaction focus):

- Traefik + Authelia + Cloudflare Tunnel examples: community guides and SimpleHomelab tutorials (see `Authelia + Traefik` integration docs).
- Backrest (Restic UI): <https://github.com/garethgeorge/backrest> — makes restic scheduling and restores UI-driven.
- Infisical: <https://github.com/Infisical/infisical> — self-hosted secrets manager with Docker Compose templates.
- DockSTARTer (optional installer): <https://github.com/GhostWriters/DockSTARTer> — opinionated, interactive installer if you want an assisted setup.

If you want, I can now:

1) Replace `Option B: Caddy` with a clear single-line note that Traefik is the recommended default and remove Caddy from infra recommendations, and
2) Create a `Makefile` and `FIRST-RUN.md` with the exact minimal commands above and a safe Watchtower opt-in example.

Tell me which of (1) or (2) to do next, or say both and I'll implement them.

---

## Implementation progress (ongoing)

- Added `scripts/harden_compose.py`: non-destructive scanner that produces
  `backups/compose-hardening-suggestions.txt` and per-file snippets under
  `backups/hardening-snippets/`. The script does not alter any repo files — it
  only emits human-reviewable suggestions.
- Added `README-HARDENING.md` with usage instructions and guidance for
  applying the suggested snippets safely.

Next immediate steps I can perform now (safe, non-destructive):

- Run `python3 scripts/harden_compose.py` to generate the current suggestions
  (read-only) and commit the results to `backups/` for your review.
- Prepare a focused hardening patch (example changes) for the infra stacks
  (Traefik, Authelia, Cloudflared) as a draft branch/PR. I will NOT change any
  running services or rotate secrets without explicit approval.

If you'd like me to run the hardening scan now and add the generated suggestions
to the repo, reply with: "Run hardening scan". To proceed with a draft PR for
infra hardening, reply with: "Prepare infra hardening PR".

### Recent implementation actions

- Scaffolder: Added minimal Compose scaffolds under `stacks/`:
  - `stacks/infrastructure/compose.yaml` (Traefik, Cloudflared, Authelia, Homepage, Uptime Kuma, Watchtower)
  - `stacks/media/compose.yaml` (qBittorrent, Navidrome, Yamtrack)
  - `stacks/services/compose.yaml` (Paperless, Joplin, Vaultwarden)
  - `stacks/cloud/compose.yaml` (Postgres + Nextcloud)
  - `stacks/arr/compose.yaml` (Prowlarr, Radarr, Sonarr)
  - `stacks/home/compose.yaml` (Home Assistant)

- Helper: Added `scripts/generate-secrets.sh` — conservative generator that
  creates `.env` from `.env.example` by populating blank secret-like keys.

These are scaffolds for review. They intentionally use environment variables
from `.env` and include labels and internal `backend`/`proxy_net` networks.
Before bringing stacks up in production, pin images to tags/digests and
populate secrets (use `scripts/generate-secrets.sh` or Infisical).

If you'd like me to proceed, choose one:

- "Run compose validation" — I will run a read-only `docker compose config` check per stack (requires Docker installed on this host).
- "Draft hardening PR" — I will prepare a draft branch with example pinning/healthcheck changes for infra services.
