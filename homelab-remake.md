# Homelab Remake — Agentic Execution Plan

> **[META] AGENT INSTRUCTIONS:**
> This is a strictly ordered, machine-actionable implementation plan.
>
> 1. Execute stage-by-stage. Do not start the next stage until the current stage is verified.
> 2. Validate every change with Docker commands and service health checks.
> 3. Keep the plan simple, deterministic, and explicitly executable by an LLM agent.
> 4. Do not remove `homelab_net` until the new internal network architecture is fully validated.

---

## How to use this plan

- Work in passes: detect current state, apply focused change, then verify.
- Prefer `docker compose config`, `docker ps`, `docker logs`, and `docker exec` for validation.
- Keep changes to one stack or one architectural concern at a time.
- Record progress in the `Live Recovery Status` checklist before moving on.

---

## Stage 0: Emergency Recovery

**Objective:** Stabilize the running stack and remove immediate failures before any refactor.

Steps:

1. Inspect unhealthy containers:

   ```bash
   docker ps --filter 'health=unhealthy' --format 'table {{.Names}} {{.Status}}'
   ```

2. Fix broken mounted configs in-place.
   - Example: repair `config.php` inside the Nextcloud container if PHP syntax is invalid.
3. Restart the affected containers and confirm service health:

   ```bash
   docker restart nextcloud
   docker exec nextcloud curl -sf http://localhost/
   docker exec caddy cat /config/caddy/Caddyfile.autosave | grep -E 'auth\.andreasmaita\.com|nextcloud\.andreasmaita\.com'
   ```

Verification:

- `nextcloud` is `Up` and `healthy`.
- `caddy`, `authelia`, and `cloudflared` are `healthy`.
- The generated `Caddyfile.autosave` contains the expected host blocks.

---

## Stage 1: Bootstrap & Inventory

**Objective:** Capture current state, protect data, and validate environment variables.

Steps:

1. Back up databases:

   ```bash
   ./scripts/backup-dbs.sh
   ls -l /backups
   ```

2. Generate secrets and check for missing manual values:

   ```bash
   ./scripts/generate-secrets.sh
   grep -E 'TUNNEL_TOKEN|PROTONVPN_WIREGUARD_PRIVATE_KEY|VAULTWARDEN_ADMIN_TOKEN' .env
   ```

3. Validate `.env` and data root:

   ```bash
   source .env
   echo "$DATA_ROOT"
   ```

4. Confirm stack directory structure:
   - `stacks/infrastructure`
   - `stacks/monitoring`
   - `stacks/downloads`
   - `stacks/arr`
   - `stacks/media`
   - `stacks/cloud`
   - `stacks/services`
   - `stacks/home`

Verification:

- `.env` loads cleanly.
- backups are present and non-empty.
- stack directories exist and match the intended architecture.

---

## Stage 2: Secure Network & Socket Isolation

**Objective:** Create isolated networks and lock down Docker socket access.

Steps:

1. Ensure these networks exist:
   - `proxy_net`
   - `socket_internal`
   - `infrastructure_internal`
   - `cloud_internal`
   - `services_internal`
   - `downloads_internal`
2. Keep `homelab_net` in place only for discovery during the migration.
3. Configure `stacks/infrastructure/compose.yaml`:
   - `docker-socket-proxy` attached only to `socket_internal`
   - `docker-socket-proxy` must allow `NETWORKS=1` so Caddy can resolve container networks via `{{upstreams}}`
   - `caddy` attached to `socket_internal` and `proxy_net`
   - `DOCKER_HOST=tcp://docker-socket-proxy:2375`
4. Configure `stacks/monitoring/compose.yaml`:
   - `dockge` gets raw `/var/run/docker.sock`
   - bind only to `100.106.40.5:20202`

Verification:

- `docker network ls` shows the expected internal networks.
- `docker exec caddy sh -lc 'wget -qO- http://docker-socket-proxy:2375/_ping'`
- `docker network inspect socket_internal` contains only socket-aware services (homepage, watchtower, docker-socket-proxy, caddy).

---

## Stage 3: Label-Driven Edge Routing

**Objective:** Replace static proxy and homepage config with Docker labels.

Steps:

1. Confirm `caddy` is using `lucaslorentz/caddy-docker-proxy:ci-alpine`.
2. Remove stale Caddy config files/Dockerfile if they exist only for the old static proxy.
3. Add labels to all public-facing services.
4. Recreate or restart the updated service containers so Docker applies the new labels.
5. Ensure services are reachable on both `proxy_net` and their stack-specific internal network.
6. Configure `homepage` to use `docker-socket-proxy` via `config/homepage/docker.yaml`.

Verification:

- `docker inspect <container> --format '{{json .Config.Labels}}'` shows `caddy` and `homepage.*` labels.
- `docker exec caddy cat /config/caddy/Caddyfile.autosave`
- `docker exec caddy sh -lc "grep -E '([a-z0-9.-]+\.)+andreasmaita\.com' /config/caddy/Caddyfile.autosave"`
- `homepage` web UI discovers container metadata.

---

## Stage 4: Database & Cache Initialization

**Objective:** Start databases and caches first, then connect applications to them.

Steps:

1. Start database-only stacks:

   ```bash
   docker compose --env-file .env -f stacks/services/compose.db.yaml up -d
   docker compose --env-file .env -f stacks/cloud/compose.db.yaml up -d
   ```

2. Confirm health checks:
   - `pg_isready` for Postgres
   - `redis-cli ping` for Redis
3. Ensure no DB services publish host ports.

Verification:

- all DB containers are `healthy`
- no database service has host-facing ports
- `docker compose --env-file .env -f stacks/cloud/compose.db.yaml config` passes
- `docker compose --env-file .env -f stacks/services/compose.db.yaml config` passes

---

## Stage 5: Application Deployment

**Objective:** Bring up the service stacks after storage and edge are stable.

Steps:

1. Start `stacks/infrastructure` first.
2. Start `stacks/cloud`, `stacks/services`, `stacks/home`, and `stacks/media`.
3. Verify route availability and auth boundaries.

Verification:

- `nextcloud` loads without reverse proxy warnings
- `immich` is reachable on the domain and Tailscale IP
- `Vaultwarden` and `Joplin` are not behind `forward_auth`

---

## Stage 6: Downloads & VPN Validation

**Objective:** Validate the download pipeline and VPN network namespace.

Steps:

1. Start `stacks/downloads` with `USE_VPN=true` if VPN mode is intended.
2. Verify `qbittorrent` runs in the Gluetun netns.
3. Confirm port forwarding sync:

   ```bash
   docker exec gluetun cat /tmp/gluetun/forwarded_port
   ```

Verification:

- `qbittorrent` sees a VPN public IP
- qBittorrent listens on the forwarded port

---

## Stage 7: Monitoring & Backup Validation

**Objective:** Confirm monitoring and backup automation work end-to-end.

Steps:

1. Start the monitoring stack.
2. Import Uptime Kuma monitor JSON if required.
3. Run a backup validation via Backrest or `scripts/backup.sh` dry-run.

Verification:

- Uptime Kuma reports healthy checks
- backup validation includes Immich, ABS, and Yamtrack data

---

## Stage 8: Post-refactor Audit

**Objective:** Validate the new architecture and retire legacy drift-prone config.

Steps:

1. Migrate static `config/homepage/services.yaml` entries into compose labels when possible.
2. Confirm `config/caddy/Caddyfile` is no longer required.
3. Verify `homelab_net` still functions only as a transition bridge.

Verification:

- no service routes depend on legacy static Caddy config
- homepage widgets come from label discovery
- `docker compose config` passes for all stacks

---

## Live Recovery Status

- [x] Nextcloud `config.php` syntax fixed.
- [x] `docker-socket-proxy` isolation validated; `NETWORKS=1` fixed Caddy upstream discovery.
- [ ] Authelia forward_auth policy verification pending.
- [x] Homepage docker socket discovery validated.
- [x] Label-driven Caddy route discovery validated for services and media containers.
- [ ] Homepage web UI metadata discovery pending.
- [x] Cloud and services DB compose configs validated.

---

## Known plan corrections

1. Do not remove `homelab_net` until the internal network migration is fully validated.
2. Infrastructure must start before application stacks.
3. Fix runtime failures first, then refactor.
4. Treat `docker-socket-proxy` ingress network query errors as non-fatal in non-Swarm Docker environments.

---

## Network isolation rule

- `*_internal` networks are the only allowed paths for DB/cache and Docker socket proxy access.
- `proxy_net` is for Caddy and label-driven public routing.
- `homelab_net` remains a cross-stack discovery bridge until the new architecture is validated.

## Appendix A: Technical Documentation & Best Practice References

To guarantee long-term stability and align with industry/homelab-community standards, refer to these official documentation streams when implementing the phases above:

### 1. Stack Management & `.env` Isolation

