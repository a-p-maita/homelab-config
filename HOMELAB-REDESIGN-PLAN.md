# Homelab Redesign Plan

> **Status**: Finalised (updated with TechHutTV best practices). Awaiting implementation approval.
> **Scope**: \*arr stack integration, directory restructure, optional Gluetun VPN, audiobookshelf podcast fix.

---

## Confirmed Decisions

| Decision              | Choice                                                                                                                     |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Prowlarr vs Jackett   | **Both**: Prowlarr for \*arr apps, Jackett kept for audiobookbay-downloader                                                |
| Readarr               | **Yes** — ebooks (epub/mobi/pdf), separate from audiobookbay-downloader audiobooks                                         |
| Bazarr                | **No**                                                                                                                     |
| VPN                   | ProtonVPN WireGuard via Gluetun. User has account and can generate WireGuard key.                                          |
| Arr access            | **Tailscale only** — no Cloudflare tunnel entries for arr services                                                         |
| Data layout           | **Flat under `homelab-data/`** — `homelab-data/torrents/` and `homelab-data/media/` directly (no intermediate `data/` dir) |
| Futureproofing        | **`DATA_ROOT` env var** — absolute path in `.env`, change one line for any new server                                      |
| qbittorrent-downloads | **Empty — remove entirely.** Follow guide.md optimal layout from scratch.                                                  |

---

## Section 1 — DATA_ROOT: Futureproof Path Strategy

A single variable in `.env` controls where all media/download data lives:

```bash
# .env
# Absolute path to media+download data root. Change this on server migration.
# On this server: /home/a-p-maita/homelab-config/homelab-data
DATA_ROOT=/home/a-p-maita/homelab-config/homelab-data
```

- Service **config** directories use relative paths (e.g. `../../homelab-data/radarr/config:/config`) — they are small and always live next to the repo.
- Media and download **data** directories use `${DATA_ROOT}` — so moving the media data to a new drive or new server is one variable change.
- Docker Compose interpolates `${DATA_ROOT}` at runtime from `--env-file .env`.

---

## Section 2 — Directory Structure

### Final layout under `homelab-data/`

```
homelab-data/                                ← DATA_ROOT points here (absolute path in .env)
│
├── torrents/                                ← qBittorrent download root
│   ├── movies/                              ← Radarr download category
│   ├── tv/                                  ← Sonarr download category
│   ├── music/                               ← Lidarr download category
│   └── books/                               ← Readarr download category
│
├── media/                                   ← Library root (what Jellyfin/ABS/Navidrome serve)
│   ├── audiobooks/    ← migrated from homelab-data/audiobooks/ (mv, instant rename)
│   ├── podcasts/      ← migrated from homelab-data/podcasts/   (mv, instant rename)
│   ├── music/         ← migrated from homelab-data/music/      (mv, instant rename)
│   ├── movies/        ← new (Radarr imports here)
│   ├── tv/            ← new (Sonarr imports here)
│   └── books/         ← new (Readarr imports here)
│
├── [all existing service config dirs — unchanged]
│   audiobookshelf/config, audiobookshelf/metadata
│   qbittorrent/config         (updated templates)
│   jackett/config
│   prowlarr/config            ← new
│   radarr/config              ← new
│   sonarr/config              ← new
│   lidarr/config              (moved to arr stack, dir unchanged)
│   readarr/config             ← new
│   gluetun/                   ← new (VPN state / forwarded_port file)
│   ...all others unchanged
```

### Container path mapping (guide.md compliance)

| Host path                       | Container path   | Who uses it                                      |
| ------------------------------- | ---------------- | ------------------------------------------------ |
| `${DATA_ROOT}`                  | `/data`          | All \*arr apps + qBittorrent (enables hardlinks) |
| `${DATA_ROOT}/media/audiobooks` | `/audiobooks`    | Audiobookshelf                                   |
| `${DATA_ROOT}/media/podcasts`   | `/podcasts`      | Audiobookshelf                                   |
| `${DATA_ROOT}/media/music`      | `/music:ro`      | Navidrome                                        |
| `${DATA_ROOT}/media/music`      | `/app/downloads` | Octo-Fiesta                                      |
| `${DATA_ROOT}/media/movies`     | `/data/movies`   | Jellyfin                                         |
| `${DATA_ROOT}/media/tv`         | `/data/tv`       | Jellyfin                                         |

### Migration notes

- `audiobooks/`, `music/`, `podcasts/` → `mv` to `media/` subdirs. Instant rename (same filesystem).
- `qbittorrent-downloads/` → **empty, can be deleted safely**.
- Audiobookshelf: container path `/audiobooks` and `/podcasts` are unchanged → **no library reconfiguration**.
- Navidrome: container path `/music` is unchanged → **trigger rescan only**.
- Lidarr: root folder changes `/music` → `/data/media/music` → **update via Lidarr UI once** (FIRST-RUN.md).

---

## Section 3 — Audiobookshelf Podcast Fix

### Root cause

Audiobookshelf (image: `ghcr.io/advplyr/audiobookshelf`) runs internally as the `node` user (UID 1000 by default). The podcast library requires **write access** to the `/podcasts` mount for episode downloads. The current compose sets **no `PUID`/`PGID`**, so if the host directory `homelab-data/podcasts/` is not owned by UID 1000, downloads silently fail to persist — the episode appears to download in the UI (in-memory), but the file is never written to the volume. After restart, ABS's database references an episode that doesn't exist on disk → "broken".

**Audiobooks work fine** because they are placed in the volume by the user (owned by the host user, world-readable) and ABS only needs to **read** them during scan. Podcasts fail because ABS needs to **write** new episode files.

### Fix

Add `PUID` and `PGID` to the audiobookshelf service environment so it runs as the correct host user. Also add a `chown` step in `up-all.sh` for the media directories.

**Change to `dockerfiles/media/compose.yaml` — audiobookshelf service:**

```yaml
audiobookshelf:
 image: ghcr.io/advplyr/audiobookshelf:latest
 container_name: audiobookshelf
 environment:
  - PUID=${PUID} # ← ADD: ensures container writes as host user
  - PGID=${PGID} # ← ADD: ensures container writes as host user
  - TZ=Europe/London
 ports:
  - "${ABS_PORT}:80"
 volumes:
  - ../../homelab-data/audiobookshelf/config:/config
  - ../../homelab-data/audiobookshelf/metadata:/metadata
  - ${DATA_ROOT}/media/audiobooks:/audiobooks # ← path updated
  - ${DATA_ROOT}/media/podcasts:/podcasts # ← path updated (WRITE access now works)
```

