# Homelab Remake — Architecture Plan

> Authoritative planning document for a full homelab rebuild from scratch.
> Generated: 2026-05-19. All decisions recorded with rationale.
> Work from this document phase-by-phase, consulting upstream docs at each step.

---

## 1. System Context

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
- `scripts/setup-uptime-kuma.sh` — monitoring script
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

### 3.4 Uptime Kuma Monitors (Manual)

Uptime Kuma monitors are managed manually via the web UI. The
`scripts/setup-uptime-kuma.sh` script bootstraps the initial monitor set and is
**retained** in the repository — run it after Phase 2 to pre-populate monitors.
Add new monitors by hand when deploying new services.

> **Note:** Use `louislam/uptime-kuma:2` image tag (V2 is required for the API used by the setup script).

### 3.5 Caddy Docker Proxy Labels

Replace `caddy:2-alpine` with `lucaslorentz/caddy-docker-proxy:ci-alpine`.
No Caddyfile needed. Labels on each service define routing.

**Global config on the Caddy container itself:**

```yaml
labels:
  caddy.auto_https: "off"   # CF handles TLS — Caddy serves plain HTTP only
```

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

**Protected service (2FA) — e.g. Vaultwarden:**

```yaml
labels:
  caddy: "vault.andreasmaita.com"
  caddy.1_import: "authelia_auth"
  caddy.2_reverse_proxy: "{{upstreams 80}}"
```

Debug the generated Caddyfile at any time:

```bash
docker exec caddy cat /config/caddy/Caddyfile.autosave
```

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
| `scrutiny`           | `ghcr.io/analogj/scrutiny:master-web`       | 8080          | 20210     | Tailscale | NVMe S.M.A.R.T monitoring —**do not remove** |
| `scrutiny-collector` | `ghcr.io/analogj/scrutiny:master-collector` | —            | —        | Internal  | Runs as cron; requires `--device /dev/nvme0`      |

**Networks:** `homelab_net`

**Key configs:**

- Homepage connects to `docker-socket-proxy:2375` (read-only)
- Run `scripts/setup-uptime-kuma.sh` after first Uptime Kuma start to bootstrap monitors
- Scrutiny: single NVMe with no RAID — this is your only early-warning system for drive failure
- Dockge: **path constraint** — the stacks directory must use the **same path inside and outside the container** (Dockge requirement). Mount the repo's `stacks/` directory using its absolute host path:

  ```yaml
  volumes:
    - /home/a-p-maita/homelab-config/stacks:/home/a-p-maita/homelab-config/stacks
  environment:
    - DOCKGE_STACKS_DIR=/home/a-p-maita/homelab-config/stacks
  ```

  Dockge treats each subdirectory as one stack and can only manage a single `compose.yaml` per stack.
  **Multi-file stacks** (`compose.db.yaml`, `compose.vpn.yaml`, `compose.override.yaml`) are not editable via the Dockge UI — use CLI / scripts for those.

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

| Service         | Image                                   | Internal Port | Host Port | Access          | Notes                                  |
| --------------- | --------------------------------------- | ------------- | --------- | --------------- | -------------------------------------- |
| `radarr`      | `lscr.io/linuxserver/radarr:latest`         | 7878          | 20056     | Tailscale       | Movies                                              |
| `sonarr`      | `lscr.io/linuxserver/sonarr:latest`         | 8989          | 20057     | Tailscale       | TV + anime                                          |
| `lidarr`      | `lscr.io/linuxserver/lidarr:latest`         | 8686          | 20058     | Tailscale       | Music                                               |
| `bazarr`      | `lscr.io/linuxserver/bazarr:latest`         | 6767          | 20059     | Tailscale       | Subtitles for Radarr/Sonarr                         |
| `shelfmark`   | `ghcr.io/calibrain/shelfmark:latest`        | 8084          | 20079     | Tailscale       | Manual book + audiobook search; Prowlarr + IRC + direct sources |
| `recyclarr`   | `ghcr.io/recyclarr/recyclarr:latest`        | —            | —        | None (cron job) | Quality profile sync from TRaSH Guides              |
| `maintainerr` | `ghcr.io/jorenn92/maintainerr:latest`       | 6246          | 20400     | Tailscale       | Library cleanup (replaces Cleanuparr)               |
| `unpackerr`   | `golift/unpackerr:latest`                   | —            | —        | None            | Archive extraction — no web UI                     |

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
  - ${CONFIG_ROOT}/shelfmark:/config
  - ${DATA_ROOT}/data/torrents/books:/books  # direct downloads land here
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
| `audiobookshelf` | `ghcr.io/advplyr/audiobookshelf:latest`  | 80            | 20020     | Domain + Tailscale | Audiobooks + podcasts                                                       |
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