- **Dockge Documentation**: [https://github.com/louislam/dockge](https://github.com/louislam/dockge)
- **Best Practice**: The community highly advises abandoning imperative `bash` deployment scripts (`up-all.sh`) in favor of managing compose files natively inside the Dockge UI or via its Git syncing interface.
- **Scoped Environment Variables**: Instead of a monolithic `homelab-config/.env` passing keys to unrelated containers, split environment states per stack. [Docker Compose ENV Docs](https://docs.docker.com/compose/how-tos/environment-variables/) recommend keeping `.env` precisely next to the `compose.yaml` utilizing those specific keys, limiting surface exposure if a single stack is compromised.

### 2. Edge Routing: Caddy Docker Proxy

- **CDP Official Repository**: [https://github.com/lucaslorentz/caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy)
- **Best Practice**: Never bind the docker socket directly to Caddy. Always use `DOCKER_HOST=tcp://docker-socket-proxy:2375`. Follow CDP's labeling semantics (`caddy: "example.com"`, `caddy.reverse_proxy: "{{upstreams 80}}"`) ensuring the Caddy container polls proxy networking metadata safely.

### 3. Permissions & Mount Handling: Docker Configs vs Bind Mounts

- **Docker Configs Documentation**: [https://docs.docker.com/compose/use-configs/](https://docs.docker.com/compose/use-configs/)
- **Best Practice**: Replace static file bind mounts (e.g., `volumes: - ./config.yml:/app/config.yml:ro`) with `configs:`. Mounting loose config files via `volumes` heavily restricts portability, invokes POSIX permission-masking clashes, and creates "directory creation" race conditions on Linux endpoints. `configs:` resolves this by treating the file as an immutable memory buffer.

### 4. Docker Socket Proxy Protection

- **Tecnativa Repository**: [https://github.com/Tecnativa/docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy)
- **Best Practice**: Expose only the required subsets of the Docker API to tools like Homepage or Caddy. By default, ensure `CONTAINERS=1` is set while sensitive methods (`POST=0`, `AUTH=0`) are permanently off, stopping lateral container breakout attacks completely.

---
**[END OF EXECUTION PLAN]**

| Attribute    | Value                                                               |
| ------------ | ------------------------------------------------------------------- |
| Hardware     | AMD Ryzen 5 5500U, 14GB RAM, ~930GB NVMe (single drive, no RAID)    |
| GPU          | AMD Vega 7 iGPU — VA-API for Jellyfin transcoding; no ROCm support |
| OS           | CachyOS Linux (Arch-based)                                          |
| Tailscale IP | `100.106.40.5`                                                    |
| Domain       | `andreasmaita.com` via Cloudflare Tunnel                          |
| Git repo     | `github.com/Andreas-PM/homelab-config` (and Forgejo mirror)       |
| Docker       | Compose plugin ≥ v2.24.0 required                                  |

---

## 2. Architecture Overview

### 2.1 Traffic Flow

```
Internet
  └─ Cloudflare (TLS edge — all HTTPS terminated here)
       └─ cloudflared (outbound tunnel daemon — no inbound port needed)
            └─ caddy:80 on homelab_net (plain HTTP — CF handles TLS)
                 ├─ [forward_auth → Authelia] for protected routes
                 └─ Service containers on homelab_net

Tailscale (100.106.40.5)
  └─ Host port bindings (20000+ range) → container ports directly
     All services accessible by IP+port — no Caddy/CF involved

Torrent traffic:
  qBittorrent (runs in Gluetun's netns) → Gluetun → ProtonVPN WireGuard → Internet

Usenet traffic (placeholder — no provider yet):
  SABnzbd → homelab_net → Internet (SSL encrypted, no VPN needed)
```

### 2.2 Access Tiers

| Tier                    | How                                          | Who uses it                   |
| ----------------------- | -------------------------------------------- | ----------------------------- |
| **Public**        | `https://*.andreasmaita.com` via CF Tunnel | Anyone                        |
| **Public + 2FA**  | Same + Authelia forward_auth challenge       | You                           |
| **Tailscale**     | `http://100.106.40.5:PORT`                 | You (any device on Tailscale) |
| **Internal only** | Docker service name resolution               | Containers only               |

### 2.3 Docker Networks

| Network                     | Type                  | Purpose                                      |
| --------------------------- | --------------------- | -------------------------------------------- |
| `homelab_net`             | Bridge, external=true | Cross-stack service discovery (all services) |
| `infrastructure_internal` | Bridge, internal=true | Authelia ↔ Redis isolated                   |
| `downloads_internal`      | Bridge, internal=true | Download clients isolated from media         |
| `cloud_internal`          | Bridge, internal=true | Immich/Nextcloud internal DB/cache access    |
| `services_internal`       | Bridge, internal=true | Paperless/Joplin DB access                   |

> **Rule:** Every container joins `homelab_net` for service-name DNS. Sensitive
> backend communication (DB connections, cache) uses an `*_internal` network that
> has no external connectivity.

### 2.4 Docker Socket Security

Two containers need Docker socket access: Caddy (routing) and Homepage (status).
Mount the socket read-only via a **socket proxy** for Homepage to limit blast radius.
Only Dockge (stack management) gets raw socket access.

```
/var/run/docker.sock (read-only)
  └─ docker-socket-proxy (Tecnativa, CONTAINERS=1 POST=0)
       └─ Homepage (reads container status for dashboard widgets)

/var/run/docker.sock (read-write)
  └─ Dockge (full stack management — deliberately scoped to Tailscale only)
  └─ caddy-docker-proxy (reads container labels to build routing config)
```

---

## 3. Declarative Configuration Strategy

### 3.1 The Problem

In the old setup, adding a service required manual changes to:

- `config/homepage/services.yaml` — dashboard entry
- `config/uptime-kuma/monitors.json` — monitoring config (re-export on each change)
- `config/caddy/Caddyfile` — routing entry

Three separate files to keep in sync, all with stale drift risk.

### 3.2 The Solution: Docker Labels as Single Source of Truth

Each service declares its own metadata directly in its compose labels.
Two tools read those labels to auto-configure themselves:

| Tool                                                                         | What it reads         | What it configures                         |
| ---------------------------------------------------------------------------- | --------------------- | ------------------------------------------ |
| **Homepage** (built-in label discovery)                                | `homepage.*` labels | Dashboard tiles, groups, widgets           |
| **Caddy Docker Proxy** (`lucaslorentz/caddy-docker-proxy:ci-alpine`) | `caddy.*` labels    | Reverse proxy routing (replaces Caddyfile) |

> **Result:** Adding a new service = add labels to its compose block.
> Caddy routing cleans up automatically when a container is removed.

### 3.3 Homepage Labels (example: Radarr)

```yaml
labels:
  homepage.group: "Arr Suite"
  homepage.name: "Radarr"
  homepage.icon: "radarr.png"
  homepage.href: "http://100.106.40.5:${RADARR_PORT}"
  homepage.description: "Movie manager"
  homepage.widget.type: "radarr"
  homepage.widget.url: "http://radarr:7878"
  homepage.widget.key: "${RADARR_API_KEY}"
```

The `docker.yaml` is already configured with the socket proxy. The `services.yaml`
config file becomes optional — only needed for static bookmarks or services without
containers (external URLs).

### 3.4 Uptime Kuma Monitors (Backup/Import)

Uptime Kuma monitors are managed manually via the web UI. After the initial setup is complete:

1. Go to **Settings → Backup** in the Uptime Kuma UI
2. Click **Export** — downloads a JSON file containing all monitors, notifications, and tags
3. Commit this file to the repo as `config/uptime-kuma/monitors.json`
4. On any rebuild, **Import** this file via the same Settings → Backup UI to restore all monitors instantly

> **Note:** Use `louislam/uptime-kuma:2` image tag (V2 required). The JSON backup format is V2-only.

### 3.5 Caddy Docker Proxy Labels

Replace `caddy:2-alpine` with `lucaslorentz/caddy-docker-proxy:ci-alpine`.
No Caddyfile needed. Labels on each service define routing.

**Global config on the Caddy container itself:**

```yaml
labels:
  caddy.auto_https: "off"                              # CF handles TLS — Caddy serves plain HTTP only
  caddy.servers.trusted_proxies: "static private_ranges"  # Trust X-Forwarded-Proto from cloudflared
```

> **Why `trusted_proxies` is required:** Cloudflared terminates TLS and forwards plain HTTP to Caddy
> on the Docker bridge. Without this, Caddy sees all requests as HTTP-only, which causes Authelia to
> generate HTTP redirect URLs for its login page — breaking the HTTPS TOTP flow.

**Authelia snippet defined on the Authelia container:**

```yaml
labels:
  caddy_0: "(authelia_auth)"
  caddy_0.forward_auth: "authelia:9091"
  caddy_0.forward_auth.uri: "/api/authz/forward-auth"
  caddy_0.forward_auth.copy_headers: "Remote-User Remote-Groups Remote-Email Remote-Name"
```

> **Note:** Do NOT add `?rd=` to the URI — that is the legacy Authelia approach.
> Instead, configure `authelia_url: https://auth.andreasmaita.com` under
> `session.cookies` in `config/authelia/configuration.yml`. Authelia handles the
> redirect automatically from there.

**Public service (no auth) — e.g. Jellyfin:**

```yaml
labels:
  caddy: "jellyfin.andreasmaita.com"
  caddy.reverse_proxy: "{{upstreams 8096}}"
```

**Protected service (2FA) — e.g. Homepage:**

```yaml
labels:
  caddy: "homepage.andreasmaita.com"
  caddy.1_import: "authelia_auth"
  caddy.2_reverse_proxy: "{{upstreams 3000}}"
```

Debug the generated Caddyfile at any time:

```bash
docker exec caddy cat /config/caddy/Caddyfile.autosave
```

**Service-specific label gotchas:**

*Actual Budget* requires `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers for its WASM features. Express these as labels:

```yaml
labels:
  caddy: "budget.andreasmaita.com"
  caddy.header.Cross-Origin-Opener-Policy: '"same-origin"'
  caddy.header.Cross-Origin-Embedder-Policy: '"require-corp"'
  caddy.reverse_proxy: "{{upstreams 5006}}"
```

*Yamtrack* has OAuth callback paths (`/import/trakt/private`, `/import/simkl/private`, `/import/anilist/private`) that must bypass `authelia_auth`. Caddy Docker Proxy supports named matchers in labels, but the syntax is complex:

```yaml
labels:
  caddy: "yamtrack.andreasmaita.com"
  caddy.@oauth_callback.path: "/import/trakt/private /import/simkl/private /import/anilist/private"
  caddy.handle_@oauth_callback.reverse_proxy: "{{upstreams 8000}}"
  caddy.handle.1_import: "authelia_auth"
  caddy.handle.2_reverse_proxy: "{{upstreams 8000}}"
```

> If the named-matcher label syntax causes parse errors, fall back to a minimal static snippet
> in a `Caddyfile.snippet` file volume-mounted into Caddy, and `import` it via a label.
> The Caddy container supports co-existing labels and an optional volume-mounted config.

---

## 4. Stack Definitions

### Stack 1 — Infrastructure (`stacks/infrastructure/`)

**Files:** `compose.yaml`

| Service                 | Image                                            | Internal Port | Host Port       | Access             | Notes                                                          |
| ----------------------- | ------------------------------------------------ | ------------- | --------------- | ------------------ | -------------------------------------------------------------- |
| `caddy`               | `lucaslorentz/caddy-docker-proxy:ci-alpine`    | 80            | —              | CF Tunnel only     | Label-driven routing; no Caddyfile                             |
| `cloudflared`         | `cloudflare/cloudflared:latest`                | —            | 20280 (metrics) | Internal           | Outbound tunnel; no inbound port needed                        |
| `authelia`            | `authelia/authelia:latest`                     | 9091          | —              | Via Caddy          | 2FA portal; Redis + SQLite backend                             |
| `authelia-redis`      | `redis:7-alpine`                               | 6379          | —              | Internal           | Session storage for Authelia                                   |
| `homepage`            | `ghcr.io/gethomepage/homepage:latest`          | 3000          | 20200           | Domain + Tailscale | Label auto-discovery enabled                                   |
| `docker-socket-proxy` | `ghcr.io/tecnativa/docker-socket-proxy:latest` | 2375          | —              | Internal           | Read-only socket for Homepage                                  |
| `watchtower`          | `containrrr/watchtower:latest`                 | —            | —              | Internal           | Opt-in only via `com.centurylinklabs.watchtower.enable=true` |

**Networks:** `homelab_net`, `infrastructure_internal` (authelia+redis isolated)

**First-run notes:**

- Authelia: set `AUTHELIA_JWT_SECRET`, `AUTHELIA_SESSION_SECRET`, `AUTHELIA_STORAGE_ENCRYPTION_KEY` in `.env`
- Generate recovery codes after first login — save to Vaultwarden + offline PDF
- Authelia `users_database.yml` pre-populated with your user before start

---

### Stack 2 — Monitoring (`stacks/monitoring/`)

**Files:** `compose.yaml`  *(new stack — split from infrastructure)*

| Service                | Image                                         | Internal Port | Host Port | Access    | Notes                                               |
| ---------------------- | --------------------------------------------- | ------------- | --------- | --------- | --------------------------------------------------- |
| `uptime-kuma`        | `louislam/uptime-kuma:2`                    | 3001          | 20201     | Tailscale | V2 image required                                   |
| `dockge`             | `louislam/dockge:latest`                    | 5001          | 20202     | Tailscale | Stack manager + container restarts from web UI      |
| `scrutiny`           | `ghcr.io/analogj/scrutiny:master-web`       | 8080          | 20210     | Tailscale | NVMe S.M.A.R.T monitoring — **do not remove**     |
| `scrutiny-collector` | `ghcr.io/analogj/scrutiny:master-collector` | —            | —        | Internal  | Runs as cron; requires `--device /dev/nvme0`      |
| `backrest`           | `ghcr.io/garethgeorge/backrest:latest`      | 9898          | 20211     | Tailscale | Web UI for Restic backups; replaces backup.sh cron  |

**Networks:** `homelab_net`

**Key configs:**

- Homepage connects to `docker-socket-proxy:2375` (read-only)
- Uptime Kuma: bootstrap monitors by importing `config/uptime-kuma/monitors.json` via Settings → Backup
- Scrutiny: single NVMe with no RAID — this is your only early-warning system for drive failure
- Dockge: **path constraint** — the stacks directory must use the **same path inside and outside the container** (Dockge requirement). Mount the repo's `stacks/` directory using its absolute host path:

  ```yaml
  volumes:
    - /home/a-p-maita/homelab-config/stacks:/home/a-p-maita/homelab-config/stacks
  environment:
    - DOCKGE_STACKS_DIR=/home/a-p-maita/homelab-config/stacks
  ```

  Dockge treats each subdirectory as one stack and can only manage a single `compose.yaml` per stack.
  **Multi-file stacks** (`compose.db.yaml`, `compose.vpn.yaml`, `compose.override.yaml`) are not editable via the Dockge UI — use CLI / Taskfile tasks for those.

- **Backrest:** Web UI for Restic (port 9898 → 20211). Configure backup repos (Backblaze B2) and schedule nightly snapshots from the UI. Pre/post hooks in Backrest run `backup-dbs.sh` to dump Postgres before each snapshot. First run: create account at `http://tailscale-ip:20211`, then add repo using `RESTIC_S3_KEY_ID/SECRET` and `RESTIC_BACKUP_PASSWORD` from `.env`. Replaces the manual Restic cron job.

---

### Stack 3 — Downloads (`stacks/downloads/`)

**Files:** `compose.yaml` + `compose.vpn.yaml` (VPN overlay)

| Service                         | Image                                      | Internal Port | Host Port               | Access    | Notes                                                     |
| ------------------------------- | ------------------------------------------ | ------------- | ----------------------- | --------- | --------------------------------------------------------- |
| `gluetun`                     | `qmcgaw/gluetun:latest`                  | —            | 20050 (WebUI via alias) | Tailscale | Gets `qbittorrent` alias on `homelab_net` in VPN mode |
| `qbittorrent`                 | `lscr.io/linuxserver/qbittorrent:latest` | 20050         | — (via Gluetun netns)  | Tailscale | Joins Gluetun netns in VPN mode; same URL for arr apps    |
| `prowlarr`                    | `lscr.io/linuxserver/prowlarr:latest`    | 9696          | 20055                   | Tailscale | Unified indexer manager                                   |
| `byparr`                      | `ghcr.io/thephaseless/byparr:latest`     | 8191          | —                      | Internal  | CF challenge solver for protected indexers                |
| `autobrr`                     | `ghcr.io/autobrr/autobrr:latest`         | 7474          | 20074                   | Tailscale | IRC/RSS instant grab before arr polling                   |
| `deunhealth`                  | `qmcgaw/deunhealth:latest`               | —            | —                      | Internal  | Auto-restarts unhealthy containers (VPN overlay only)     |
| `sabnzbd` *(commented out)* | `lscr.io/linuxserver/sabnzbd:latest`     | 8080          | 20300                   | Tailscale | Usenet client — enable when you have a paid provider     |

**Networks:** `homelab_net`, `downloads_internal`

**VPN notes:**

- `USE_VPN=true` in `.env` → `up-all.sh` applies `compose.vpn.yaml` overlay
- Gluetun gets alias `qbittorrent` on `homelab_net` — arr apps always reach it as `http://qbittorrent:20050`
- `scripts/update-qbt-port.sh` called by Gluetun when ProtonVPN assigns forwarded port
- Byparr is NOT routed through VPN — indexer search traffic is fine unrouted
- SABnzbd does NOT need VPN — usenet uses SSL encryption; DMCA is a torrent concern

---

### Stack 4 — Arr (`stacks/arr/`)

**Files:** `compose.yaml`

| Service         | Image                                   | Internal Port | Host Port | Access          | Notes                                                           |
| --------------- | --------------------------------------- | ------------- | --------- | --------------- | --------------------------------------------------------------- |
| `radarr`      | `lscr.io/linuxserver/radarr:latest`   | 7878          | 20056     | Tailscale       | Movies                                                          |
| `sonarr`      | `lscr.io/linuxserver/sonarr:latest`   | 8989          | 20057     | Tailscale       | TV + anime                                                      |
| `lidarr`      | `lscr.io/linuxserver/lidarr:latest`   | 8686          | 20058     | Tailscale       | Music                                                           |
| `bazarr`      | `lscr.io/linuxserver/bazarr:latest`   | 6767          | 20059     | Tailscale       | Subtitles for Radarr/Sonarr                                     |
| `shelfmark`   | `ghcr.io/calibrain/shelfmark:latest`  | 8084          | 20079     | Tailscale       | Manual book + audiobook search; Prowlarr + IRC + direct sources |
| `recyclarr`   | `ghcr.io/recyclarr/recyclarr:latest`  | —            | —        | None (cron job) | Quality profile sync from TRaSH Guides                          |
| `maintainerr` | `ghcr.io/jorenn92/maintainerr:latest` | 6246          | 20400     | Tailscale       | Library cleanup (replaces Cleanuparr)                           |
| `unpackerr`   | `golift/unpackerr:latest`             | —            | —        | None            | Archive extraction — no web UI                                 |

**Networks:** `homelab_net`

**Shared data mount:** All arr apps + qBittorrent mount `${DATA_ROOT}:/data`

- `*arr` root folders → `/data/media/{movies,tv,music,books,audiobooks,comics}`
- qBittorrent download paths → `/data/torrents/{movies,tv,music,books,audiobooks,incomplete}`

**Manual book/audiobook search:** Use **Shelfmark** (`shelfmark:8084`) as the unified search UI. Configure Prowlarr as an indexer source inside Shelfmark, and qBittorrent as the download client. Shelfmark also supports direct HTTP sources, IRC, and Usenet. Downloads land in `/data/torrents/books` or `/data/torrents/audiobooks` (picked up by arr apps / ABS).

- Set qBittorrent categories `books` and `audiobooks` as the destination in Shelfmark's download client settings.
- ABS Online Sources (Settings → Online Libraries) remains useful for AudioBookBay specifically — ABB is **not** in Prowlarr's supported indexer list and has no Torznab API.
- For private tracker access: add **MyAnonaMouse (MAM)** and **ABtorrents** as Prowlarr indexers (both are natively supported), then configure Prowlarr as an indexer source in Shelfmark.

**Shelfmark auth:** Supports proxy (forward) auth — set `X-Auth-User` header passthrough from Caddy and configure Shelfmark to trust it. Alternatively use OIDC with Authelia (PKCE flow supported). Since Shelfmark is Tailscale-only, single username/password auth is the simplest option for a solo setup.

**Shelfmark volumes:**

```yaml
volumes:
  - ../../data/shelfmark:/config          # relative to stacks/arr/compose.yaml
  - ${DATA_ROOT}/torrents/books:/books    # direct downloads land here
```

**Lidarr note:** Lidarr is functional when configured with the right indexers in Prowlarr.
Key improvement: add a dedicated music indexer (e.g. Gazelle-based private tracker if available)
via Prowlarr. The main issue is public torrent indexer quality for music, not Lidarr itself.

---

### Stack 5 — Media (`stacks/media/`)

**Files:** `compose.yaml`

| Service            | Image                                      | Internal Port | Host Port | Access             | Notes                                                                       |
| ------------------ | ------------------------------------------ | ------------- | --------- | ------------------ | --------------------------------------------------------------------------- |
| `jellyfin`       | `jellyfin/jellyfin:latest`               | 8096          | 20330     | Domain + Tailscale | Enable VA-API (`/dev/dri`) for hardware transcoding                       |
| `navidrome`      | `deluan/navidrome:latest`                | 4533          | 20070     | Tailscale          | Music; subsonic-compatible. Apps: Finamp (iOS/Android), Symfonium (Android) |
| `audiobookshelf` | `ghcr.io/advplyr/audiobookshelf:latest`  | 80            | 20020     | Domain + Tailscale | Audiobooks, podcasts, music, books (multiple library types supported)       |
| `calibre-web`    | `lscr.io/linuxserver/calibre-web:latest` | 8083          | 20078     | Tailscale          | Ebook library + reader (OPDS)                                               |
| `komga`          | `gotson/komga:latest`                    | 8080          | 20077     | Tailscale          | Comics + manga (OPDS)                                                       |
| `seerr`          | `fallenbagel/jellyseerr:latest`          | 5055          | 20331     | Domain + Tailscale | Media request system → Radarr/Sonarr                                       |
| `yamtrack`       | `ghcr.io/fuzzygrim/yamtrack:latest`      | 8000          | 20041     | Domain + Tailscale | Media tracking (TV, movies, anime, games, books, manga)                     |
| `yamtrack-redis` | `redis:8-alpine`                         | 6379          | —        | Internal           | Yamtrack session cache                                                      |
| `crosswatch`     | `ghcr.io/cenodude/crosswatch:latest`     | 8080          | 20042     | Tailscale          | Cross-service watch state sync (complements Yamtrack)                       |

**Networks:** `homelab_net`

**Calibre-Web note:** Calibre-Web requires a Calibre library (`metadata.db`). To manage the library
without a desktop GUI, add `lscr.io/linuxserver/calibre:latest` (headless Calibre with KasmVNC web
UI) at port 20080. This is optional if the library already exists.

**Jellyfin VA-API:** Add to compose:

```yaml
devices:
  - /dev/dri:/dev/dri
```

Then enable AMD VA-API transcoding in Jellyfin → Dashboard → Playback → Hardware Acceleration.

**Shared media directory mounts:** All media services in this stack mount subdirectories of `${DATA_ROOT}/media/`.
Multiple services intentionally share the same directories — the data is read-only for most consumers
(arr apps have write access for hardlinking; media servers are read-only).

| `${DATA_ROOT}/media/` subdirectory | Services that mount it                                      | Access |
| ---------------------------------- | ----------------------------------------------------------- | ------ |
| `movies/`                          | Jellyfin (Movies library), Radarr (root folder)             | Read / Write |
| `tv/`                              | Jellyfin (TV Shows library), Sonarr (root folder)           | Read / Write |
| `music/`                           | Jellyfin (Music library), Navidrome (library dir), Lidarr (root folder), ABS (Music library — optional) | Read / Write (Lidarr), Read |
| `audiobooks/`                      | ABS (Audiobooks library), Jellyfin (Audiobooks library — optional) | Read |
| `podcasts/`                        | ABS (Podcasts library)                                      | Read |
| `books/`                           | Calibre-Web (library — must contain `metadata.db`), ABS (Books/E-books library — optional), Komga (if mixed) | Read |
| `comics/`                          | Komga (Comics library)                                      | Read |
| `manga/`                           | Komga (Manga library)                                       | Read |

> **Note:** All these services mount `${DATA_ROOT}:/data` so the subdirectory paths above are all reachable as
> `/data/media/<dir>` inside each container. Configure each service's library path to that internal path.
> ABS in particular supports multiple simultaneous library types — add all that apply during ABS setup.

### Stack 6 — Cloud (`stacks/cloud/`)

**Files:** `compose.yaml` + `compose.override.yaml` (Immich customisations) + `compose.db.yaml` (databases)

**Start order:** `compose.db.yaml` first, then `compose.yaml` + `compose.override.yaml`

#### Databases (`compose.db.yaml`)

| Service                | Image                                  | Purpose                                          |
| ---------------------- | -------------------------------------- | ------------------------------------------------ |
| `immich-postgres`    | `tensorchord/pgvecto-rs:pg16-v0.2.0` | Immich — requires pgvecto-rs extension          |
| `immich-redis`       | `redis:7-alpine`                     | Immich session cache                             |
| `nextcloud-postgres` | `postgres:16-alpine`                 | Nextcloud data                                   |
| `nextcloud-redis`    | `redis:7-alpine`                     | Nextcloud file-locking (required for production) |

#### Applications (`compose.yaml` + `compose.override.yaml`)

| Service                     | Image                                                  | Internal Port | Host Port     | Access             | Notes                                                             |
| --------------------------- | ------------------------------------------------------ | ------------- | ------------- | ------------------ | ----------------------------------------------------------------- |
| `immich-server`           | `ghcr.io/immich-app/immich-server:${IMMICH_VERSION}` | 2283          | **2283**      | Domain + Tailscale | **Never use Watchtower** — update manually via docs        |
| `immich-machine-learning` | (same)                                                 | —            | —            | Internal           | **Disabled** — AMD Vega 7 has no ROCm; CPU too slow        |
| `forgejo`                 | `codeberg.org/forgejo/forgejo:latest`                | 3000 / 22     | 20110 / 20111 | Domain + Tailscale | Git server; SSH on 20111                                          |
| `vaultwarden`             | `vaultwarden/server:latest`                          | 80            | 20315         | Domain             | Self-hosted Bitwarden — own auth + built-in 2FA (see note below) |
| `nextcloud`               | `nextcloud:stable-apache`                            | 80            | 20460         | Domain + Tailscale | Cloud storage + Nextcloud Office (WASM)                           |

**Networks:** `homelab_net`, `immich_internal` + `cloud_internal` (each DB tier isolated in separate internal networks)

**Immich port:** The upstream Immich `compose.yaml` hardcodes `2283:2283`. This host port is kept as-is —
**do not override it to a non-standard port**. Immich mobile and desktop clients hard-code port 2283
when connecting via Tailscale IP (`100.106.40.5:2283`). Changing the host port breaks all existing app
connections and requires every client to be reconfigured. The `compose.override.yaml` does not override
ports; only the environment and network sections are customised there.

**Immich upload size limit:** CF Tunnel does not support chunked upload reassembly (>~100MB uploads
silently fail). **Workaround:** use Tailscale (`100.106.40.5:2283`) for bulk photo imports from desktop/mobile.
CF domain access is fine for browsing and small uploads. This is an accepted tradeoff — tracked
upstream but classified as out-of-scope by the Immich team.

**Nextcloud proxy config:** Set these in `.env` before first start — the `nextcloud:stable-apache`
entrypoint reads them and writes them into `config.php` automatically:

```bash
OVERWRITEPROTOCOL=https
OVERWRITEHOST=nextcloud.andreasmaita.com
OVERWRITECLIURL=https://nextcloud.andreasmaita.com
NEXTCLOUD_TRUSTED_DOMAINS=nextcloud.andreasmaita.com 100.106.40.5
```

> These must be set **before the first container start**. If Nextcloud has already initialised
> without them, run `docker exec nextcloud php occ config:system:set <key> --value=<val>` for
> each setting, or delete `./data/nextcloud/` and start fresh.

Nextcloud handles large file uploads correctly through CF Tunnel (client-side TUS chunking protocol —
unlike Immich which requires server-side reassembly).

**Forgejo env vars:** Configure via double-underscore env vars that map to `app.ini` sections
(`FORGEJO__section__key`). Required before first start:

- `FORGEJO__server__ROOT_URL=https://git.andreasmaita.com/` (controls clone URLs and redirect URLs)
- `FORGEJO__server__SSH_DOMAIN=git.andreasmaita.com`
- `FORGEJO__server__DOMAIN=git.andreasmaita.com`

**Vaultwarden admin token:** `ADMIN_TOKEN` must be an **Argon2 hash** of your chosen password, not the plain password itself. Generate:

```bash
docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp
```

Leave `ADMIN_TOKEN` blank to disable the admin panel entirely (safe for personal use).

**Vaultwarden + Immich — no Authelia forward_auth:** Both services rely on their own authentication systems. Bitwarden app and browser extension clients use direct API calls with session tokens; Authelia's cookie-based forward_auth intercepts these API calls and returns HTTP 302/401, breaking vault sync entirely. Immich mobile and desktop clients behave the same way. This is the same reason ABS, Forgejo, and Joplin are excluded from forward_auth.

**What to enable instead:**

- **Vaultwarden:** Set `SIGNUPS_ALLOWED=false`. Enable 2FA in the Vaultwarden web UI (Security → Two-step Login) — supports TOTP authenticators and FIDO2/WebAuthn hardware keys. The master password + 2FA is equivalent or stronger than Authelia in front of it.
- **Immich:** Disable user registration in Settings → User Management. Enable TOTP 2FA in account settings. Immich session tokens are long-lived but bound to device.

**Vaultwarden note:** Your existing Bitwarden subscription and this self-hosted instance are
completely separate vaults. Use Bitwarden's export function to migrate passwords across if desired,
or run both in parallel. The Bitwarden mobile/desktop apps can connect to the self-hosted instance
via the custom server URL option.

---

### Stack 7 — Home (`stacks/home/`)

**Files:** `compose.yaml`

| Service            | Image                                   | Internal Port | Host Port | Access    | Notes                                                            |
| ------------------ | --------------------------------------- | ------------- | --------- | --------- | ---------------------------------------------------------------- |
| `home-assistant` | `homeassistant/home-assistant:stable` | 8123          | 20340     | Tailscale | Use `network_mode: host` for device discovery (Zigbee/mDNS/BT) |

**Network note:** If using USB Zigbee/Z-Wave dongles or Bluetooth, switch to `network_mode: host`
and remove the ports mapping. HA will bind to host port 8123 directly.

---

### Stack 8 — Services (`stacks/services/`)

**Files:** `compose.yaml` + `compose.db.yaml`

#### Databases (`compose.db.yaml`)

| Service                | Image                  | Purpose                                    |
| ---------------------- | ---------------------- | ------------------------------------------ |
| `paperless-postgres` | `postgres:16-alpine` | Paperless-ngx (same `services_internal`) |
| `paperless-redis`    | `redis:7-alpine`     | Paperless task queue                       |
| `joplin-postgres`    | `postgres:16-alpine` | Joplin note sync server                    |

#### Applications (`compose.yaml`)

| Service           | Image                                          | Internal Port | Host Port | Access                | Notes                                                             |
| ----------------- | ---------------------------------------------- | ------------- | --------- | --------------------- | ----------------------------------------------------------------- |
| `paperless-ngx` | `ghcr.io/paperless-ngx/paperless-ngx:latest` | 8000          | 20301     | Domain +**2FA** | Documents; uses `services_internal` for DB + Redis              |
| `actual-budget` | `actualbudget/actual-server:latest`          | 5006          | 20350     | Domain + Tailscale    | Finance; own auth                                                 |
| `mealie`        | `ghcr.io/mealie-recipes/mealie:latest`       | 9000          | 20360     | Domain + Tailscale    | Recipe manager                                                    |
| `joplin`        | `joplin/server:latest`                       | 22300         | 20370     | Domain + Tailscale    | Note sync server; clients connect to domain                       |
| `stirling-pdf`  | `frooodle/s-pdf:latest`                      | 8080          | 20380     | Domain +**2FA** | PDF tools; login enabled via `config/stirling-pdf/settings.yml` |
| `monica`        | `monica:latest`                              | 80            | 20390     | Tailscale             | Personal CRM; SQLite; requires `APP_KEY` (see env vars)         |
| `drawio`        | `jgraph/drawio:latest`                       | 8080          | 20401     | Tailscale             | Diagrams; no auth — local/Tailscale only                         |
| `excalidraw`    | `excalidraw/excalidraw:latest`               | 80            | 20402     | Tailscale             | Whiteboard; no auth — local/Tailscale only                       |
| `it-tools`      | `corentinth/it-tools:latest`                 | 80            | 20403     | Tailscale             | Dev utilities; no auth — local/Tailscale only                    |

**Networks:** `homelab_net`, `services_internal` (DBs isolated)

---

## 5. Complete Port Allocation Table

All ports in the `20000–20499` range. No overlap with standard Linux services.

| Port  | Service                  | Stack          | Tailscale | Domain                               |
| ----- | ------------------------ | -------------- | --------- | ------------------------------------ |
| 20020 | Audiobookshelf           | media          | ✓        | `abs.andreasmaita.com`             |
| 20041 | Yamtrack                 | media          | ✓        | `yamtrack.andreasmaita.com`        |
| 20042 | Crosswatch               | media          | ✓        | —                                   |
| 20050 | qBittorrent WebUI        | downloads      | ✓        | —                                   |
| 20051 | qBittorrent TCP          | downloads      | ✓        | —                                   |
| 20052 | qBittorrent UDP          | downloads      | ✓        | —                                   |
| 20055 | Prowlarr                 | downloads      | ✓        | —                                   |
| 20056 | Radarr                   | arr            | ✓        | —                                   |
| 20057 | Sonarr                   | arr            | ✓        | —                                   |
| 20058 | Lidarr                   | arr            | ✓        | —                                   |
| 20059 | Bazarr                   | arr            | ✓        | —                                   |
| 20070 | Navidrome                | media          | ✓        | —                                   |
| 20074 | Autobrr                  | downloads      | ✓        | —                                   |
| 20077 | Komga                    | media          | ✓        | —                                   |
| 20078 | Calibre-Web              | media          | ✓        | —                                   |
| 20079 | Shelfmark                | arr            | ✓        | —                                   |
| 20080 | Calibre*(optional)*      | media          | ✓        | —                                   |
| 20110 | Forgejo HTTP             | cloud          | ✓        | `git.andreasmaita.com`             |
| 20111 | Forgejo SSH              | cloud          | ✓        | —                                   |
| 20200 | Homepage                 | infrastructure | ✓        | `homepage.andreasmaita.com` + 2FA  |
| 20201 | Uptime Kuma              | monitoring     | ✓        | —                                   |
| 20202 | Dockge                   | monitoring     | ✓        | —                                   |
| 20210 | Scrutiny                 | monitoring     | ✓        | —                                   |
| 20211 | Backrest                 | monitoring     | ✓        | —                                   |
| 20280 | Cloudflared metrics      | infrastructure | —        | —                                   |
| 20300 | SABnzbd*(commented out)* | downloads      | ✓        | —                                   |
| 20301 | Paperless-ngx            | services       | ✓        | `paperless.andreasmaita.com` + 2FA |
| 20315 | Vaultwarden              | cloud          | ✓        | `vault.andreasmaita.com`           |
| 20330 | Jellyfin                 | media          | ✓        | `jellyfin.andreasmaita.com`        |
| 20331 | Seerr (Jellyseerr)       | media          | ✓        | `seerr.andreasmaita.com`           |
| 20340 | Home Assistant           | home           | ✓        | —                                   |
| 20350 | Actual Budget            | services       | ✓        | `budget.andreasmaita.com`          |
| 20360 | Mealie                   | services       | ✓        | `mealie.andreasmaita.com`          |
| 20370 | Joplin                   | services       | ✓        | `joplin.andreasmaita.com`          |
| 20380 | Stirling PDF             | services       | ✓        | `pdf.andreasmaita.com` + 2FA       |
| 20390 | Monica                   | services       | ✓        | —                                   |
| 20400 | Maintainerr              | arr            | ✓        | —                                   |
| 20401 | DrawIO                   | services       | ✓        | —                                   |
| 20402 | Excalidraw               | services       | ✓        | —                                   |
| 20403 | IT-Tools                 | services       | ✓        | —                                   |
| 2283  | Immich                   | cloud          | ✓        | `immich.andreasmaita.com`          |
| 20460 | Nextcloud                | cloud          | ✓        | `nextcloud.andreasmaita.com`       |

---

## 6. Data Layout

```
${DATA_ROOT}/               (set in .env, default: ~/homelab-data)
├── media/
│   ├── movies/             ← Radarr root folder
│   ├── tv/                 ← Sonarr root folder
│   ├── music/              ← Lidarr root folder + Navidrome library
│   ├── audiobooks/         ← Audiobookshelf library
│   ├── podcasts/           ← Audiobookshelf library
│   ├── books/              ← Calibre-Web library (must contain metadata.db)
│   ├── comics/             ← Komga library
│   └── manga/              ← Komga library
├── torrents/
│   ├── movies/
│   ├── tv/
│   ├── music/
│   ├── books/
│   ├── audiobooks/
│   └── incomplete/         ← in-progress downloads (never hardlink from here)
├── photos/                 ← Immich upload location
└── nextcloud/              ← Nextcloud data directory

./data/                     (repo-local, gitignored)
├── {service}/              ← Each service's config/state volume
│   └── config/
└── ...

./config/                   (repo-tracked)
├── authelia/               ← users_database.yml, configuration.yml
├── qbittorrent/            ← categories.json seed file
├── recyclarr/              ← recyclarr.yml + configs/
└── stirling-pdf/           ← settings.yml
```

**qBittorrent categories** (seed on first run via `config/qbittorrent/categories.json`):

```json
{
  "movies":       { "save_path": "/data/torrents/movies" },
  "tv":           { "save_path": "/data/torrents/tv" },
  "music":        { "save_path": "/data/torrents/music" },
  "books":        { "save_path": "/data/torrents/books" },
  "audiobooks":   { "save_path": "/data/torrents/audiobooks" }
}
```

---

## 7. Security Model

### Auth Tiers

| Route                          | Protection                                                                       |
| ------------------------------ | -------------------------------------------------------------------------------- |
| `auth.andreasmaita.com`      | None (it IS the auth portal)                                                     |
| `vault.andreasmaita.com`     | Vaultwarden own login + built-in 2FA (TOTP/WebAuthn — no Authelia forward_auth) |
| `paperless.andreasmaita.com` | Authelia 2FA + Paperless own login                                               |
| `pdf.andreasmaita.com`       | Authelia 2FA + Stirling PDF own login                                            |
| `immich.andreasmaita.com`    | Immich own login (Authelia breaks mobile app)                                    |
| `jellyfin.andreasmaita.com`  | Jellyfin own login                                                               |
| `git.andreasmaita.com`       | Forgejo own login                                                                |
| `abs.andreasmaita.com`       | ABS own login                                                                    |
| `seerr.andreasmaita.com`     | Authelia one_factor                                                              |
| `yamtrack.andreasmaita.com`  | Authelia 2FA                                                                     |
| `homepage.andreasmaita.com`  | Authelia 2FA                                                                     |
| All other domains              | Authelia 2FA (default_policy: two_factor)                                        |

### Authelia Fallback & Recovery

1. **TOTP backup codes** — generate on first login, store in:
   - Vaultwarden entry (encrypted)
   - Offline PDF on phone, desktop, and a printed copy
2. **Second device** — enrol a second TOTP device (e.g. Aegis on a tablet)
3. **Circular dependency note:** A web-based TOTP app (e.g. Authelia WebAuthn) behind Authelia
   creates a lock-out risk. Recovery codes are the correct solution — simpler and reliable.

### Registration Lockdown

All services: disable signups/registration after initial account creation.
Key env vars and settings per service:

- `YAMTRACK_REGISTRATION=False`
- Jellyfin: disable user self-registration in Dashboard → General
- Immich: disable sign-up via Settings → User Management
- Forgejo: set `DISABLE_REGISTRATION=true` in app.ini after creating your account
- Vaultwarden: `SIGNUPS_ALLOWED=false` in env
- Nextcloud: disable "Allow users to sign up" in admin settings
- Paperless: no self-registration by default (superuser only)
- Mealie: set `ALLOW_SIGNUP=false` in env

### Secrets Management

All secrets in `.env` (gitignored). `.env.example` tracks the keys only.
`generate-secrets.sh` auto-generates random values for Authelia, Grafana, Restic passwords.
Secrets that require manual registration (CF token, Tailscale key, ProtonVPN) remain commented
in `.env.example` with instructions.

---

## 8. Service Decision Log

### Removed (and why)

| Service                           | Reason                                                                                         |
| --------------------------------- | ---------------------------------------------------------------------------------------------- |
| `jackett`                       | Prowlarr contains every indexer Jackett has; running both is redundant overhead                |
| `lazylibrarian`                 | Replaced by Shelfmark — unified search UI with Prowlarr, IRC, Usenet, and direct HTTP sources |
| `readarr`                       | User prefers manual search + Calibre-Web (reading) over automated Readarr                      |
| `bookbounty`                    | Replaced by Shelfmark — same search-on-demand workflow with a better UI and more source types |
| `audiobookbay-downloader`       | Audiobookshelf built-in Online Sources search replaces this custom script                      |
| `profilarr`                     | Overlaps with Recyclarr; Recyclarr is more established (TRaSH Guides integration)              |
| `cleanuparr`                    | Maintainerr is more feature-complete for the same purpose                                      |
| `crosswatch` *(reconsidered)* | Kept — provides cross-service watch sync Yamtrack doesn't do                                  |
| `prometheus`                    | Heavyweight for single-server; removed with Grafana and node-exporter                          |
| `grafana`                       | Removed with Prometheus stack                                                                  |
| `node-exporter`                 | Removed with Prometheus stack                                                                  |
| `feishin`                       | Removed per user request — Navidrome's own web UI is sufficient                               |
| `octo-fiesta`                   | Tested and not working well; removed                                                           |
| `romm`                          | Removed — not in use                                                                          |
| `wizarr`                        | Removed — no need for user invitation system (solo homelab)                                   |
| `kiwix`                         | Removed — not in active use                                                                   |
| `libreoffice`                   | Removed — replaced by Nextcloud Office (built-in WASM)                                        |
| `youtarr`                       | Removed — not in use                                                                          |
| `listenarr`                     | Removed — not in use                                                                          |
| `monica`                        | Kept*(was on removal list; user confirmed keep)*                                               |

### Added (and why)

| Service                         | Reason                                                                                                                              |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `nextcloud`                   | Google Drive/Docs replacement; cloud file storage + Nextcloud Office for document editing                                           |
| `dockge`                      | Web-based stack manager — restart containers and update stacks without SSH                                                         |
| `docker-socket-proxy`         | Security: limits Docker socket access for Homepage (read-only)                                                                      |
| `sabnzbd` *(commented out)* | Usenet client placeholder — enable when a paid provider is subscribed                                                              |
| `shelfmark`                   | Unified manual book + audiobook search UI; replaces Bookbounty + LazyLibrarian; supports Prowlarr, IRC, Usenet, direct HTTP sources |
| `scrutiny-collector`          | Standalone NVMe health monitoring — retained despite removing Prometheus stack                                                     |

### Retained with Notes

| Service       | Note                                                                               |
| ------------- | ---------------------------------------------------------------------------------- |
| `lidarr`    | Functional with proper indexers; quality depends on Prowlarr indexer configuration |
| `scrutiny`  | Critical — single NVMe with no RAID; only early warning for drive failure         |
| `recyclarr` | Run as `docker compose run --rm recyclarr sync` or on schedule via cron          |
| `unpackerr` | Silent background worker; no web UI; essential for compressed downloads            |

---

## 9. Critical Notes & Known Limitations

### RAM Budget

Estimated idle RAM usage across all services: **6–9GB** of 14GB available.
Active Jellyfin transcoding adds 0.5–2GB depending on codec. VA-API hardware transcoding is
critical to keep CPU/RAM load low — enable it in Jellyfin immediately after setup.

Heaviest services: Jellyfin (~400MB), Immich (~700MB), Nextcloud (~350MB), Stirling PDF (~400MB).
If RAM pressure becomes an issue, Stirling PDF is the first candidate to stop (Java heap).

### Storage Budget

930GB NVMe for everything. Media files will consume this over time.

- Set Radarr/Sonarr quality profiles to prefer **1080p WEB-DL** (4–8GB/movie) over remuxes (30–80GB)
- Recyclarr (TRaSH Guides) configures quality profiles automatically
- Maintainerr can auto-unmonitor/delete media not watched within a set period
- No off-server media backup — media is re-downloadable; prioritise config + DB backups

### Prowlarr as the Only Indexer Manager

Jackett removed. If a specific indexer is missing from Prowlarr, check the
[Prowlarr supported indexers list](https://wiki.servarr.com/prowlarr/supported-indexers) first.
Adding Jackett back is always an option — it still works as a Prowlarr source via the
`Torznab/Newznab proxy` connector.

### Manual Book & Audiobook Acquisition

**Shelfmark** (`ghcr.io/calibrain/shelfmark:latest`) is the primary book and audiobook discovery tool. It provides a single web UI that searches across all configured sources simultaneously:

- **Prowlarr** — connects to all Prowlarr indexers (MAM, ABtorrents, EBookBay, etc.) for torrent search
- **Direct HTTP sources** — scrapes book sites directly (no Torznab required)
- **IRC** — IRC book bot integration (e.g. #ebooks on IRC)
- **Usenet** — Newznab-compatible usenet indexer support
- **ABS integration** — audiobook downloads can be sent directly to the ABS library path
- **Calibre-Web integration** — link your CW instance in the Shelfmark header for quick library lookups

Shelfmark is intentionally **not** an automated monitor — it finds books and downloads them on demand. It does not track author releases or watch for new items. That non-goal is by design.

**Workflow — Search & Download via Shelfmark:**

1. Open Shelfmark (`http://tailscale-ip:20079`)
2. Search by title, author, or ISBN in Universal mode (searches metadata providers + all configured sources)
3. Select a result → choose source → download via qBittorrent (category `books` or `audiobooks`) or direct HTTP
4. qBittorrent delivers to `/data/torrents/books` or `/data/torrents/audiobooks`
5. Calibre-Web (ebooks) or ABS (audiobooks) picks up the file from their respective library paths

**Workflow — Audiobookshelf Online Sources (AudioBookBay specifically):**
ABB is **not** in Prowlarr's supported indexer list and has no Torznab API. For ABB content, use ABS's built-in Online Libraries (Settings → Online Libraries) which scrapes ABB directly and downloads into the ABS library without qBittorrent.

**Private tracker indexers for Prowlarr:**

- **MyAnonaMouse (MAM)** — large private audiobook + ebook tracker (natively supported in Prowlarr; invite-based)
- **ABtorrents** — dedicated private audiobook tracker (natively supported in Prowlarr; invite-based)
- **EBookBay** — public ebook tracker (no account required)

### Immich Machine Learning

Disabled (`profiles: [disabled]`). AMD Vega 7 has no ROCm/OpenCL Docker support for Immich's
ML container. Enabling CPU-only ML consumes ~2GB RAM and is too slow to be useful.
Smart search (CLIP), facial recognition, and smart albums are non-functional.
Track: `github.com/immich-app/immich/issues/2185` for future ROCm/VA-API ML support.

### Nextcloud Office

Nextcloud Office (built-in since NC27+) runs as WASM in the browser — no separate Collabora
container needed. It is slower than desktop LibreOffice but works entirely in-browser.
For heavy document editing, the desktop LibreOffice with Nextcloud sync is faster.

### Directory Structure & Multi-Compose Files

The current layout (`stacks/`, `config/`, `data/`, `scripts/`, `backups/`) is standard homelab
best practice. No changes needed.

A `Taskfile.yaml` in the repo root replaces the `scripts/up-all.sh`, `down-all.sh`,
`compose-pull-all.sh`, and `restart-update-all.sh` files. Install the `task` binary
(`paru -S go-task-bin` on CachyOS) or run it as a Docker container. Three short scripts
(`backup-dbs.sh`, `generate-secrets.sh`, `update-qbt-port.sh`) are retained because they
have no meaningful container substitute.

**Multiple compose files per stack** is the correct Docker approach for separation of concerns:

- `compose.yaml` — core services (always applied)
- `compose.vpn.yaml` — VPN overlay (applied only when needed: `-f compose.yaml -f compose.vpn.yaml`)
- `compose.db.yaml` — databases isolated from app tier
- `compose.override.yaml` — auto-merged by Docker when present alongside `compose.yaml`

Docker Compose v2 auto-merges `compose.override.yaml` when both files share the same directory.
All other non-standard filenames require explicit `-f` flags, which is what the scripts do.

### Script Analysis & Replacements

The custom `scripts/` bash files are replaced with standard tooling where possible.
Only scripts with no viable container/binary substitute are retained.

#### Taskfile — replaces orchestration scripts

**[Taskfile](https://taskfile.dev)** (`ghcr.io/go-task/task:latest` or install binary) replaces
`up-all.sh`, `down-all.sh`, `compose-pull-all.sh`, and `restart-update-all.sh`. A `Taskfile.yaml`
in the repo root defines reproducible, documented tasks that run the same `docker compose` commands
without bespoke bash logic.

Install on CachyOS: `paru -S go-task-bin` (AUR) or download binary from GitHub releases.

```yaml
# Taskfile.yaml (repo root — illustrative structure)
version: "3"
tasks:
  up:
    desc: "Start all stacks"
    cmds:
      - docker compose -p infrastructure -f stacks/infrastructure/compose.yaml up -d
      - docker compose -p monitoring -f stacks/monitoring/compose.yaml up -d
      # ... remaining stacks in order
  down:
    desc: "Stop all stacks"
    cmds:
      - docker compose -p services -f stacks/services/compose.yaml -f stacks/services/compose.db.yaml down
      # ... reverse order
  pull:
    desc: "Pull latest images for all stacks"
    cmds:
      - for: [infrastructure, monitoring, downloads, arr, media, cloud, home, services]
        cmd: docker compose -p {{.ITEM}} -f stacks/{{.ITEM}}/compose.yaml pull
  backup:
    desc: "Dump databases then trigger Backrest snapshot"
    cmds:
      - bash scripts/backup-dbs.sh
      - docker exec backrest backrest backup --plan homelab
```

> Dockge handles **per-stack** restarts and single-compose-file stacks via the web UI.
> Taskfile handles **multi-stack orchestration** and multi-file stacks from the CLI.

#### Backrest — replaces backup.sh + cron

**[Backrest](https://github.com/garethgeorge/backrest)** (`ghcr.io/garethgeorge/backrest:latest`)
is a web UI and scheduler built on Restic. It runs as a container in the monitoring stack (port 20211)
and replaces the `scripts/backup.sh` cron job entirely:

- Configure backup plans and schedules from the web UI (no cron needed)
- Pre-backup hook: calls `scripts/backup-dbs.sh` to dump Postgres before each snapshot
- Supports Backblaze B2 (and any other Restic backend) — configure with `RESTIC_S3_KEY_ID/SECRET`
- Browse and restore snapshots from the UI
- Notifications via Discord/Gotify/Healthchecks

`scripts/backup-dbs.sh` is **retained** — it is called as a Backrest pre-backup hook and is a short,
reliable script with no container substitute.

#### Uptime Kuma JSON — replaces setup-uptime-kuma.sh

The complex Python bootstrap script (`scripts/setup-uptime-kuma.sh`) is replaced by Uptime Kuma's
built-in backup/restore:

1. After initial setup, go to **Settings → Backup → Export**
2. Commit the JSON to `config/uptime-kuma/monitors.json`
3. On rebuild, **Import** the file to restore all monitors instantly

No script, no API calls, no Python dependencies. `scripts/setup-uptime-kuma.sh` can be deleted.

#### Retained scripts

| Script                   | Reason retained                                                                       |
| ------------------------ | ------------------------------------------------------------------------------------- |
| `backup-dbs.sh`        | Called as Backrest pre-backup hook; dumps Immich, Paperless, Joplin Postgres          |
| `generate-secrets.sh`  | One-time `.env` secret generation; no container substitute adds value                |
| `update-qbt-port.sh`   | Called by Gluetun's `VPN_PORT_FORWARDING_UP_COMMAND`; Gluetun-specific, no substitute |

**Conclusion:** Backrest replaces `backup.sh`. Taskfile replaces the four orchestration scripts.
Uptime Kuma JSON import replaces `setup-uptime-kuma.sh`. Three short scripts are kept.

---

## 10. Rebuild Phases

Execute in order. Each phase should be fully working before proceeding to the next.

### Phase 0 — Preparation & Data Migration

Since only **Audiobookshelf** and **Immich** data is worth migrating, do this before tearing down the current stack.

#### Data to migrate

| What                  | Current path                                                       | Why                                                      |
| --------------------- | ------------------------------------------------------------------ | -------------------------------------------------------- |
| ABS config + metadata | `data/audiobookshelf/config/`                                    | Users, progress, library metadata                        |
| ABS metadata cache    | `data/audiobookshelf/metadata/`                                  | Cover art, podcasts cache                                |
| Audiobook media files | Wherever ABS currently points (check ABS → Settings → Libraries) | The actual audio files                                   |
| Immich photos/videos  | `data/immich_upload/`                                            | library/, profile/, thumbs/, upload/, encoded-video/     |
| Immich database       | Dump via `backup-dbs.sh`                                         | All album/people/metadata — required for Immich restore |

#### Migration steps

**Option A — Same machine rebuild (data dirs stay put):**

The new Immich compose volume mount uses `${DATA_ROOT}/photos` as the upload path, but the current
data lives at `data/immich_upload/` (repo-local). You must either move the data to the new path
**or** point the new compose file at the old path. Moving is cleaner:

```bash
# 1. Dump databases BEFORE stopping anything
bash scripts/backup-dbs.sh                  # creates backups/immich-YYYY-MM-DD.sql etc.

# 2. Stop only the containers whose data you care about
docker compose -p media stop audiobookshelf
docker compose -p cloud stop immich-server immich-machine-learning immich-postgres

# 3. Verify data dirs are intact before proceeding
ls -lh data/audiobookshelf/
ls -lh data/immich_upload/

# 4. Move Immich upload data to the new DATA_ROOT location
#    (DATA_ROOT must be set in .env first)
mkdir -p ${DATA_ROOT}/photos
mv data/immich_upload/* ${DATA_ROOT}/photos/
# data/immich_upload/ can be removed after verifying the new path
```

**Option B — Different machine / path change:**

```bash
# 1. Dump Immich Postgres (immich_postgres container must be running)
docker exec immich-postgres pg_dumpall -U postgres > backups/immich-full-$(date +%F).sql

# 2. rsync ABS data (config + metadata + media)
rsync -avP data/audiobookshelf/ NEW_SERVER:/path/to/data/audiobookshelf/
rsync -avP /path/to/audiobook/media/ NEW_SERVER:/path/to/media/audiobooks/

# 3. rsync Immich upload directory to new DATA_ROOT path
rsync -avP data/immich_upload/ NEW_SERVER:${DATA_ROOT}/photos/

# 4. On new server — restore Immich Postgres AFTER immich-postgres container is up
#    but BEFORE immich-server starts (stop immich-server first)
docker exec -i immich-postgres psql -U postgres < backups/immich-full-YYYY-MM-DD.sql
```

**After restore — Immich verification checklist:**

- [ ] `IMMICH_VERSION` in `.env` matches the dumped version exactly (do not change versions during migration)
- [ ] All library paths in Immich admin match the new host paths
- [ ] Run Library Scan after first start to rebuild thumbnails index

**After restore — ABS verification checklist:**

- [ ] Library paths in ABS Settings → Libraries point to the correct new media dirs
- [ ] Users, progress, and podcast subscriptions are intact (stored in `config/`)

#### Pre-rebuild checklist

- [ ] Run `bash scripts/backup-dbs.sh` — database dumps to `backups/`
- [ ] Run `bash scripts/backup.sh` (or trigger Backrest manual snapshot if already running) — full Restic backup
- [ ] Commit current config to git + push to GitHub
- [ ] Export Bitwarden vault as encrypted JSON (offline backup)
- [ ] Export Uptime Kuma monitors: Settings → Backup → Export → save as `config/uptime-kuma/monitors.json`
- [ ] Note all API keys currently in use (Radarr, Sonarr, Prowlarr etc.)
- [ ] Verify `data/audiobookshelf/` and `data/immich_upload/` are intact
- [ ] Create `homelab_net` bridge: `docker network create homelab_net`

### Phase 1 — Infrastructure Core

- [ ] Remove or archive the existing `stacks/infrastructure/Dockerfile.caddy` — caddy-docker-proxy uses its own pre-built image (`lucaslorentz/caddy-docker-proxy:ci-alpine`) and does not require a custom Dockerfile
- [ ] Deploy `caddy-docker-proxy` (replace `caddy:2-alpine`)
- [ ] Deploy `cloudflared` with `TUNNEL_TOKEN`
- [ ] Verify CF Tunnel connects and caddy serves a test page
- [ ] Deploy `authelia` + `authelia-redis`
- [ ] Configure `users_database.yml` and `configuration.yml`
- [ ] Generate Authelia recovery codes — save immediately
- [ ] Verify `auth.andreasmaita.com` is reachable and 2FA works

### Phase 2 — Monitoring

- [ ] Deploy `uptime-kuma` (V2 image: `louislam/uptime-kuma:2`)
- [ ] Import `config/uptime-kuma/monitors.json` via Settings → Backup to restore monitors (or build manually if first-ever setup)
- [ ] Deploy `dockge` — verify stack management works
- [ ] Deploy `scrutiny` + `scrutiny-collector` — verify NVMe data appears
- [ ] Deploy `homepage` with Docker socket proxy
- [ ] Deploy `backrest` — configure B2 repo with `RESTIC_S3_KEY_ID/SECRET`; add pre-backup hook calling `backup-dbs.sh`; schedule nightly backup plan

### Phase 3 — Downloads

- [ ] Deploy `gluetun` + `qbittorrent` (no VPN first, verify connectivity)
- [ ] Apply VPN overlay (`compose.vpn.yaml`), verify VPN connects
- [ ] Deploy `prowlarr` — configure indexers
- [ ] Deploy `byparr` — link in Prowlarr as CF solver
- [ ] Deploy `autobrr` — configure IRC/RSS filters
- [ ] Verify qBittorrent categories match `config/qbittorrent/categories.json`

### Phase 4 — Arr Automation

- [ ] Deploy `radarr`, `sonarr`, `lidarr`, `bazarr`
- [ ] Connect each to qBittorrent and Prowlarr (via UI)
- [ ] Run `recyclarr sync` — apply TRaSH Guide quality profiles
- [ ] Deploy `maintainerr` — configure cleanup rules
- [ ] Deploy `unpackerr` — configure paths for each arr app
- [ ] Deploy `shelfmark` — configure Prowlarr + qBittorrent as sources, point download dir to `/data/torrents/books`
- [ ] Verify Shelfmark search works end-to-end (search → grab → qBittorrent delivery)

### Phase 5 — Media Servers

- [ ] Deploy `jellyfin` — configure VA-API, add media libraries (Movies, TV, Music, Audiobooks, Podcasts — all from `/data/media/`)
- [ ] Deploy `navidrome` — point at `/data/media/music`
- [ ] Deploy `audiobookshelf` — add libraries: Audiobooks (`/data/media/audiobooks`), Podcasts (`/data/media/podcasts`), Music (optional, `/data/media/music`), Books (optional, `/data/media/books`)
- [ ] Deploy `calibre-web` — point at `/data/media/books` (requires `metadata.db`)
- [ ] Deploy `komga` — configure comics (`/data/media/comics`) and manga (`/data/media/manga`) libraries
- [ ] Deploy `seerr` — connect to Radarr + Sonarr
- [ ] Deploy `yamtrack` + `yamtrack-redis` — configure Trakt/AniList/Steam OAuth
- [ ] Deploy `crosswatch` — configure sync sources

### Phase 6 — Cloud Services

- [ ] Start cloud databases: `compose.db.yaml` (Immich Postgres + Redis, Nextcloud Postgres + Redis)
- [ ] Deploy `immich` — configure upload location, verify Tailscale upload works
- [ ] Deploy `forgejo` — set `FORGEJO__server__ROOT_URL` in `.env` before first start; disable registration after creating account
- [ ] Deploy `vaultwarden` — `SIGNUPS_ALLOWED=false`, generate and set `ADMIN_TOKEN` hash, configure 2FA
- [ ] Migrate Bitwarden vault to Vaultwarden (test with one non-critical entry first)
- [ ] Deploy `nextcloud` — verify `OVERWRITEPROTOCOL`, `OVERWRITEHOST`, `NEXTCLOUD_TRUSTED_DOMAINS` in `.env` before first start; then install Nextcloud Office app via the Apps menu

### Phase 7 — Home & Services

- [ ] Deploy `home-assistant` — complete onboarding wizard
- [ ] Start services databases: `compose.db.yaml` (Paperless Postgres + Redis, Joplin Postgres)
- [ ] Deploy `paperless-ngx` — superuser created from `PAPERLESS_ADMIN_USER/PASSWORD` env vars on first start; configure consumption directory after
- [ ] Deploy `actual-budget`, `mealie`, `joplin`, `stirling-pdf`
  - Mealie: `DEFAULT_EMAIL` + `DEFAULT_PASSWORD` set in `.env` before first start
  - Joplin: `APP_BASE_URL` must match domain before first start
  - Stirling PDF: credentials set in `config/stirling-pdf/settings.yml` (already tracked)
- [ ] Deploy `monica`, `drawio`, `excalidraw`, `it-tools`
  - Monica: `APP_KEY` must be set in `.env` before first start (format: `base64:...`)

### Phase 8 — Hardening & Final Config

- [ ] Disable signups/registration on all services (see Security Model above)
- [ ] Verify all Authelia 2FA routes are protected
- [ ] Verify Homepage shows all services via Docker labels
- [ ] Verify Uptime Kuma monitors are active; export monitors JSON → commit to `config/uptime-kuma/monitors.json`
- [ ] Verify Backrest scheduled backup runs and snapshot appears in the UI; test restore of one file
- [ ] Run `task backup` (or `bash scripts/backup-dbs.sh && docker exec backrest backrest backup --plan homelab`) to verify end-to-end backup works
- [ ] Push final config to GitHub + Forgejo

### Phase 9 — SABnzbd (when provider is ready)

- [ ] Choose usenet provider (Frugal, Eweka, or Newshosting recommended — ~£3–5/month)
- [ ] Uncomment SABnzbd in `stacks/downloads/compose.yaml`
- [ ] Add newznab indexer in Prowlarr pointing at provider
- [ ] Configure SABnzbd as a download client in Radarr, Sonarr, Lidarr

---

## 11. Key Environment Variables

Complete `.env` reference for the new setup. Copy `.env.example` to `.env` and fill in.
Run `bash scripts/generate-secrets.sh` after copying to auto-generate all random secrets.

```bash
# ─── Core ────────────────────────────────────────────────────────────────────
TZ=Europe/London
PUID=1000
PGID=1000

# ─── Paths ───────────────────────────────────────────────────────────────────
DATA_ROOT=/home/a-p-maita/homelab-data  # absolute path; NOT inside the repo
# UPLOAD_LOCATION: Immich-specific var consumed by the upstream compose.yaml
# Docker Compose resolves $DATA_ROOT at runtime so this reference works:
UPLOAD_LOCATION=${DATA_ROOT}/photos

# ─── Cloudflare ───────────────────────────────────────────────────────────────
TUNNEL_TOKEN=                           # dash.cloudflare.com → Zero Trust → Tunnels → your tunnel → Token
CLOUDFLARED_PORT=20280

# ─── VPN (optional) ───────────────────────────────────────────────────────────
USE_VPN=false                           # set true to apply compose.vpn.yaml overlay on arr stack
OPENVPN_USER=                           # ProtonVPN: account.proton.me → VPN → OpenVPN/IKEv2 credentials
OPENVPN_PASSWORD=                       # separate from your ProtonVPN login — these are VPN account creds
PROTONVPN_SERVER_COUNTRIES=Netherlands  # P2P-capable country list
HEALTH_VPN_DURATION_INITIAL=120s

# ─── Authelia (run generate-secrets.sh) ──────────────────────────────────────
AUTHELIA_JWT_SECRET=                    # openssl rand -hex 64
AUTHELIA_SESSION_SECRET=               # openssl rand -hex 32
AUTHELIA_STORAGE_ENCRYPTION_KEY=       # openssl rand -hex 32

# ─── qBittorrent ─────────────────────────────────────────────────────────────
QBITTORRENT_WEBUI_PORT=20050
QBITTORRENT_TCP_PORT=20051
QBITTORRENT_UDP_PORT=20052
QBITTORRENT_WEBUI_USER=a-p-maita
QBITTORRENT_WEBUI_PASS=               # strong password; used by arr apps to authenticate

# ─── Immich ───────────────────────────────────────────────────────────────────
# ⚠ Pin IMMICH_VERSION to the exact release you install.
# Never bump version during or after a migration without reading the release notes.
IMMICH_VERSION=release                  # e.g. v1.131.0 — check github.com/immich-app/immich/releases
DB_PASSWORD=                            # generate-secrets.sh; used directly by upstream compose.yaml
DB_USERNAME=postgres
DB_DATABASE_NAME=immich

# ─── Nextcloud ────────────────────────────────────────────────────────────────
# ⚠ All four vars below MUST be set before the very first container start.
# Changing them post-init requires running `occ config:system:set` manually.
NEXTCLOUD_ADMIN_USER=a-p-maita
NEXTCLOUD_ADMIN_PASSWORD=               # set before first start
NEXTCLOUD_DB_PASSWORD=                  # generate-secrets.sh
NEXTCLOUD_REDIS_PASSWORD=               # generate-secrets.sh
NEXTCLOUD_TRUSTED_DOMAINS=nextcloud.andreasmaita.com 100.106.40.5
OVERWRITEPROTOCOL=https
OVERWRITEHOST=nextcloud.andreasmaita.com
OVERWRITECLIURL=https://nextcloud.andreasmaita.com

# ─── Forgejo ──────────────────────────────────────────────────────────────────
# Double-underscore vars map to app.ini: FORGEJO__<Section>__<Key>
FORGEJO__server__ROOT_URL=https://git.andreasmaita.com/
FORGEJO__server__SSH_DOMAIN=git.andreasmaita.com
FORGEJO__server__DOMAIN=git.andreasmaita.com
FORGEJO__server__HTTP_PORT=3000
FORGEJO__server__OFFLINE_MODE=false

# ─── Vaultwarden ──────────────────────────────────────────────────────────────
VAULTWARDEN_SIGNUPS_ALLOWED=false
# Admin token: Argon2 hash of your admin password (NOT the plain password)
# Generate: docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp
# Leave blank to disable the admin panel entirely (safe for solo use)
VAULTWARDEN_ADMIN_TOKEN=

# ─── Paperless-ngx ────────────────────────────────────────────────────────────
PAPERLESS_SECRET_KEY=                   # generate-secrets.sh
PAPERLESS_ADMIN_USER=a-p-maita
PAPERLESS_ADMIN_MAIL=admin@andreasmaita.com
PAPERLESS_ADMIN_PASSWORD=               # set before first start; account created on first start
PAPERLESS_DB_PASSWORD=                  # generate-secrets.sh
PAPERLESS_URL=https://paperless.andreasmaita.com

# ─── Joplin ───────────────────────────────────────────────────────────────────
JOPLIN_DB_PASSWORD=                     # generate-secrets.sh
JOPLIN_BASE_URL=https://joplin.andreasmaita.com  # clients connect to this URL

# ─── Mealie ───────────────────────────────────────────────────────────────────
MEALIE_DEFAULT_EMAIL=admin@andreasmaita.com
MEALIE_DEFAULT_PASSWORD=               # set before first start; change after first login
MEALIE_BASE_URL=https://mealie.andreasmaita.com

# ─── Monica ───────────────────────────────────────────────────────────────────
# ⚠ Required before first start. Format MUST be base64:<key>
# Generate: echo "base64:$(openssl rand -base64 32)"
MONICA_APP_KEY=

# ─── Yamtrack ─────────────────────────────────────────────────────────────────
YAMTRACK_SECRET=                        # generate-secrets.sh
YAMTRACK_EXTERNAL_URL=https://yamtrack.andreasmaita.com
YAMTRACK_REGISTRATION=False
YAMTRACK_TMDB_API=                      # optional — themoviedb.org/settings/api (v3 key)
# OAuth apps — register redirect URIs at each provider before using Import:
YAMTRACK_TRAKT_CLIENT_ID=               # trakt.tv/oauth/applications
YAMTRACK_TRAKT_CLIENT_SECRET=           # redirect: https://yamtrack.andreasmaita.com/import/trakt/private
YAMTRACK_ANILIST_CLIENT_ID=             # anilist.co/settings/developer
YAMTRACK_ANILIST_CLIENT_SECRET=         # redirect: https://yamtrack.andreasmaita.com/import/anilist/private
YAMTRACK_SIMKL_CLIENT_ID=              # simkl.com/settings/developer
YAMTRACK_SIMKL_CLIENT_SECRET=          # redirect: https://yamtrack.andreasmaita.com/import/simkl/private
STEAM_API_KEY=                          # optional — steamcommunity.com/dev/apikey

# ─── Backups ──────────────────────────────────────────────────────────────────
RESTIC_BACKUP_PASSWORD=                 # generate-secrets.sh; used as Restic repo password in Backrest
RESTIC_S3_KEY_ID=                       # Backblaze B2 application key ID (configure in Backrest UI → Repository)
RESTIC_S3_SECRET=                       # Backblaze B2 application key secret

# ─── Uptime Kuma ──────────────────────────────────────────────────────────────
# Monitors seeded from config/uptime-kuma/monitors.json via Settings → Backup → Import
UPTIMEKUMA_USER=a-p-maita
UPTIMEKUMA_PASS=

# ─── API keys (fill in after each service is running) ─────────────────────────
RADARR_API_KEY=                         # Settings → General
SONARR_API_KEY=                         # Settings → General
PROWLARR_API_KEY=                       # Settings → General
LIDARR_API_KEY=                         # Settings → General
BAZARR_API_KEY=                         # Settings → General (Homepage widget)
JELLYFIN_API_KEY=                       # Dashboard → API Keys
SEERR_API_KEY=                          # Settings → General
ABS_API_KEY=                            # Settings → Security

# ─── Port allocations ─────────────────────────────────────────────────────────
# Infrastructure
HOMEPAGE_PORT=20200
UPTIME_KUMA_PORT=20201
DOCKGE_PORT=20202
SCRUTINY_PORT=20210
BACKREST_PORT=20211

# Media
ABS_PORT=20020
YAMTRACK_PORT=20041
CROSSWATCH_PORT=20042

# Downloads
PROWLARR_PORT=20055
AUTOBRR_PORT=20074

# Arr
RADARR_PORT=20056
SONARR_PORT=20057
LIDARR_PORT=20058
BAZARR_PORT=20059
SHELFMARK_PORT=20079
MAINTAINERR_PORT=20400

# Media servers
JELLYFIN_PORT=20330
SEERR_PORT=20331
NAVIDROME_PORT=20070
CALIBREWEB_PORT=20078
KOMGA_PORT=20077

# ─── Cloud
FORGEJO_PORT=20110
FORGEJO_SSH_PORT=20111
IMMICH_PORT=2283
VAULTWARDEN_PORT=20315
NEXTCLOUD_PORT=20460

# Services
PAPERLESS_PORT=20301
HOME_ASSISTANT_PORT=20340
ACTUAL_BUDGET_PORT=20350
MEALIE_PORT=20360
JOPLIN_PORT=20370
STIRLING_PDF_PORT=20380
MONICA_PORT=20390
DRAWIO_PORT=20401
EXCALIDRAW_PORT=20402
IT_TOOLS_PORT=20403

# SABnzbd (uncomment when provider ready)
# SABNZBD_PORT=20300
# SABNZBD_API_KEY=
```