**Change to `scripts/up-all.sh` — after `mkdir -p` block:**

```bash
# Read DATA_ROOT from .env for directory setup
DATA_ROOT=$(grep -E '^DATA_ROOT=' .env | head -1 | cut -d= -f2- | sed "s/^['\"]//; s/['\"]$//")
DATA_ROOT="${DATA_ROOT:-$(pwd)/homelab-data}"
PUID=$(grep -E '^PUID=' .env | head -1 | cut -d= -f2-)
PGID=$(grep -E '^PGID=' .env | head -1 | cut -d= -f2-)

# Ensure ABS media dirs are owned by the correct user (fixes podcast download persistence)
# ABS writes podcast episode files here; must be writable by PUID:PGID
chown -R "${PUID:-1000}:${PGID:-1000}" "${DATA_ROOT}/media/audiobooks" 2>/dev/null || \
  echo "Note: Could not chown audiobooks dir. Run: sudo chown -R ${PUID:-1000}:${PGID:-1000} ${DATA_ROOT}/media/audiobooks"
chown -R "${PUID:-1000}:${PGID:-1000}" "${DATA_ROOT}/media/podcasts" 2>/dev/null || \
  echo "Note: Could not chown podcasts dir. Run: sudo chown -R ${PUID:-1000}:${PGID:-1000} ${DATA_ROOT}/media/podcasts"
```

---

## Section 4 — New File: `dockerfiles/arr/compose.yaml`

All download automation services consolidated into a single stack.