---

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

| Service                     | Image                                                  | Internal Port | Host Port     | Access                | Notes                                                      |
| --------------------------- | ------------------------------------------------------ | ------------- | ------------- | --------------------- | ---------------------------------------------------------- |
| `immich-server`           | `ghcr.io/immich-app/immich-server:${IMMICH_VERSION}` | 2283          | 20450         | Domain + Tailscale    | **Never use Watchtower** — update manually via docs |
| `immich-machine-learning` | (same)                                                 | —            | —            | Internal              | **Disabled** — AMD Vega 7 has no ROCm; CPU too slow |
| `forgejo`                 | `codeberg.org/forgejo/forgejo:latest`                | 3000 / 22     | 20110 / 20111 | Domain + Tailscale    | Git server; SSH on 20111                                   |
| `paperless-ngx`           | `ghcr.io/paperless-ngx/paperless-ngx:latest`         | 8000          | 20301         | Domain +**2FA** | Documents; most sensitive data                             |
| `vaultwarden`             | `vaultwarden/server:latest`                          | 80            | 20315         | Domain                | Self-hosted Bitwarden — own auth + built-in 2FA (see note below) |
| `nextcloud`               | `nextcloud:stable-apache`                            | 80            | 20450         | Domain + Tailscale    | Cloud storage + Nextcloud Office (WASM)                    |

**Networks:** `homelab_net`, `cloud_internal` (DBs isolated)

**Immich upload size limit:** CF Tunnel does not support chunked upload reassembly (>~100MB uploads
silently fail). **Workaround:** use Tailscale (port 20450) for bulk photo imports from desktop/mobile.
CF domain access is fine for browsing and small uploads. This is an accepted tradeoff — tracked
upstream but classified as out-of-scope by the Immich team.

**Nextcloud proxy config:** Add to `config/www/html/config/config.php` (or via entrypoint env):

```php
'overwriteprotocol' => 'https',
'overwritehost' => 'nextcloud.andreasmaita.com',
'trusted_proxies' => ['caddy'],
```

Nextcloud handles large file uploads correctly through CF Tunnel (client-side TUS chunking protocol —
unlike Immich which requires server-side reassembly).

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

| Service                | Image                  | Purpose                 |
| ---------------------- | ---------------------- | ----------------------- |
| `paperless-postgres` | `postgres:16-alpine` | Paperless-ngx           |
| `paperless-redis`    | `redis:7-alpine`     | Paperless task queue    |
| `joplin-postgres`    | `postgres:16-alpine` | Joplin note sync server |

#### Applications (`compose.yaml`)

| Service           | Image                                    | Internal Port | Host Port | Access                | Notes                                          |
| ----------------- | ---------------------------------------- | ------------- | --------- | --------------------- | ---------------------------------------------- |
| `actual-budget` | `actualbudget/actual-server:latest`    | 5006          | 20350     | Domain + Tailscale    | Finance; no external auth needed (own auth)    |
| `mealie`        | `ghcr.io/mealie-recipes/mealie:latest` | 9000          | 20360     | Domain + Tailscale    | Recipe manager                                 |
| `joplin`        | `joplin/server:latest`                 | 22300         | 20370     | Domain + Tailscale    | Note sync server; clients connect to domain    |
| `stirling-pdf`  | `frooodle/s-pdf:latest`                | 8080          | 20380     | Domain +**2FA** | PDF tools; login enabled; disable signups      |
| `monica`        | `monica:latest`                        | 80            | 20390     | Tailscale             | Personal CRM; SQLite backend                   |
| `drawio`        | `jgraph/drawio:latest`                 | 8080          | 20401     | Tailscale             | Diagrams; no auth — local/Tailscale only      |
| `excalidraw`    | `excalidraw/excalidraw:latest`         | 80            | 20402     | Tailscale             | Whiteboard; no auth — local/Tailscale only    |
| `it-tools`      | `corentinth/it-tools:latest`           | 80            | 20403     | Tailscale             | Dev utilities; no auth — local/Tailscale only |

**Networks:** `homelab_net`, `services_internal` (DBs isolated)

---

## 5. Complete Port Allocation Table

All ports in the `20000–20499` range. No overlap with standard Linux services.