```yaml
name: arr

# ─────────────────────────────────────────────────────────────────────────────
# Arr stack: download automation (*arr apps + download clients + indexers)
#
# ⚠️  TAILSCALE / LOCAL ACCESS ONLY — do NOT add these to the Cloudflare tunnel.
#
# Service startup order:
#   qbittorrent → (base)
#   jackett     → (base)
#   prowlarr    → (base)
#   radarr      → depends_on: qbittorrent (healthy)
#   sonarr      → depends_on: qbittorrent (healthy)
#   lidarr      → depends_on: qbittorrent (healthy), jackett (healthy)
#   readarr     → depends_on: qbittorrent (healthy)
#   audiobookbay-downloader → depends_on: qbittorrent (healthy), jackett (healthy)
#
# VPN (optional): bring up with compose.vpn.yaml overlay:
#   USE_VPN=true in .env  → scripts/up-all.sh handles automatically
#   Manual: docker compose -f dockerfiles/arr/compose.yaml -f dockerfiles/arr/compose.vpn.yaml up -d
#
# Paths: all *arr apps and qbittorrent mount ${DATA_ROOT}:/data
#   qBittorrent categories → /data/torrents/{movies,tv,music,books}
#   *arr root folders      → /data/media/{movies,tv,music,books}
#   abb-downloader         → qBittorrent category "abb-downloader" → /data/media/audiobooks
# ─────────────────────────────────────────────────────────────────────────────

services:
 # ── qBittorrent ─────────────────────────────────────────────────────────────
 # ⚠️  FIRST RUN STEPS (see FIRST-RUN.md):
 #   1. Enable "Bypass authentication for clients on localhost" (required for VPN port-sync)
 #   2. Default save path → /data/torrents
 #   3. Seed categories.json is pre-seeded via up-all.sh from config-templates/qbittorrent/
 qbittorrent:
  image: lscr.io/linuxserver/qbittorrent:latest
  container_name: qbittorrent
  environment:
   - PUID=${PUID}
   - PGID=${PGID}
   - TZ=Europe/London
   - WEBUI_PORT=${QBITTORRENT_WEBUI_PORT}
   - TORRENTING_PORT=${QBITTORRENT_TCP_PORT}
   - WEBUI_ADDRESS=0.0.0.0
   - WEBUI_USERNAME=${QBITTORRENT_WEBUI_USER}
  volumes:
   - ../../homelab-data/qbittorrent/config:/config
   - ${DATA_ROOT}:/data
  ports:
   - "${QBITTORRENT_WEBUI_PORT}:${QBITTORRENT_WEBUI_PORT}"
   - "${QBITTORRENT_TCP_PORT}:${QBITTORRENT_TCP_PORT}"
   - "${QBITTORRENT_UDP_PORT}:${QBITTORRENT_UDP_PORT}/udp"
  restart: unless-stopped
  networks:
   - homelab_net
  healthcheck:
   test: ["CMD", "curl", "-f", "http://localhost:${QBITTORRENT_WEBUI_PORT}"]
   interval: 1m
   timeout: 10s
   retries: 3
   start_period: 30s
  deploy:
   resources:
    limits:
     cpus: "1.0"
     memory: 1G
    reservations:
     cpus: "0.25"
     memory: 256M

 # ── Jackett ─────────────────────────────────────────────────────────────────
 # Kept for audiobookbay-downloader which uses Jackett's API format directly.
 # Prowlarr handles indexers for all *arr apps.
 jackett:
  image: lscr.io/linuxserver/jackett:latest
  container_name: jackett
  environment:
   - PUID=${PUID}
   - PGID=${PGID}
   - TZ=Europe/London
   - AUTO_UPDATE=true
  volumes:
   - ../../homelab-data/jackett/config:/config
   - ../../homelab-data/jackett/downloads:/downloads
  ports:
   - "${JACKETT_PORT}:9117"
  restart: unless-stopped
  networks:
   - homelab_net
  healthcheck:
   test: ["CMD", "curl", "-f", "http://localhost:9117"]
   interval: 1m
   timeout: 10s
   retries: 3
   start_period: 60s
  deploy:
   resources:
    limits:
     cpus: "0.5"
     memory: 256M
    reservations:
     cpus: "0.05"
     memory: 128M

 # ── Prowlarr ─────────────────────────────────────────────────────────────────
 # Indexer manager. Add indexers here; Prowlarr syncs them to Radarr/Sonarr/Lidarr/Readarr.
 # First run: Settings → Apps → Add each *arr app.
 prowlarr:
  image: lscr.io/linuxserver/prowlarr:latest
  container_name: prowlarr
  environment:
   - PUID=${PUID}
   - PGID=${PGID}
   - TZ=Europe/London
  volumes:
   - ../../homelab-data/prowlarr/config:/config
  ports:
   - "${PROWLARR_PORT}:9696"
  restart: unless-stopped
  networks:
   - homelab_net
  healthcheck:
   test: ["CMD", "curl", "-f", "http://localhost:9696/ping"]
   interval: 1m
   timeout: 10s
   retries: 3
   start_period: 60s
  deploy:
   resources:
    limits:
     cpus: "0.5"
     memory: 256M
    reservations:
     cpus: "0.05"
     memory: 128M

 # ── Radarr ───────────────────────────────────────────────────────────────────
 # Movies: root folder /data/media/movies, download client path /data/torrents/movies
 radarr:
  image: lscr.io/linuxserver/radarr:latest
  container_name: radarr
  environment:
   - PUID=${PUID}
   - PGID=${PGID}
   - TZ=Europe/London
  volumes:
   - ../../homelab-data/radarr/config:/config
   - ${DATA_ROOT}:/data
  ports:
   - "${RADARR_PORT}:7878"
  restart: unless-stopped
  networks:
   - homelab_net
  depends_on:
   qbittorrent:
    condition: service_healthy
  healthcheck:
   test: ["CMD", "curl", "-f", "http://localhost:7878/ping"]
   interval: 1m
   timeout: 10s
   retries: 3
   start_period: 60s
  deploy:
   resources:
    limits:
     cpus: "1.0"
     memory: 512M
    reservations:
     cpus: "0.1"
     memory: 128M

 # ── Sonarr ───────────────────────────────────────────────────────────────────
 # TV shows: root folder /data/media/tv, download client path /data/torrents/tv
 sonarr:
  image: lscr.io/linuxserver/sonarr:latest
  container_name: sonarr
  environment:
   - PUID=${PUID}
   - PGID=${PGID}
   - TZ=Europe/London
  volumes:
   - ../../homelab-data/sonarr/config:/config
   - ${DATA_ROOT}:/data
  ports:
   - "${SONARR_PORT}:8989"
  restart: unless-stopped
  networks:
   - homelab_net
  depends_on:
   qbittorrent:
    condition: service_healthy
  healthcheck:
   test: ["CMD", "curl", "-f", "http://localhost:8989/ping"]
   interval: 1m
   timeout: 10s
   retries: 3
   start_period: 60s
  deploy:
   resources:
    limits:
     cpus: "1.0"
     memory: 512M
    reservations:
     cpus: "0.1"
     memory: 128M

 # ── Lidarr ───────────────────────────────────────────────────────────────────
 # Music: root folder /data/media/music, download client path /data/torrents/music
 # ⚠️  FIRST RUN: update root folder in Lidarr UI from /music → /data/media/music
 lidarr:
  image: lscr.io/linuxserver/lidarr:latest
  container_name: lidarr
  environment:
   - PUID=${PUID}
   - PGID=${PGID}
   - TZ=Europe/London
  volumes:
   - ../../homelab-data/lidarr/config:/config
   - ${DATA_ROOT}:/data
  ports:
   - "${LIDARR_PORT}:8686"
  restart: unless-stopped
  networks:
   - homelab_net
  depends_on:
   qbittorrent:
    condition: service_healthy
  # Note: Lidarr uses Prowlarr for indexers in this setup (not Jackett directly)
  healthcheck:
   test: ["CMD", "curl", "-f", "http://localhost:8686/ping"]
   interval: 1m
   timeout: 10s
   retries: 3
   start_period: 60s
  deploy:
   resources:
    limits:
     cpus: "1.0"
     memory: 512M
    reservations:
     cpus: "0.1"
     memory: 128M

 # ── Readarr ──────────────────────────────────────────────────────────────────
 # Ebooks (epub/mobi/pdf): root folder /data/media/books, download path /data/torrents/books
 # Note: Readarr uses the 'develop' branch — it has no stable release yet; develop is stable for daily use.
 readarr:
  image: lscr.io/linuxserver/readarr:develop
  container_name: readarr
  environment:
   - PUID=${PUID}
   - PGID=${PGID}
   - TZ=Europe/London
  volumes:
   - ../../homelab-data/readarr/config:/config
   - ${DATA_ROOT}:/data
  ports:
   - "${READARR_PORT}:8787"
  restart: unless-stopped
  networks:
   - homelab_net
  depends_on:
   qbittorrent:
    condition: service_healthy
  healthcheck:
   test: ["CMD", "curl", "-f", "http://localhost:8787/ping"]
   interval: 1m
   timeout: 10s
   retries: 3
   start_period: 60s
  deploy:
   resources:
    limits:
     cpus: "0.5"
     memory: 512M
    reservations:
     cpus: "0.1"
     memory: 128M

 # ── Audiobookbay Downloader ──────────────────────────────────────────────────
 # Downloads audiobooks via Jackett → qBittorrent, category "abb-downloader"
 # qBittorrent saves abb-downloader category directly to /data/media/audiobooks
 # (no *arr import step needed — files ARE the final library files)
 audiobookbay-downloader:
  image: ghcr.io/moonblade/audiobookbay-downloader:latest
  ports:
   - "${ABB_PORT}:9000"
  container_name: audiobookbay-downloader
  depends_on:
   qbittorrent:
    condition: service_healthy
   jackett:
    condition: service_healthy
  environment:
   - JACKETT_API_URL=http://jackett:9117/api/v2.0/indexers/audiobookbay/results
   - JACKETT_API_KEY=${JACKETT_API_KEY}
   - TORRENT_CLIENT_TYPE=qbittorrent
   - QBITTORRENT_URL=http://qbittorrent:${QBITTORRENT_WEBUI_PORT}
   - QBITTORRENT_USERNAME=${QBITTORRENT_WEBUI_USER}
   - QBITTORRENT_PASSWORD=${QBITTORRENT_WEBUI_PASS}
   # This category's save path in qBittorrent is /data/media/audiobooks
   - QBITTORRENT_CATEGORY=abb-downloader
   - DB_PATH=/app/data
   - DELETE_AFTER_DAYS=365
   - STRICTLY_DELETE_AFTER_DAYS=365
  volumes:
   - ../../homelab-data/audiobookbay-downloader:/app/data
  restart: unless-stopped
  healthcheck:
   test:
    [
     "CMD-SHELL",
     'python3 -c "import urllib.request; urllib.request.urlopen(''http://localhost:9000'')"',
    ]
   interval: 1m
   timeout: 10s
   retries: 3
   start_period: 30s
  networks:
   - homelab_net
  deploy:
   resources:
    limits:
     cpus: "0.25"
     memory: 256M
    reservations:
     cpus: "0.05"
     memory: 128M

 # ── FlareSolverr (optional — uncomment to enable) ────────────────────────────
 # Bypasses Cloudflare-protected torrent index pages for Prowlarr.
 # After enabling: Prowlarr → Settings → Indexers → FlareSolverr → host: http://flaresolverr:8191
 # Runs on the real IP (NOT through VPN) — Cloudflare challenges require a real browser fingerprint.
 # Reference: https://github.com/FlareSolverr/FlareSolverr
 # flaresolverr:
 #  image: ghcr.io/flaresolverr/flaresolverr:latest
 #  container_name: flaresolverr
 #  environment:
 #   - LOG_LEVEL=${LOG_LEVEL:-info}
 #   - TZ=Europe/London
 #  ports:
 #   - "20084:8191"   # internal only — no Tailscale/Cloudflare exposure needed
 #  restart: unless-stopped
 #  networks:
 #   - homelab_net

networks:
 homelab_net:
  external: true
```