| Port  | Service                    | Stack          | Tailscale | Domain                               |
| ----- | -------------------------- | -------------- | --------- | ------------------------------------ |
| 20020 | Audiobookshelf             | media          | ✓        | `abs.andreasmaita.com`             |
| 20041 | Yamtrack                   | media          | ✓        | `yamtrack.andreasmaita.com`        |
| 20042 | Crosswatch                 | media          | ✓        | —                                   |
| 20050 | qBittorrent WebUI          | downloads      | ✓        | —                                   |
| 20051 | qBittorrent TCP            | downloads      | ✓        | —                                   |
| 20052 | qBittorrent UDP            | downloads      | ✓        | —                                   |
| 20055 | Prowlarr                   | downloads      | ✓        | —                                   |
| 20056 | Radarr                     | arr            | ✓        | —                                   |
| 20057 | Sonarr                     | arr            | ✓        | —                                   |
| 20058 | Lidarr                     | arr            | ✓        | —                                   |
| 20059 | Bazarr                     | arr            | ✓        | —                                   |
| 20070 | Navidrome                  | media          | ✓        | —                                   |
| 20074 | Autobrr                    | downloads      | ✓        | —                                   |
| 20077 | Komga                      | media          | ✓        | —                                   |
| 20078 | Calibre-Web                | media          | ✓        | —                                   |
| 20079 | Shelfmark                  | arr            | ✓        | —                                   |
| 20080 | Calibre*(optional)*      | media          | ✓        | —                                   |
| 20110 | Forgejo HTTP               | cloud          | ✓        | `git.andreasmaita.com`             |
| 20111 | Forgejo SSH                | cloud          | ✓        | —                                   |
| 20200 | Homepage                   | infrastructure | ✓        | `homepage.andreasmaita.com` + 2FA  |
| 20201 | Uptime Kuma                | monitoring     | ✓        | —                                   |
| 20202 | Dockge                     | monitoring     | ✓        | —                                   |
| 20210 | Scrutiny                   | monitoring     | ✓        | —                                   |
| 20280 | Cloudflared metrics        | infrastructure | —        | —                                   |
| 20300 | SABnzbd*(commented out)* | downloads      | ✓        | —                                   |
| 20301 | Paperless-ngx              | services       | ✓        | `paperless.andreasmaita.com` + 2FA |
| 20315 | Vaultwarden                | cloud          | ✓        | `vault.andreasmaita.com`           |
| 20330 | Jellyfin                   | media          | ✓        | `jellyfin.andreasmaita.com`        |
| 20331 | Seerr (Jellyseerr)         | media          | ✓        | `seerr.andreasmaita.com`           |
| 20340 | Home Assistant             | home           | ✓        | —                                   |
| 20350 | Actual Budget              | services       | ✓        | `budget.andreasmaita.com`          |
| 20360 | Mealie                     | services       | ✓        | `mealie.andreasmaita.com`          |
| 20370 | Joplin                     | services       | ✓        | `joplin.andreasmaita.com`          |
| 20380 | Stirling PDF               | services       | ✓        | `pdf.andreasmaita.com` + 2FA       |
| 20390 | Monica                     | services       | ✓        | —                                   |
| 20400 | Maintainerr                | arr            | ✓        | —                                   |
| 20401 | DrawIO                     | services       | ✓        | —                                   |
| 20402 | Excalidraw                 | services       | ✓        | —                                   |
| 20403 | IT-Tools                   | services       | ✓        | —                                   |
| 20450 | Immich                     | cloud          | ✓        | `immich.andreasmaita.com`          |
| 20460 | Nextcloud                  | cloud          | ✓        | `nextcloud.andreasmaita.com`       |

---

## 6. Data Layout