---

## Section 5 — New File: `dockerfiles/arr/compose.vpn.yaml`

Override file for optional Gluetun/ProtonVPN. Used only when `USE_VPN=true` in `.env`.

```yaml
# VPN overlay for the arr stack.
# Usage: applied automatically by up-all.sh when USE_VPN=true
# Manual: docker compose -f dockerfiles/arr/compose.yaml -f dockerfiles/arr/compose.vpn.yaml up -d
#
# Architecture:
#   gluetun gets alias "qbittorrent" on homelab_net.
#   qbittorrent joins gluetun's network namespace (no separate homelab_net attachment).
#   All *arr apps reach qBittorrent at http://qbittorrent:PORT — same URL in both VPN and non-VPN mode.
#   Port forwarding: gluetun writes the ProtonVPN-assigned port to /tmp/gluetun/forwarded_port,
#   then calls scripts/update-qbt-port.sh to update qBittorrent's listen port via its Web API.

services:
 gluetun:
  image: qmcgaw/gluetun:latest
  container_name: gluetun
  cap_add:
   - NET_ADMIN
  devices:
   - /dev/net/tun:/dev/net/tun
  environment:
   - VPN_SERVICE_PROVIDER=protonvpn
   - VPN_TYPE=wireguard
   - WIREGUARD_PRIVATE_KEY=${PROTONVPN_WIREGUARD_PRIVATE_KEY}
   - SERVER_COUNTRIES=${PROTONVPN_SERVER_COUNTRIES:-Netherlands}
   # Only use P2P-capable servers (required for port forwarding)
   - PORT_FORWARD_ONLY=on
   - VPN_PORT_FORWARDING=on
   - VPN_PORT_FORWARDING_PROVIDER=protonvpn
   - VPN_PORT_FORWARDING_STATUS_FILE=/tmp/gluetun/forwarded_port
   # Runs inside the gluetun container when the forwarded port changes
   # qBittorrent shares this container's network namespace → localhost works
   - VPN_PORT_FORWARDING_UP_COMMAND=/bin/sh /scripts/update-qbt-port.sh
   # Allow traffic to Docker bridge subnets so *arr apps can reach gluetun's alias
   - FIREWALL_OUTBOUND_SUBNETS=172.16.0.0/12,192.168.0.0/16
   - HTTPPROXY=off
   - SHADOWSOCKS=off
   # Give the VPN 2 minutes to connect before health checks start failing on startup
   - HEALTH_VPN_DURATION_INITIAL=${HEALTH_VPN_DURATION_INITIAL:-120s}
   # Passed through so update-qbt-port.sh knows qBittorrent's WebUI port
   - QBITTORRENT_WEBUI_PORT=${QBITTORRENT_WEBUI_PORT}
  ports:
   # Gluetun owns qBittorrent's ports — qbt is in this namespace
   - "${QBITTORRENT_WEBUI_PORT}:${QBITTORRENT_WEBUI_PORT}"
   - "${QBITTORRENT_TCP_PORT}:${QBITTORRENT_TCP_PORT}"
   - "${QBITTORRENT_UDP_PORT}:${QBITTORRENT_UDP_PORT}/udp"
  volumes:
   - ../../homelab-data/gluetun:/tmp/gluetun
   - ../../scripts/update-qbt-port.sh:/scripts/update-qbt-port.sh:ro
  networks:
   homelab_net:
    aliases:
     - qbittorrent # ← *arr apps use http://qbittorrent:PORT in both VPN and non-VPN mode
  restart: unless-stopped
  healthcheck:
   test:
    [
     "CMD-SHELL",
     'wget -qO- http://localhost:8000/v1/publicip/ip | grep -qE ''"public_ip"''',
    ]
   interval: 30s
   timeout: 10s
   retries: 5
   start_period: 120s # match HEALTH_VPN_DURATION_INITIAL — VPN needs up to 2 min to connect
  deploy:
   resources:
    limits:
     cpus: "0.5"
     memory: 256M
    reservations:
     cpus: "0.05"
     memory: 64M

 qbittorrent:
  # In VPN mode: join gluetun's network namespace instead of homelab_net
  network_mode: "service:gluetun"
  labels:
   - deunhealth.restart.on.unhealthy=true # deunhealth auto-restarts qbt when VPN stalls
  depends_on:
   gluetun:
    condition: service_healthy
    restart: true # if gluetun restarts and becomes healthy again, restart qbt too
  # Override healthcheck: test real internet connectivity via the VPN tunnel.
  # qBittorrent shares gluetun's network namespace, so it routes through the VPN.
  # If the VPN tunnel drops, this fails → deunhealth catches it and restarts qbt.
  healthcheck:
   test: ["CMD-SHELL", "ping -c 1 -W 5 1.1.1.1 || exit 1"]
   interval: 60s
   timeout: 10s
   retries: 3
   start_period: 30s
  # The ports defined in compose.yaml are ignored when network_mode is set;
  # gluetun publishes them above.

 # ── deunhealth ───────────────────────────────────────────────────────────────
 # Watches containers labelled 'deunhealth.restart.on.unhealthy=true' and restarts
 # them automatically when they become unhealthy. This solves the classic
 # "qBittorrent stalls after VPN timeout" problem without manual intervention.
 # Reference: https://github.com/qdm12/deunhealth
 # Intentionally no network access — only needs the Docker socket.
 deunhealth:
  image: qmcgaw/deunhealth:latest
  container_name: deunhealth
  network_mode: "none"
  environment:
   - LOG_LEVEL=info
   - HEALTH_SERVER_ADDRESS=127.0.0.1:9999
   - TZ=Europe/London
  volumes:
   - /var/run/docker.sock:/var/run/docker.sock
  restart: always

networks:
 homelab_net:
  external: true
```

---

## Section 6 — New File: `scripts/update-qbt-port.sh`

Runs inside the Gluetun container when ProtonVPN assigns a new forwarded port. Updates qBittorrent's listen port via its Web API.