```
${DATA_ROOT}/               (set in .env, default: ~/homelab-data)
├── media/
│   ├── movies/             ← Radarr root folder
│   ├── tv/                 ← Sonarr root folder
│   ├── music/              ← Lidarr root folder + Navidrome library
│   ├── audiobooks/         ← Audiobookshelf library
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

| Route                          | Protection                                    |
| ------------------------------ | --------------------------------------------- |
| `auth.andreasmaita.com`      | None (it IS the auth portal)                  |
| `vault.andreasmaita.com`     | Authelia 2FA + Vaultwarden own login          |
| `paperless.andreasmaita.com` | Authelia 2FA + Paperless own login            |
| `pdf.andreasmaita.com`       | Authelia 2FA + Stirling PDF own login         |
| `immich.andreasmaita.com`    | Immich own login (Authelia breaks mobile app) |
| `jellyfin.andreasmaita.com`  | Jellyfin own login                            |
| `git.andreasmaita.com`       | Forgejo own login                             |
| `abs.andreasmaita.com`       | ABS own login                                 |
| `seerr.andreasmaita.com`     | Authelia one_factor                           |
| `yamtrack.andreasmaita.com`  | Authelia 2FA                                  |
| `homepage.andreasmaita.com`  | Authelia 2FA                                  |
| All other domains              | Authelia 2FA (default_policy: two_factor)     |

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

| Service                           | Reason                                                                              |
| --------------------------------- | ----------------------------------------------------------------------------------- |
| `jackett`                       | Prowlarr contains every indexer Jackett has; running both is redundant overhead     |
| `lazylibrarian`                 | Removed; Prowlarr's search tab + ABS built-in Online Sources cover manual discovery |
| `readarr`                       | User prefers manual search + Calibre-Web (reading) over automated Readarr           |
| `bookbounty`                    | Manual book requests handled via Prowlarr search tab directly                       |
| `audiobookbay-downloader`       | Audiobookshelf built-in Online Sources search replaces this custom script           |
| `profilarr`                     | Overlaps with Recyclarr; Recyclarr is more established (TRaSH Guides integration)   |
| `cleanuparr`                    | Maintainerr is more feature-complete for the same purpose                           |
| `crosswatch` *(reconsidered)* | Kept — provides cross-service watch sync Yamtrack doesn't do                       |
| `prometheus`                    | Heavyweight for single-server; removed with Grafana and node-exporter               |
| `grafana`                       | Removed with Prometheus stack                                                       |
| `node-exporter`                 | Removed with Prometheus stack                                                       |
| `feishin`                       | Removed per user request — Navidrome's own web UI is sufficient                    |
| `octo-fiesta`                   | Tested and not working well; removed                                                |
| `romm`                          | Removed — not in use                                                               |
| `wizarr`                        | Removed — no need for user invitation system (solo homelab)                        |
| `kiwix`                         | Removed — not in active use                                                        |
| `libreoffice`                   | Removed — replaced by Nextcloud Office (built-in WASM)                             |
| `youtarr`                       | Removed — not in use                                                               |
| `listenarr`                     | Removed — not in use                                                               |
| `monica`                        | Kept*(was on removal list; user confirmed keep)*                                  |

### Added (and why)

| Service                         | Reason                                                                                    |
| ------------------------------- | ----------------------------------------------------------------------------------------- |
| `nextcloud`                   | Google Drive/Docs replacement; cloud file storage + Nextcloud Office for document editing |
| `dockge`                      | Web-based stack manager — restart containers and update stacks without SSH               |
| `docker-socket-proxy`         | Security: limits Docker socket access for Homepage (read-only)                            |
| `sabnzbd` *(commented out)* | Usenet client placeholder — enable when a paid provider is subscribed                    |
| `shelfmark`                 | Unified manual book + audiobook search UI; replaces Bookbounty + LazyLibrarian; supports Prowlarr, IRC, Usenet, direct HTTP sources |
| `scrutiny-collector`          | Standalone NVMe health monitoring — retained despite removing Prometheus stack           |

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

**Multiple compose files per stack** is the correct Docker approach for separation of concerns:

- `compose.yaml` — core services (always applied)
- `compose.vpn.yaml` — VPN overlay (applied only when needed: `-f compose.yaml -f compose.vpn.yaml`)
- `compose.db.yaml` — databases isolated from app tier
- `compose.override.yaml` — auto-merged by Docker when present alongside `compose.yaml`

Docker Compose v2 auto-merges `compose.override.yaml` when both files share the same directory.
All other non-standard filenames require explicit `-f` flags, which is what the scripts do.

### Script Analysis & Replacement Candidates

| Script                   | Role                                  | Better alternative?                                                    |
| ------------------------ | ------------------------------------- | ---------------------------------------------------------------------- |
| `up-all.sh`            | Start all stacks                      | Dockge UI (single-file stacks only); keep script for multi-file stacks |
| `down-all.sh`          | Stop all stacks                       | Same as above                                                          |
| `restart-update-all.sh`| Pull images + restart all             | Watchtower (image updates, opt-in via labels); Dockge for manual restarts; **git pull + config sync steps must stay as script** |
| `compose-pull-all.sh`  | Pull images without restart           | Covered by Watchtower or Dockge; keep for manual use                   |
| `backup.sh`            | Restic snapshot                       | Restic IS the best practice — the shell wrapper is correct             |
| `backup-dbs.sh`        | Dump Postgres/SQLite DBs              | Standard pattern; no containerised replacement adds value               |
| `generate-secrets.sh`  | Generate `.env` secrets               | Fine as-is; self-hosted Infisical is overkill for a single-machine homelab |
| `setup-uptime-kuma.sh` | Bootstrap Uptime Kuma monitors via API | No better alternative for this automation approach                     |

**Conclusion:** Watchtower + Dockge replace the automated image-update and per-stack-restart
use cases. All multi-file-stack orchestration and one-time bootstrap scripts remain necessary.

---

## 10. Rebuild Phases

Execute in order. Each phase should be fully working before proceeding to the next.

### Phase 0 — Preparation & Data Migration

Since only **Audiobookshelf** and **Immich** data is worth migrating, do this before tearing down the current stack.

#### Data to migrate

| What | Current path | Why |
| ---- | ------------ | --- |
| ABS config + metadata | `data/audiobookshelf/config/` | Users, progress, library metadata |
| ABS metadata cache | `data/audiobookshelf/metadata/` | Cover art, podcasts cache |
| Audiobook media files | Wherever ABS currently points (check ABS → Settings → Libraries) | The actual audio files |
| Immich photos/videos | `data/immich_upload/` | library/, profile/, thumbs/, upload/, encoded-video/ |
| Immich database | Dump via `backup-dbs.sh` | All album/people/metadata — required for Immich restore |

#### Migration steps

**Option A — Same machine rebuild (data dirs stay put):**

If `DATA_ROOT` and `CONFIG_ROOT` in `.env` stay the same, the data survives the rebuild automatically. Just ensure the containers are stopped cleanly before `docker compose down` and the volumes point to the same host paths.

```bash
# 1. Dump databases BEFORE stopping anything
./scripts/backup-dbs.sh                     # creates backups/immich-YYYY-MM-DD.sql etc.

# 2. Stop only the containers whose data you care about
docker compose -p media stop audiobookshelf
docker compose -p cloud stop immich-server immich-machine-learning immich-postgres

# 3. Verify data dirs are intact before proceeding
ls -lh data/audiobookshelf/
ls -lh data/immich_upload/
```

**Option B — Different machine / path change:**

```bash
# 1. Dump Immich Postgres (immich_postgres container must be running)
docker exec immich-postgres pg_dumpall -U postgres > backups/immich-full-$(date +%F).sql

# 2. rsync ABS data (config + metadata + media)
rsync -avP data/audiobookshelf/ NEW_SERVER:/path/to/data/audiobookshelf/
rsync -avP /path/to/audiobook/media/ NEW_SERVER:/path/to/media/audiobooks/

# 3. rsync Immich upload directory
rsync -avP data/immich_upload/ NEW_SERVER:/path/to/data/immich_upload/

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

- [ ] Run `./scripts/backup-dbs.sh` — database dumps to `backups/`
- [ ] Run `./scripts/backup.sh` — full Restic backup
- [ ] Commit current config to git + push to GitHub
- [ ] Export Bitwarden vault as encrypted JSON (offline backup)
- [ ] Note all API keys currently in use (Radarr, Sonarr, Prowlarr etc.)
- [ ] Verify `data/audiobookshelf/` and `data/immich_upload/` are intact
- [ ] Create `homelab_net` bridge: `docker network create homelab_net`

### Phase 1 — Infrastructure Core

- [ ] Deploy `caddy-docker-proxy` (replace `caddy:2-alpine`)
- [ ] Deploy `cloudflared` with `TUNNEL_TOKEN`
- [ ] Verify CF Tunnel connects and caddy serves a test page
- [ ] Deploy `authelia` + `authelia-redis`
- [ ] Configure `users_database.yml` and `configuration.yml`
- [ ] Generate Authelia recovery codes — save immediately
- [ ] Verify `auth.andreasmaita.com` is reachable and 2FA works

### Phase 2 — Monitoring

- [ ] Deploy `uptime-kuma` (V2 image: `louislam/uptime-kuma:2`)
- [ ] Run `scripts/setup-uptime-kuma.sh` to bootstrap initial monitors
- [ ] Deploy `dockge` — verify stack management works
- [ ] Deploy `scrutiny` + `scrutiny-collector` — verify NVMe data appears
- [ ] Deploy `homepage` with Docker socket proxy

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