```bash
#!/bin/sh
# Called by Gluetun via VPN_PORT_FORWARDING_UP_COMMAND when the forwarded port changes.
# qBittorrent shares gluetun's network namespace → localhost works for the API call.
#
# PREREQUISITE: qBittorrent → Tools → Options → Web UI →
#               ☑ "Bypass authentication for clients on localhost"
#               This is safe: only processes in gluetun's namespace have localhost access.

PORT=$(cat /tmp/gluetun/forwarded_port 2>/dev/null | tr -d '[:space:]')
if [ -z "$PORT" ] || [ "$PORT" = "0" ]; then
  echo "[port-sync] No valid forwarded port in status file, skipping"
  exit 0
fi

echo "[port-sync] ProtonVPN forwarded port: $PORT — updating qBittorrent listen port"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "http://localhost:${QBITTORRENT_WEBUI_PORT}/api/v2/app/setPreferences" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "json={\"listen_port\":${PORT}}")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "[port-sync] Success — qBittorrent now listens on port $PORT"
else
  echo "[port-sync] Failed (HTTP $HTTP_STATUS)"
  echo "[port-sync] Ensure 'Bypass auth for localhost' is enabled in qBittorrent Web UI settings"
  exit 1
fi
```

---

## Section 7 — Modified: `dockerfiles/media/compose.yaml`

### Services REMOVED (moved to arr stack)

- `qbittorrent`, `jackett`, `audiobookbay-downloader`, `lidarr`

### Services REMAINING

`audiobookshelf`, `yamtrack`, `yamtrack-redis`, `navidrome`, `feishin`, `octo-fiesta`, `crosswatch`

### Volume path changes + podcast fix

```yaml
audiobookshelf:
 image: ghcr.io/advplyr/audiobookshelf:latest
 container_name: audiobookshelf
 environment:
  - PUID=${PUID} # ← NEW: fixes podcast download persistence
  - PGID=${PGID} # ← NEW: ensures write access to /podcasts volume
  - TZ=Europe/London
 ports:
  - "${ABS_PORT}:80"
 volumes:
  - ../../homelab-data/audiobookshelf/config:/config
  - ../../homelab-data/audiobookshelf/metadata:/metadata
  - ${DATA_ROOT}/media/audiobooks:/audiobooks # ← updated host path (container path unchanged)
  - ${DATA_ROOT}/media/podcasts:/podcasts # ← updated host path (container path unchanged)
 # ... (rest unchanged)

navidrome:
 # ...
 volumes:
  - ../../homelab-data/navidrome/data:/data
  - ${DATA_ROOT}/media/music:/music:ro # ← updated host path (container path unchanged)

octo-fiesta:
 # ...
 volumes:
  - ${DATA_ROOT}/media/music:/app/downloads # ← updated host path (container path unchanged)
```

---

## Section 8 — Modified: `dockerfiles/entertainment/compose.yaml`

Add media library mounts to Jellyfin. User configures libraries via wizard (paths `/data/movies`, `/data/tv`).

```yaml
jellyfin:
 # ...
 volumes:
  - ../../homelab-data/jellyfin/config:/config
  - ../../homelab-data/jellyfin/cache:/cache
  - ${DATA_ROOT}/media/movies:/data/movies:ro # ← NEW
  - ${DATA_ROOT}/media/tv:/data/tv:ro # ← NEW
  # Optional: - ${DATA_ROOT}/media/music:/data/music:ro
```

---

## Section 9 — Modified: `.env`

### New variables to add

```bash
# ─── Data root (absolute path — change this for server migrations) ─────────────
DATA_ROOT=/home/a-p-maita/homelab-config/homelab-data

# ─── *arr stack ──────────────────────────────────────────────────────────────
PROWLARR_PORT=20083
RADARR_PORT=20080
SONARR_PORT=20081
READARR_PORT=20082

# ─── Gluetun / ProtonVPN (optional — set USE_VPN=true to activate) ────────────
USE_VPN=false
# Get from: account.proton.me/u/0/vpn/WireGuard → Generate → copy PrivateKey value
PROTONVPN_WIREGUARD_PRIVATE_KEY=
# Comma-separated countries. ProtonVPN P2P servers: Netherlands, Switzerland, Iceland, etc.
PROTONVPN_SERVER_COUNTRIES=Netherlands
# Gluetun startup grace period: VPN has 2 minutes to connect before health checks run.
# Prevents false "unhealthy" on slow ProtonVPN handshakes.
HEALTH_VPN_DURATION_INITIAL=120s
```

### Port summary (no conflicts)

| Port  | Variable                 | Service                 |
| ----- | ------------------------ | ----------------------- |
| 20050 | `QBITTORRENT_WEBUI_PORT` | qBittorrent WebUI       |
| 20051 | `QBITTORRENT_TCP_PORT`   | qBittorrent TCP         |
| 20052 | `QBITTORRENT_UDP_PORT`   | qBittorrent UDP         |
| 20060 | `ABB_PORT`               | audiobookbay-downloader |
| 20065 | `JACKETT_PORT`           | Jackett                 |
| 20073 | `LIDARR_PORT`            | Lidarr                  |
| 20080 | `RADARR_PORT`            | Radarr (new)            |
| 20081 | `SONARR_PORT`            | Sonarr (new)            |
| 20082 | `READARR_PORT`           | Readarr (new)           |
| 20083 | `PROWLARR_PORT`          | Prowlarr (new)          |

---

## Section 10 — New File: `.env.example`

Sanitised template with all secrets replaced by `changeme_*` placeholders. Tracked by git (`.env` is gitignored). Every variable documented with a comment explaining its purpose and how to obtain/generate its value.

---

## Section 11 — Modified: `scripts/up-all.sh`

### Key changes (in order)

1. **Read DATA_ROOT + PUID/PGID from .env** (before mkdir block):

   ```bash
   DATA_ROOT=$(grep -E '^DATA_ROOT=' .env | head -1 | cut -d= -f2- | sed "s/^['\"]//; s/['\"]$//")
   DATA_ROOT="${DATA_ROOT:-$(pwd)/homelab-data}"
   PUID=$(grep -E '^PUID=' .env | head -1 | cut -d= -f2-)
   PGID=$(grep -E '^PGID=' .env | head -1 | cut -d= -f2-)
   ```

2. **Migrate old directories** (one-time, idempotent):

   ```bash
   # Migrate audiobooks
   if [ -d "./homelab-data/audiobooks" ] && [ ! -L "./homelab-data/audiobooks" ]; then
     mkdir -p "${DATA_ROOT}/media/audiobooks"
     if [ "$(ls -A ./homelab-data/audiobooks 2>/dev/null)" ]; then
       mv ./homelab-data/audiobooks/* "${DATA_ROOT}/media/audiobooks/" 2>/dev/null || true
     fi
     rmdir ./homelab-data/audiobooks 2>/dev/null || true
     echo "Migrated homelab-data/audiobooks → ${DATA_ROOT}/media/audiobooks"
   fi
   # Same pattern for music → media/music, podcasts → media/podcasts

   # Remove empty qbittorrent-downloads dir (deprecated — no data in it)
   rmdir ./homelab-data/qbittorrent-downloads 2>/dev/null || true
   ```

3. **Updated `mkdir -p` block** — new dirs, removed old:

   ```bash
   mkdir -p \
     "${DATA_ROOT}/torrents/movies" \
     "${DATA_ROOT}/torrents/tv" \
     "${DATA_ROOT}/torrents/music" \
     "${DATA_ROOT}/torrents/books" \
     "${DATA_ROOT}/media/audiobooks" \
     "${DATA_ROOT}/media/podcasts" \
     "${DATA_ROOT}/media/music" \
     "${DATA_ROOT}/media/movies" \
     "${DATA_ROOT}/media/tv" \
     "${DATA_ROOT}/media/books" \
     ./homelab-data/prowlarr/config \
     ./homelab-data/radarr/config \
     ./homelab-data/sonarr/config \
     ./homelab-data/readarr/config \
     ./homelab-data/gluetun \
     # ... all existing dirs (remove: audiobooks, music, podcasts, qbittorrent-downloads)
   ```

4. **Fix ownership for ABS podcast write access**:

   ```bash
   chown -R "${PUID:-1000}:${PGID:-1000}" "${DATA_ROOT}/media/audiobooks" 2>/dev/null || \
     echo "Note: Run: sudo chown -R ${PUID:-1000}:${PGID:-1000} ${DATA_ROOT}/media/audiobooks"
   chown -R "${PUID:-1000}:${PGID:-1000}" "${DATA_ROOT}/media/podcasts" 2>/dev/null || \
     echo "Note: Run: sudo chown -R ${PUID:-1000}:${PGID:-1000} ${DATA_ROOT}/media/podcasts"
   ```

5. **Update existing qBittorrent config** (handles the common case where qBittorrent has already run):

   > **Why this is needed**: The qBittorrent config at `homelab-data/qbittorrent/config/qBittorrent/qBittorrent.conf` already exists with `/downloads/` paths. The `if [ ! -f ... ]` seed guard will be skipped. Similarly, `categories.json` already exists with the old `abb-downloader` entry only. Both must be updated explicitly.

   ```bash
   QBT_CONF="./homelab-data/qbittorrent/config/qBittorrent/qBittorrent.conf"
   QBT_CAT="./homelab-data/qbittorrent/config/qBittorrent/categories.json"

   # Update save paths in existing qBittorrent.conf (idempotent — safe to run multiple times)
   if [ -f "$QBT_CONF" ]; then
     sed -i \
       -e 's|Session\\DefaultSavePath=.*|Session\\DefaultSavePath=/data/torrents/|' \
       -e 's|Session\\TempPath=.*|Session\\TempPath=/data/torrents/incomplete/|' \
       -e 's|Downloads\\SavePath=.*|Downloads\\SavePath=/data/torrents/|' \
       -e 's|Downloads\\TempPath=.*|Downloads\\TempPath=/data/torrents/incomplete/|' \
       "$QBT_CONF"
     echo "Updated qBittorrent.conf paths → /data/torrents/"
   fi

   # Replace categories.json with the new 5-category layout (old file only had abb-downloader)
   cp config-templates/qbittorrent/categories.json "$QBT_CAT"
   echo "Replaced qBittorrent categories.json with new layout."
   ```

6. **Seed qBittorrent config** (for fresh installs only — guards already-updated files):

   ```bash
   if [ ! -f ./homelab-data/qbittorrent/config/qBittorrent/qBittorrent.conf ]; then
     mkdir -p ./homelab-data/qbittorrent/config/qBittorrent
     cp config-templates/qbittorrent/qBittorrent.conf \
        ./homelab-data/qbittorrent/config/qBittorrent/qBittorrent.conf
     echo "Seeded qBittorrent.conf from config-templates."
   fi
   if [ ! -f ./homelab-data/qbittorrent/config/qBittorrent/categories.json ]; then
     mkdir -p ./homelab-data/qbittorrent/config/qBittorrent
     cp config-templates/qbittorrent/categories.json \
        ./homelab-data/qbittorrent/config/qBittorrent/categories.json
     echo "Seeded qBittorrent categories.json from config-templates."
   fi
   ```

7. **VPN toggle + arr stack**:

   ```bash
   USE_VPN=$(grep -E '^USE_VPN=' .env | head -1 | cut -d= -f2- | tr -d "'" | tr -d '"')
   if [ "${USE_VPN:-false}" = "true" ]; then
     ARR_COMPOSE_ARGS="-f dockerfiles/arr/compose.yaml -f dockerfiles/arr/compose.vpn.yaml"
     echo "VPN mode enabled (Gluetun/ProtonVPN)"
   else
     ARR_COMPOSE_ARGS="-f dockerfiles/arr/compose.yaml"
   fi
   echo "Bringing up arr..."
   docker compose $ENV_FILE_ARG $ARR_COMPOSE_ARGS up -d
   ```

8. **Stack order** (arr after core, before media):
   core → arr → media → productivity → immich → monitoring → documents → tools → personal → entertainment → home