- [ ] Deploy `jellyfin` — configure VA-API, add media libraries
- [ ] Deploy `navidrome` — point at music library
- [ ] Deploy `audiobookshelf` — point at audiobooks + podcasts
- [ ] Deploy `calibre-web` — point at books library (requires `metadata.db`)
- [ ] Deploy `komga` — configure comics + manga libraries
- [ ] Deploy `seerr` — connect to Radarr + Sonarr
- [ ] Deploy `yamtrack` + `yamtrack-redis` — configure Trakt/AniList/Steam OAuth
- [ ] Deploy `crosswatch` — configure sync sources

### Phase 6 — Cloud Services

- [ ] Start cloud databases: `compose.db.yaml`
- [ ] Deploy `immich` — configure upload location, verify Tailscale upload works
- [ ] Deploy `forgejo` — disable registration after creating account
- [ ] Deploy `vaultwarden` — set `SIGNUPS_ALLOWED=false`, configure 2FA
- [ ] Migrate Bitwarden vault to Vaultwarden (test with one non-critical entry first)
- [ ] Deploy `nextcloud` + configure proxy trust, install Nextcloud Office app
- [ ] Deploy `paperless-ngx` — configure consumption directory

### Phase 7 — Home & Services

- [ ] Deploy `home-assistant` — complete onboarding wizard
- [ ] Deploy services databases: `compose.db.yaml`
- [ ] Deploy `actual-budget`, `mealie`, `joplin`, `stirling-pdf`
- [ ] Deploy `monica`, `drawio`, `excalidraw`, `it-tools`

### Phase 8 — Hardening & Final Config

- [ ] Disable signups/registration on all services (see Security Model above)
- [ ] Verify all Authelia 2FA routes are protected
- [ ] Verify Homepage shows all services via Docker labels
- [ ] Verify Uptime Kuma monitors are active; add any missing services manually
- [ ] Set up Restic backup cron: `0 3 * * * /path/to/scripts/backup.sh`
- [ ] Push final config to GitHub + Forgejo

### Phase 9 — SABnzbd (when provider is ready)

- [ ] Choose usenet provider (Frugal, Eweka, or Newshosting recommended — ~£3–5/month)
- [ ] Uncomment SABnzbd in `stacks/downloads/compose.yaml`
- [ ] Add newznab indexer in Prowlarr pointing at provider
- [ ] Configure SABnzbd as a download client in Radarr, Sonarr, Lidarr

---

## 11. Key Environment Variables

Variables needed in `.env` for the new setup (additions/changes from old setup):

```bash
# ─── New services ───────────────────────────────────────────────────
NEXTCLOUD_PORT=20460
NEXTCLOUD_DB_PASSWORD=                  # generate: openssl rand -hex 32
NEXTCLOUD_REDIS_PASSWORD=               # generate: openssl rand -hex 32
NEXTCLOUD_ADMIN_USER=a-p-maita
NEXTCLOUD_ADMIN_PASSWORD=               # set before first start

DOCKGE_PORT=20202
SCRUTINY_PORT=20210

SHELFMARK_PORT=20079

MAINTAINERR_PORT=20400
DRAWIO_PORT=20401
EXCALIDRAW_PORT=20402
IT_TOOLS_PORT=20403
MONICA_PORT=20390

# ─── Ports renamed/changed ──────────────────────────────────────────
PROWLARR_PORT=20055                     # was: default 9696
RADARR_PORT=20056                       # was: default 7878
SONARR_PORT=20057                       # was: default 8989
LIDARR_PORT=20058                       # was: default 8686
BAZARR_PORT=20059                       # was: default 6767
JELLYFIN_PORT=20330
SEERR_PORT=20331
NAVIDROME_PORT=20070
CALIBREWEB_PORT=20078
KOMGA_PORT=20077
FORGEJO_PORT=20110
FORGEJO_SSH_PORT=20111
PAPERLESS_PORT=20301
VAULTWARDEN_PORT=20315
IMMICH_PORT=20450
UPTIME_KUMA_PORT=20201
HOME_ASSISTANT_PORT=20340
ACTUAL_BUDGET_PORT=20350
MEALIE_PORT=20360
JOPLIN_PORT=20370
STIRLING_PDF_PORT=20380

# ─── SABnzbd (placeholder — uncomment when provider ready) ──────────
# SABNZBD_PORT=20300
# SABNZBD_API_KEY=
```