9. **Remove** `lidarr/config` mkdir (still exists via arr's qbittorrent-downloads removal); ensure `./homelab-data/lidarr/config` is still in the mkdir block (Lidarr moved stacks but dir stays).

---

## Section 12 — Modified: `scripts/down-all.sh`

Add VPN toggle (same pattern as up-all.sh) and arr stack:

```bash
USE_VPN=$(grep -E '^USE_VPN=' .env | head -1 | cut -d= -f2- | tr -d "'" | tr -d '"')
if [ "${USE_VPN:-false}" = "true" ]; then
  ARR_COMPOSE_ARGS="-f dockerfiles/arr/compose.yaml -f dockerfiles/arr/compose.vpn.yaml"
else
  ARR_COMPOSE_ARGS="-f dockerfiles/arr/compose.yaml"
fi

# Down order: reverse of up (home → ... → arr → core)
echo "Bringing down arr..."
docker compose $ENV_FILE_ARG $ARR_COMPOSE_ARGS down
```

---

## Section 13 — Modified: `scripts/compose-pull-all.sh`

Add:

```bash
USE_VPN=$(grep -E '^USE_VPN=' .env | head -1 | cut -d= -f2- | tr -d "'" | tr -d '"')
ARR_COMPOSE_ARGS="-f dockerfiles/arr/compose.yaml"
# Always pull both compose files so vpn overlay image is also updated
echo "Pulling arr images..."
docker compose $ENV_FILE_ARG -f dockerfiles/arr/compose.yaml pull
docker compose $ENV_FILE_ARG -f dockerfiles/arr/compose.vpn.yaml pull 2>/dev/null || true
```

---

## Section 14 — Modified: `config-templates/qbittorrent/`

### `categories.json` — replace entirely

```json
{
 "books": {
  "save_path": "/data/torrents/books"
 },
 "movies": {
  "save_path": "/data/torrents/movies"
 },
 "music": {
  "save_path": "/data/torrents/music"
 },
 "tv": {
  "save_path": "/data/torrents/tv"
 },
 "abb-downloader": {
  "save_path": "/data/media/audiobooks"
 }
}
```

### `qBittorrent.conf` — update paths only

```ini
# Changes from current config:
[BitTorrent]
Session\DefaultSavePath=/data/torrents/
Session\TempPath=/data/torrents/incomplete/

[Preferences]
Downloads\SavePath=/data/torrents/
Downloads\TempPath=/data/torrents/incomplete/
# (all other settings unchanged)
```

> The `incomplete/` temp directory lives under `torrents/` so partial downloads and seeding files are always on the same filesystem → hardlinks work at import time.

---

## Section 15 — Modified: `config-templates/homepage/services.yaml`

### Changes

1. **External section** — no changes to arr services (they are NOT exposed via Cloudflare tunnel).
2. **Media section (Tailscale)** — add arr services, reorganise. Radarr/Sonarr/Readarr/Prowlarr go here (Tailscale-only access at `100.106.40.5:PORT`):

```yaml
- Media:
   # ... existing entries ...
   - Prowlarr:
      href: http://100.106.40.5:20083
      description: Indexer manager for *arr apps
      icon: prowlarr.png
      server: my-docker
      container: prowlarr
   - Radarr:
      href: http://100.106.40.5:20080
      description: Movie automation
      icon: radarr.png
      server: my-docker
      container: radarr
   - Sonarr:
      href: http://100.106.40.5:20081
      description: TV show automation
      icon: sonarr.png
      server: my-docker
      container: sonarr
   - Readarr:
      href: http://100.106.40.5:20082
      description: Ebook automation
      icon: readarr.png
      server: my-docker
      container: readarr
```

3. **Jellyfin** — already in External (has Cloudflare tunnel). Stays as-is.

---

## Section 16 — Modified: `scripts/setup-uptime-kuma.sh`

Add internal monitors for new arr services:

```python
# ── Arr stack ─────────────────────────────────────────────────────────────────
{"name": "Prowlarr",  "type": MonitorType.HTTP, "url": "http://prowlarr:9696/ping",   "interval": 60},
{"name": "Radarr",    "type": MonitorType.HTTP, "url": "http://radarr:7878/ping",     "interval": 60},
{"name": "Sonarr",    "type": MonitorType.HTTP, "url": "http://sonarr:8989/ping",     "interval": 60},
{"name": "Readarr",   "type": MonitorType.HTTP, "url": "http://readarr:8787/ping",    "interval": 60},
```

> Note: arr services are on `homelab_net` so the uptime-kuma container can reach them by container name. No external (Cloudflare) monitors needed for arr services — Tailscale-only.

---

## Section 17 — Modified: `FIRST-RUN.md`

Add new section: **"\*arr Stack Initial Configuration"** covering:

### qBittorrent (required before arr apps work)

1. Open `http://100.106.40.5:20050`
2. **Tools → Options → Web UI**: enable `☑ Bypass authentication for clients on localhost` (required for VPN port-sync script)
3. Default save path is pre-configured to `/data/torrents` via seeded `qBittorrent.conf`
4. Categories are pre-configured via seeded `categories.json` — verify they appear in Tools → Options → BitTorrent → Categories
5. Torrenting port is pre-configured to `20051`

### Prowlarr (configure first — syncs indexers to all apps)

1. Open `http://100.106.40.5:20083`
2. Add indexers: Indexers → Add Indexer (add public indexers like RARBG, 1337x, or private trackers)
3. Connect arr apps: Settings → Apps → Add Application:
   - Add Radarr: host=`radarr`, port=`7878`, API key from Radarr Settings → General
   - Add Sonarr: host=`sonarr`, port=`8989`, API key from Sonarr Settings → General
   - Add Lidarr: host=`lidarr`, port=`8686`, API key from Lidarr Settings → General
   - Add Readarr: host=`readarr`, port=`8787`, API key from Readarr Settings → General
4. Prowlarr will automatically sync indexers to all connected apps

### Radarr, Sonarr, Readarr

For each app:

1. Settings → Download Clients → Add qBittorrent:
   - Host: `qbittorrent`, Port: `20050`
   - Username/Password: from `.env` (`QBITTORRENT_WEBUI_USER` / `QBITTORRENT_WEBUI_PASS`)
   - Category: `movies` / `tv` / `books` respectively
2. Settings → Media Management → Root Folders → Add:
   - Radarr: `/data/media/movies`
   - Sonarr: `/data/media/tv`
   - Readarr: `/data/media/books`

### Lidarr (migration from old path)

1. Settings → Download Clients → Add qBittorrent (same as above, category: `music`)
2. Settings → Media Management → Root Folders:
   - Remove old `/music` entry
   - Add `/data/media/music`

### Jellyfin (new media libraries)

1. Open setup wizard / Dashboard → Libraries → Add Media Library
2. Add Movies library: folder `/data/movies`
3. Add TV Shows library: folder `/data/tv`

### VPN Activation (optional)

1. Generate WireGuard key at [account.proton.me/u/0/vpn/WireGuard](https://account.proton.me/u/0/vpn/WireGuard)
2. Copy the `PrivateKey` value from the generated config
3. Set in `.env`:
   ```bash
   PROTONVPN_WIREGUARD_PRIVATE_KEY=your_key_here
   PROTONVPN_SERVER_COUNTRIES=Netherlands   # or Switzerland, Iceland — must be P2P-capable
   USE_VPN=true
   ```
4. Run `./scripts/restart-update-all.sh`
5. Verify VPN tunnel is up and using a non-home IP:
   ```bash
   docker run --rm --network=container:gluetun alpine:3.18 sh -c "apk add -q wget && wget -qO- https://ipinfo.io"
   ```
   The returned `"ip"` should NOT be your home IP, and `"country"` should match `PROTONVPN_SERVER_COUNTRIES`.
6. Check gluetun logs for port forwarding confirmation:
   ```bash
   docker logs gluetun | grep -i "port"
   ```
   Should show "Port forwarding is enabled" and the assigned port.

---

## Section 18 — Modified: `README.md`

Add arr stack rows to the services table. Mark arr services as "Tailscale only".

### New section: **Arr / Download Automation**

| Service                                                                         | Purpose                                               | Access    |
| ------------------------------------------------------------------------------- | ----------------------------------------------------- | --------- |
| [Prowlarr](https://github.com/Prowlarr/Prowlarr)                                | Indexer manager (syncs to all \*arr apps)             | Tailscale |
| [Radarr](https://radarr.video/)                                                 | Automated movie collection                            | Tailscale |
| [Sonarr](https://sonarr.tv/)                                                    | Automated TV show collection                          | Tailscale |
| [Readarr](https://readarr.com/)                                                 | Automated ebook collection                            | Tailscale |
| [Lidarr](https://lidarr.audio/)                                                 | Automated music collection                            | Tailscale |
| [qBittorrent](https://www.qbittorrent.org/)                                     | Torrent client                                        | Tailscale |
| [Jackett](https://github.com/Jackett/Jackett)                                   | Indexer proxy (for audiobookbay-downloader)           | Tailscale |
| [Audiobookbay Downloader](https://github.com/moonblade/audiobookbay-downloader) | Audiobook search & download                           | Tailscale |
| [Gluetun](https://github.com/qdm12/gluetun)                                     | VPN gateway (optional, ProtonVPN WireGuard)           | Internal  |
| [deunhealth](https://github.com/qdm12/deunhealth)                               | Auto-restart qBittorrent on VPN stall (VPN mode only) | Internal  |

---

## Section 19 — `.gitignore` Review

Current `.gitignore` is correct as-is:

```gitignore
homelab-data/        # covers homelab-data/torrents/, homelab-data/media/ — correct
.env                 # sensitive credentials — correct
.DS_Store
*.log
core/cloudflared/
```

`scripts/update-qbt-port.sh` — **tracked** (no sensitive data, needed for VPN)
`.env.example` — **tracked** (sanitised, needed for new setups)
`HOMELAB-REDESIGN-PLAN.md` — **tracked** (this file)

---

## Section 20 — Network Architecture

```
homelab_net (Docker bridge, external)
│
├── cloudflared ─────────────────────────── Cloudflare Tunnel (outbound only)
│   Exposes: audiobookshelf, navidrome, feishin, octo-fiesta, immich, jellyfin,
│            yamtrack, crosswatch, forgejo, paperless, vaultwarden, joplin, mealie,
│            homepage, kiwix, stirling-pdf, drawio, excalidraw, it-tools, actual-budget
│   Does NOT expose: arr services (Tailscale-only)
│
├── arr services (Tailscale-only access via 100.106.40.5:PORT)
│   ├── prowlarr, radarr, sonarr, lidarr, readarr
│   ├── jackett, audiobookbay-downloader
│   └── qbittorrent (non-VPN mode) ──── direct homelab_net attachment
│       OR
│       gluetun (VPN mode, alias: qbittorrent)
│          └── [qbittorrent in gluetun network namespace]
│
├── media services
│   audiobookshelf, navidrome, feishin, octo-fiesta, yamtrack, crosswatch
│
└── all other stacks...

documents_net (internal) — paperless-redis, paperless-postgres ↔ paperless-ngx
immich_internal (internal) — immich-server ↔ redis ↔ database
```

---

## Section 21 — Implementation Order

Execute in this order to avoid downtime/conflicts:

1. **Stop all stacks**: `./scripts/down-all.sh`
2. **Update `.env`**: add `DATA_ROOT`, new port vars, VPN vars
3. **Create** `dockerfiles/arr/compose.yaml`
4. **Create** `dockerfiles/arr/compose.vpn.yaml`
5. **Create** `scripts/update-qbt-port.sh` (make executable: `chmod +x`)
6. **Update** `dockerfiles/media/compose.yaml` (remove arr services, fix ABS PUID/PGID, update paths)
7. **Update** `dockerfiles/entertainment/compose.yaml` (add Jellyfin media mounts)
8. **Update** `config-templates/qbittorrent/categories.json` (new paths)
9. **Update** `config-templates/qbittorrent/qBittorrent.conf` (new save paths)
10. **Update** `scripts/up-all.sh` (DATA_ROOT, migration, new dirs, VPN toggle, arr stack)
11. **Update** `scripts/down-all.sh` (VPN toggle, arr stack)
12. **Update** `scripts/compose-pull-all.sh` (arr stack)
13. **Update** `config-templates/homepage/services.yaml` (new arr services in Media section)
14. **Update** `scripts/setup-uptime-kuma.sh` (arr monitors)
15. **Update** `FIRST-RUN.md` (arr setup section)
16. **Update** `README.md` (arr services table)
17. **Create** `.env.example`
18. **Run** `./scripts/up-all.sh` (handles migration + seeding automatically)
19. **Validate**: `docker compose --env-file .env -f dockerfiles/arr/compose.yaml config`
20. **Complete FIRST-RUN.md steps** for arr stack (qBittorrent categories, Prowlarr indexers, etc.)
21. **Test podcast download** in Audiobookshelf to confirm fix

---

## Appendix — qBittorrent App Configuration Reference

After first start, configure these settings in the qBittorrent Web UI:

| Setting               | Path in UI                   | Value                                  |
| --------------------- | ---------------------------- | -------------------------------------- |
| Default save path     | Tools → Options → Downloads  | `/data/torrents`                       |
| Temp/incomplete path  | Tools → Options → Downloads  | `/data/torrents/incomplete`            |
| Bypass auth localhost | Tools → Options → Web UI     | ☑ Enabled (required for VPN port-sync) |
| Seeding limits        | Tools → Options → BitTorrent | Set ratio limit as desired             |

Categories (pre-seeded, verify they appear):

| Category         | Save Path                |
| ---------------- | ------------------------ |
| `movies`         | `/data/torrents/movies`  |
| `tv`             | `/data/torrents/tv`      |
| `music`          | `/data/torrents/music`   |
| `books`          | `/data/torrents/books`   |
| `abb-downloader` | `/data/media/audiobooks` |

---

_Plan finalised: 30 April 2026_
