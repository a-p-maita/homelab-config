# Homelab Overhaul — Condensed Implementation Reference

> This file is the authoritative, LLM-optimized version of overhaul-plan.md. It records all decisions made, constraints, flaw analysis, and ordered tasks with exact configs. The original overhaul-plan.md is retained as historical context.

---

## System Context

| Attribute      | Value                                                                              |
| -------------- | ---------------------------------------------------------------------------------- |
| Hardware       | AMD Ryzen 5 5500U, 14GB RAM, ~930GB NVMe (single drive, no RAID)                   |
| GPU            | AMD Vega 7 iGPU — enable VA-API in Jellyfin for hardware transcoding               |
| OS             | Ubuntu (Docker Compose plugin required ≥ v2.24.0 for `!reset` overlay syntax)      |
| Tailscale IP   | `100.106.40.5`                                                                     |
| Primary access | Port-based URLs: `http://100.106.40.5:PORT` — all services listed in Homepage      |
| Public access  | Cloudflare Tunnel → Caddy → `forward_auth` Authelia (selected services only)       |
| DNS challenge  | Cloudflare API token available (Zone:DNS:Write) for DNS-01 certs if needed         |
| Git repo       | Andreas-PM/homelab-config, branch: main                                            |
| Philosophy     | WebUI-first, no CLI-only tools, no subscription-gated features, git-tracked config |
| Downtime       | Acceptable — system does not need to stay live during overhaul                     |

---

## Known Flaws (Identified Pre-Implementation)

These must be understood before writing any compose file.

### F1 — Docker Compose `!reset` syntax requires ≥ v2.24.0

`compose.vpn.yaml` uses `!reset` YAML tags for gluetun VPN namespace. Ubuntu 22.04 ships v2.17 — fails silently or exposes ports outside VPN.
**Action:** `docker compose version` before Phase 1. Update if needed: `sudo apt-get install --only-upgrade docker-compose-plugin`

### F2 — Hardlinks require consistent mount path across all containers

All `*arr` apps AND qBittorrent must mount `${DATA_ROOT}` at exactly `/data` inside the container. Any sub-path mount breaks hardlinks, causing double-disk-usage on import. 930GB NVMe will abort imports silently when near full.
**Rule:** Every service in the `arr` stack gets `- ${DATA_ROOT}:/data`. No sub-path overrides.

### F3 — Authelia only protects tunnel-facing services in this setup

`forward_auth` in Caddy only intercepts requests routed through Caddy subdomains. Direct `http://100.106.40.5:PORT` access (the primary LAN method) bypasses Caddy and Authelia entirely. Authelia scope = public internet services only (those exposed via Cloudflare tunnel → Caddy). LAN/Tailscale relies on network-level trust. This is an accepted tradeoff, not a bug, but must be understood by the implementer.

### F4 — Phase 2 Caddy subdomain examples conflict with Q6 (port-based URLs)

The overhaul-plan.md Phase 2 builds full `*.home.arpa` subdomains. This is NOT required. Caddy is still needed for tunnel routing (Phase 7/12) but local subdomain routing is optional. Do not add `home.arpa` DNS or subdomain routing unless explicitly requested.

### F5 — node-exporter requires `network_mode: host`

For full system visibility, `node-exporter` must use host networking. This is a deliberate security exception to Phase 2 network segmentation. Keep it isolated to read-only mounts only.

### F6 — `services` stack split not reflected in target structure

Pain points analysis recommends splitting `services` into `services-db` and `services` (app layer). The target stack table shows one `services` stack. If debugging requires `docker compose down services`, all 15+ services go down simultaneously. Implement the split from day one: `stacks/services/compose.yaml` (apps) + `stacks/services/compose.db.yaml` (postgres + redis only).

### F7 — `LIDARR_API_KEY` is undocumented

Used in the Unpackerr snippet. Obtain from Lidarr: Settings → General → API Key. Add to `.env`.

### F8 — Immich version pin is a placeholder

`v1.131.0` was current at plan creation. Always pin to the actual latest stable at time of implementation. Check: https://github.com/immich-app/immich/releases

---

## Final Decisions

| #   | Topic              | Decision                                                                                                     |
| --- | ------------------ | ------------------------------------------------------------------------------------------------------------ |
| 1   | abb-downloader     | Keep. Keep Jackett until Listenarr + Prowlarr Torznab is confirmed working                                   |
| 2   | Book management    | LazyLibrarian → Komga + Calibre-Web + BookBounty. Readarr is RETIRED (Servarr, June 2025) — do not add       |
| 3   | Watchtower         | Opt-in mode. Only containers with `com.centurylinklabs.watchtower.enable=true` label. Never on DBs or Immich |
| 4   | Postgres           | Consolidate Joplin + Paperless into one shared postgres with separate databases                              |
| 5   | Cloudflare token   | Available (Zone:DNS:Write). Use for tunnel TLS. Already rotated after accidental exposure                    |
| 6   | LAN access         | Port-based URLs only (`http://100.106.40.5:PORT`). All services in Homepage. No `*.home.arpa` routing needed |
| 7   | autobrr            | Public trackers only. Poll Prowlarr RSS feeds — no IRC announce, no private trackers                         |
| 8   | Comics             | Deferred. No current collection. Komga handles them natively when needed. Kapowarr/Mylar3: future only       |
| 9   | Immich ML          | Disabled via `profiles: [disabled]` in compose.override.yaml. Saves ~2GB RAM                                 |
| 10  | Migration approach | One phase at a time. System can be fully offline. Stop between phases if context/quality degrades            |
| 11  | Usenet             | Removed entirely. No SABnzbd. Torrent pipeline only                                                          |
| 12  | Authelia 2FA       | Infrastructure setup only. User manages TOTP enrollment and backup of `config/authelia/` manually            |
| 13  | Youtarr            | `https://www.youtube.com/@fireship`, limit=1 (most recent only), daily schedule                              |
| 14  | Listenarr timeline | No timeline. User evaluates at own pace. Run alongside abb-downloader indefinitely                           |

---

## Target Architecture — 6 Stacks

**Grouping criterion: restart independence.** Services always restarted together belong in one stack.

| Stack            | Services                                                                                                                                                                 | Notes                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `infrastructure` | cloudflared, caddy, authelia, authelia-redis, homepage, uptime-kuma, watchtower, prometheus, node-exporter, grafana, scrutiny                                            | Start first. Caddy needed for Cloudflare tunnel routing                        |
| `arr`            | gluetun, deunhealth, qbittorrent, prowlarr, byparr, radarr, sonarr, lidarr, bazarr, jackett†, bookbounty, profilarr, unpackerr, autobrr, cleanuparr, listenarr†, youtarr | VPN namespace (`network_mode: service:gluetun`) requires gluetun in same stack |
| `media`          | jellyfin, seerr, audiobookshelf, navidrome, feishin, octo-fiesta, crosswatch, yamtrack, maintainerr, komga, calibre-web                                                  | No VPN, no DBs. Pure playback/tracking                                         |
| `cloud`          | immich-server, immich-postgres, immich-redis ~~immich-machine-learning~~ (disabled)                                                                                      | Isolated internal network. Immich ML disabled — saves 2GB RAM                  |
| `services`       | vaultwarden, actual-budget, joplin+postgres, paperless+redis+postgres, stirling-pdf, kiwix, mealie, forgejo, drawio, excalidraw, it-tools, wizarr                        | Consider services/services.db.yaml split (see F6)                              |
| `home`           | home-assistant                                                                                                                                                           | May need `network_mode: host` for mDNS/Zigbee                                  |

† jackett: keep until abb-downloader replaced. listenarr: beta, run alongside abb-downloader.

**startup order:** `infrastructure` → then `arr`, `media`, `cloud`, `services`, `home` in parallel.

---

## Network Segmentation

```
homelab_net       (external bridge — cross-stack communication)
  └── caddy, cloudflared, homepage, uptime-kuma
  └── prowlarr, radarr, sonarr, lidarr, bazarr, bookbounty, profilarr, autobrr, jellyfin, seerr,
      audiobookshelf, navidrome, maintainerr, komga, calibre-web, vaultwarden, forgejo, mealie,
      joplin, paperless, authelia, grafana

arr_internal      (internal — no external exposure)
  └── prowlarr, radarr, sonarr, lidarr, bazarr, bookbounty (also on homelab_net for Caddy/Homepage)
  └── qbittorrent (via gluetun namespace)

services_internal (internal — DBs + their apps only)
  └── paperless-postgres, paperless-redis, paperless-ngx
  └── joplin-postgres, joplin-server

immich_internal   (keep existing)
  └── immich-server, immich-postgres, immich-redis
```

**Rule:** Databases never join `homelab_net`. Services join `homelab_net` only if they need Caddy routing, Homepage monitoring, or cross-stack API calls.

---

## File Structure

```
homelab-config/
├── .env                          # gitignored — all secrets + ports
├── .env.example                  # tracked — document every variable with placeholder
├── stacks/                       # replaces dockerfiles/
│   ├── infrastructure/compose.yaml
│   ├── arr/
│   │   ├── compose.yaml
│   │   └── compose.vpn.yaml      # gluetun + deunhealth overlay (requires Compose ≥ v2.24.0)
│   ├── media/compose.yaml
│   ├── cloud/
│   │   ├── compose.yaml          # upstream immich file (update periodically)
│   │   └── compose.override.yaml # our paths + immich-ml disabled:
│   │                             #   immich-machine-learning:
│   │                             #     profiles: [disabled]
│   ├── services/
│   │   ├── compose.yaml          # app layer
│   │   └── compose.db.yaml       # postgres + redis only (see F6)
│   └── home/compose.yaml
├── config/                       # replaces config-templates/ — version-controlled seed configs
│   ├── caddy/Caddyfile
│   ├── authelia/
│   │   ├── configuration.yml
│   │   └── users_database.yml    # user manages this manually
│   ├── prometheus/prometheus.yml
│   └── homepage/ qbittorrent/ profilarr/ ...
├── homelab-data/                 # keep name — live configs, partially git-tracked
└── scripts/
    ├── up-all.sh                 # trap-based, collects failures (see snippet below)
    ├── down-all.sh
    ├── compose-pull-all.sh
    ├── seed-configs.sh           # NEW: idempotent config seeding (extracted from up-all.sh)
    ├── backup.sh                 # NEW: Restic offsite
    ├── backup-dbs.sh             # NEW: pg_dumpall before any overhaul
    └── generate-secrets.sh       # NEW: populates auto-generated .env secrets
```

---

## `.env` Reference

```dotenv
# Core
TZ=Europe/London
DATA_ROOT=/home/a-p-maita/homelab-config/data
PUID=1000
PGID=1000

# Existing API keys
RADARR_API_KEY=5a1bd8ee5cc84ab1ae1299483ff8b2a6
SONARR_API_KEY=8478d0c426aa4b438f2e09d5191fb577
PROWLARR_API_KEY=6339dd71e7b54376bf6b46040dbd3293
LIDARR_API_KEY=          # obtain from Lidarr → Settings → General → API Key (see F7)

# Existing ports
QBITTORRENT_WEBUI_PORT=20050
BAZARR_PORT=20061

# New ports
WIZARR_PORT=20071
CLEANUPARR_PORT=20072
LISTENARR_PORT=20073
AUTOBRR_PORT=20074
PROFILARR_PORT=20075
YOUTARR_PORT=20076
KOMGA_PORT=20077
CALIBREWEB_PORT=20078
BOOKBOUNTY_PORT=20079
MAINTAINERR_PORT=6246
AUTHELIA_PORT=9091
PROMETHEUS_PORT=9090
GRAFANA_PORT=3001        # 3000 may conflict with homepage
SCRUTINY_PORT=8081       # 8080 may conflict

# Immich — pin to current stable at time of implementation (NOT release)
IMMICH_VERSION=          # check https://github.com/immich-app/immich/releases

# Auto-generated secrets (run generate-secrets.sh)
AUTHELIA_SESSION_SECRET= # openssl rand -hex 32
AUTHELIA_STORAGE_KEY=    # openssl rand -hex 32
GRAFANA_PASSWORD=        # openssl rand -base64 16
VAULTWARDEN_ADMIN_TOKEN= # openssl rand -base64 32
RESTIC_BACKUP_PASSWORD=  # openssl rand -hex 32
RESTIC_S3_KEY_ID=
RESTIC_S3_SECRET=

# Cloudflare
CLOUDFLARE_TUNNEL_TOKEN= # Zero Trust → Tunnels → your tunnel → Configure
CF_API_TOKEN=            # Zone:DNS:Write — rotated; create new at dash.cloudflare.com/profile/api-tokens
```

---

## Compose Snippets — New Services

All snippets use the new `stacks/` path convention. Adjust relative paths for current `dockerfiles/` structure if implementing before Phase 6.

### infrastructure stack additions

```yaml
caddy:
 image: caddy:alpine
 container_name: caddy
 restart: unless-stopped
 ports:
  - "80:80"
  - "443:443"
  - "443:443/udp"
 volumes:
  - ../../config/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
  - ../../data/caddy/data:/data
  - ../../data/caddy/config:/config
 networks:
  - homelab_net

authelia:
 image: authelia/authelia:latest
 container_name: authelia
 environment:
  - TZ=${TZ}
 volumes:
  - ../../config/authelia:/config
 ports:
  - "${AUTHELIA_PORT}:9091"
 restart: unless-stopped
 networks:
  - homelab_net
 labels:
  - "com.centurylinklabs.watchtower.enable=true"

authelia-redis:
 image: redis:7-alpine
 container_name: authelia-redis
 volumes:
  - ../../data/authelia/redis:/data
 restart: unless-stopped
 networks:
  - homelab_net
 # NOTE: do NOT add watchtower label to redis

prometheus:
 image: prom/prometheus:latest
 volumes:
  - ../../data/prometheus:/prometheus
  - ../../config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
 ports:
  - "${PROMETHEUS_PORT}:9090"
 networks:
  - homelab_net

node-exporter:
 image: prom/node-exporter:latest
 network_mode: host # EXCEPTION to network segmentation — required for full system visibility (see F5)
 pid: host
 volumes:
  - /proc:/host/proc:ro
  - /sys:/host/sys:ro
  - /:/rootfs:ro
 command:
  - "--path.procfs=/host/proc"
  - "--path.sysfs=/host/sys"
  - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
 restart: unless-stopped

grafana:
 image: grafana/grafana:latest
 volumes:
  - ../../data/grafana:/var/lib/grafana
 environment:
  - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
  - GF_USERS_ALLOW_SIGN_UP=false
 ports:
  - "${GRAFANA_PORT}:3000"
 networks:
  - homelab_net

scrutiny:
 image: ghcr.io/analogj/scrutiny:master-omnibus
 container_name: scrutiny
 cap_add:
  - SYS_RAWIO
  - SYS_ADMIN
 devices:
  - /dev/nvme0:/dev/nvme0
 volumes:
  - /run/udev:/run/udev:ro
  - ../../data/scrutiny:/opt/scrutiny/config
  - ../../data/scrutiny/influxdb:/opt/scrutiny/influxdb
 ports:
  - "${SCRUTINY_PORT}:8080"
 networks:
  - homelab_net

watchtower:
 image: containrrr/watchtower:latest
 command: --label-enable --cleanup --schedule "0 0 3 * * *"
 volumes:
  - /var/run/docker.sock:/var/run/docker.sock
 environment:
  - TZ=${TZ}
 restart: unless-stopped
```

### arr stack additions

```yaml
unpackerr:
 image: golift/unpackerr:latest
 container_name: unpackerr
 user: "${PUID}:${PGID}"
 environment:
  - TZ=${TZ}
  - UN_SONARR_0_URL=http://sonarr:8989
  - UN_SONARR_0_API_KEY=${SONARR_API_KEY}
  - UN_RADARR_0_URL=http://radarr:7878
  - UN_RADARR_0_API_KEY=${RADARR_API_KEY}
  - UN_LIDARR_0_URL=http://lidarr:8686
  - UN_LIDARR_0_API_KEY=${LIDARR_API_KEY}
 volumes:
  - ${DATA_ROOT}:/data
 restart: unless-stopped
 networks:
  - homelab_net

autobrr:
 image: ghcr.io/autobrr/autobrr:latest
 container_name: autobrr
 user: "${PUID}:${PGID}"
 environment:
  - TZ=${TZ}
 volumes:
  - ../../data/autobrr/config:/config
 ports:
  - "${AUTOBRR_PORT}:7474"
 restart: unless-stopped
 networks:
  - homelab_net
 labels:
  - "com.centurylinklabs.watchtower.enable=true"

cleanuparr:
 image: ghcr.io/cleanuparr/cleanuparr:latest
 container_name: cleanuparr
 environment:
  - PUID=${PUID}
  - PGID=${PGID}
  - TZ=${TZ}
 volumes:
  - ../../data/cleanuparr/config:/config
 ports:
  - "${CLEANUPARR_PORT}:11011"
 restart: unless-stopped
 networks:
  - homelab_net
 labels:
  - "com.centurylinklabs.watchtower.enable=true"

profilarr:
 image: ghcr.io/dictionarry-hub/profilarr:latest
 container_name: profilarr
 environment:
  - TZ=${TZ}
 volumes:
  - ../../data/profilarr/config:/config
 ports:
  - "${PROFILARR_PORT}:7474"
 restart: unless-stopped
 networks:
  - homelab_net
 labels:
  - "com.centurylinklabs.watchtower.enable=true"

listenarr:
 image: ghcr.io/listenarrs/listenarr:canary # beta — only tag available
 container_name: listenarr
 environment:
  - PUID=${PUID}
  - PGID=${PGID}
  - UMASK=022
  - TZ=${TZ}
 volumes:
  - ../../data/listenarr/config:/app/config
  - ${DATA_ROOT}/media/audiobooks:/audiobooks
  - ${DATA_ROOT}/torrents/audiobooks:/downloads/torrents
 ports:
  - "${LISTENARR_PORT}:4545"
 restart: unless-stopped
 networks:
  - homelab_net

youtarr:
 image: ghcr.io/dialmasterorg/youtarr:latest
 container_name: youtarr
 environment:
  - TZ=${TZ}
 volumes:
  - ../../data/youtarr/config:/app/config
  - ${DATA_ROOT}/media/youtube:/downloads
 ports:
  - "${YOUTARR_PORT}:9762"
 restart: unless-stopped
 networks:
  - homelab_net
 labels:
  - "com.centurylinklabs.watchtower.enable=true"
# After start: WebUI → add channel https://www.youtube.com/@fireship, limit=1, daily schedule
# Add ${DATA_ROOT}/media/youtube to Jellyfin as "Shows" or "Video" library
```

### media stack additions

```yaml
maintainerr:
 image: ghcr.io/jorenn92/maintainerr:latest
 container_name: maintainerr
 user: "${PUID}:${PGID}"
 environment:
  - TZ=${TZ}
 volumes:
  - ../../data/maintainerr:/opt/data
 ports:
  - "${MAINTAINERR_PORT}:6246"
 restart: unless-stopped
 networks:
  - homelab_net
 labels:
  - "com.centurylinklabs.watchtower.enable=true"

komga:
 image: gotson/komga:latest
 container_name: komga
 environment:
  - TZ=${TZ}
 user: "${PUID}:${PGID}"
 volumes:
  - ../../data/komga/config:/config
  - ${DATA_ROOT}/media/books:/data/books
  - ${DATA_ROOT}/media/comics:/data/comics # ready for future comics
 ports:
  - "${KOMGA_PORT}:25600"
 restart: unless-stopped
 networks:
  - homelab_net
 labels:
  - "com.centurylinklabs.watchtower.enable=true"

calibre-web:
 image: lscr.io/linuxserver/calibre-web:latest
 container_name: calibre-web
 environment:
  - PUID=${PUID}
  - PGID=${PGID}
  - TZ=${TZ}
  - DOCKER_MODS=linuxserver/mods:universal-calibre
 volumes:
  - ../../data/calibre-web/config:/config
  - ${DATA_ROOT}/media/books:/books
 ports:
  - "${CALIBREWEB_PORT}:8083"
 restart: unless-stopped
 networks:
  - homelab_net
 labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

### services stack additions

```yaml
wizarr:
 image: ghcr.io/wizarrrr/wizarr:latest
 container_name: wizarr
 environment:
  - TZ=${TZ}
 volumes:
  - ../../data/wizarr/database:/data/database
 ports:
  - "${WIZARR_PORT}:5690"
 restart: unless-stopped
 networks:
  - homelab_net
 labels:
  - "com.centurylinklabs.watchtower.enable=true"

bookbounty:
 image: ghcr.io/thewicklowwolf/bookbounty:latest
 container_name: bookbounty
 environment:
  - PUID=${PUID}
  - PGID=${PGID}
  - TZ=${TZ}
 volumes:
  - ../../data/bookbounty/config:/config
  - ${DATA_ROOT}/media/books:/data/books
  - /etc/localtime:/etc/localtime:ro
 ports:
  - "${BOOKBOUNTY_PORT}:5000"
 restart: unless-stopped
 networks:
  - homelab_net
 labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

### Immich cloud stack — compose.override.yaml additions

```yaml
# stacks/cloud/compose.override.yaml
services:
 immich-machine-learning:
  profiles:
   - disabled # comment out this section to re-enable if needed in future
 immich-server:
  volumes:
   - ${DATA_ROOT}/immich_upload:/usr/src/app/upload
  environment:
   - TZ=${TZ}
  networks:
   - homelab_net
   - immich_internal
 immich-postgres:
  volumes:
   - ${DATA_ROOT}/immich_db:/var/lib/postgresql/data
  networks:
   - immich_internal
  # NEVER add watchtower label — DB schema migrations require manual controlled updates
 immich-redis:
  networks:
   - immich_internal
  # NEVER add watchtower label
```

---

## Critical Rules (Never Violate)

```
HARDLINKS:     Every *arr app + qBittorrent must mount ${DATA_ROOT}:/data (not sub-paths)
IMMICH:        Never add watchtower label to immich-server, immich-postgres, immich-redis
               Update manually: bump IMMICH_VERSION in .env → docker compose pull && up -d
WATCHTOWER:    Opt-in only. Never label any postgres/redis/mariadb container
READARR:       Do not add. Officially retired by Servarr team, June 2025. Metadata broken.
IMMICH ML:     Disabled. Do not re-enable. Saves 2GB RAM. Face recognition not used.
USENET:        Not in scope. Do not add SABnzbd or any Usenet tooling.
COMICS:        Deferred. Komga mounts /data/comics ready for future. Kapowarr not yet.
AUTHELIA LAN:  Direct port-based access bypasses Caddy/Authelia. Authelia only protects
               Cloudflare-tunnelled services. LAN trust is network-level.
```

---

## up-all.sh (trap-based, replace current)

```bash
#!/usr/bin/env bash
set -uo pipefail

failures=()

up_stack() {
  local name="$1" path="$2"
  echo "[up] Starting $name..."
  if ! docker compose -f "$path" up -d; then
    failures+=("$name")
    echo "[up] WARNING: $name failed" >&2
  fi
}

up_stack "infrastructure" "stacks/infrastructure/compose.yaml"
up_stack "arr"            "stacks/arr/compose.yaml"
up_stack "media"          "stacks/media/compose.yaml"
up_stack "cloud"          "stacks/cloud/compose.yaml"
up_stack "services"       "stacks/services/compose.yaml"
up_stack "home"           "stacks/home/compose.yaml"

if [ ${#failures[@]} -gt 0 ]; then
  echo "[up] FAILED stacks: ${failures[*]}"
  exit 1
fi
```

---

## backup-dbs.sh (run before any overhaul phase)

```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p backups
docker exec immich-postgres   pg_dumpall -U postgres  > backups/immich-$(date -I).sql
docker exec paperless-postgres pg_dumpall -U paperless > backups/paperless-$(date -I).sql
docker exec joplin-postgres    pg_dumpall -U joplin    > backups/joplin-$(date -I).sql
echo "[backup] DB dumps complete"
```

---

## backup.sh (Restic offsite — run via cron: `0 3 * * *`)

```bash
#!/usr/bin/env bash
set -euo pipefail
source /home/a-p-maita/homelab-config/.env
export RESTIC_REPOSITORY="s3:https://s3.us-west-004.backblazeb2.com/homelab-backup"
export RESTIC_PASSWORD="${RESTIC_BACKUP_PASSWORD}"
export AWS_ACCESS_KEY_ID="${RESTIC_S3_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${RESTIC_S3_SECRET}"

restic backup \
  "${DATA_ROOT}/vaultwarden" \
  "${DATA_ROOT}/paperless" \
  "${DATA_ROOT}/immich_upload" \
  "${DATA_ROOT}/forgejo" \
  "${DATA_ROOT}/joplin" \
  "${DATA_ROOT}/actual-budget" \
  "${DATA_ROOT}/home-assistant" \
  --tag homelab --exclude="*.log" --exclude="*.tmp"

restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12

cd /home/a-p-maita/homelab-config
git add -A
git diff-index --quiet HEAD || git commit -m "auto: config backup $(date -I)" && git push
```

---

## generate-secrets.sh (run once on first setup)

```bash
#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="$(cd "$(dirname "$0")/.." && pwd)/.env"

set_if_empty() {
  local key="$1" value="$2"
  if grep -qE "^${key}=$" "$ENV_FILE" 2>/dev/null || ! grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE" 2>/dev/null || echo "${key}=${value}" >> "$ENV_FILE"
    echo "[generated] ${key}"
  else
    echo "[skip] ${key} already set"
  fi
}

set_if_empty "AUTHELIA_SESSION_SECRET" "$(openssl rand -hex 32)"
set_if_empty "AUTHELIA_STORAGE_KEY"    "$(openssl rand -hex 32)"
set_if_empty "GRAFANA_PASSWORD"         "$(openssl rand -base64 16)"
set_if_empty "VAULTWARDEN_ADMIN_TOKEN" "$(openssl rand -base64 32)"
set_if_empty "RESTIC_BACKUP_PASSWORD"  "$(openssl rand -hex 32)"

echo "[done] Fill in external API keys manually: CLOUDFLARE_TUNNEL_TOKEN, CF_API_TOKEN, RESTIC_S3_KEY_ID, RESTIC_S3_SECRET, LIDARR_API_KEY"
```

---

## Authelia Config Templates

### config/authelia/configuration.yml

```yaml
server:
 address: tcp://0.0.0.0:9091
log:
 level: info
theme: dark
totp:
 issuer: homelab
 period: 30
 skew: 1
authentication_backend:
 file:
  path: /config/users_database.yml
  password:
   algorithm: argon2
access_control:
 default_policy: two_factor
 rules:
  - domain: "*.andreasmaita.com"
    resources:
     - "^/api/.*$"
     - "^/identity/.*$"
    policy: bypass
  - domain: ["jellyfin.andreasmaita.com", "seerr.andreasmaita.com"]
    policy: one_factor
session:
 name: authelia_session
 secret: ${AUTHELIA_SESSION_SECRET}
 expiration: 1h
 inactivity: 10m
 redis:
  host: authelia-redis
  port: 6379
storage:
 local:
  path: /config/db.sqlite3
 encryption_key: ${AUTHELIA_STORAGE_KEY}
notifier:
 filesystem:
  filename: /config/notification.txt # use smtp block when email is configured
```

### config/authelia/users_database.yml

```yaml
users:
 yourusername:
  displayname: "Andreas"
  password: "" # generate: docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'yourpassword'
  email: you@yourdomain.com
  groups:
   - admins
```

**Authelia setup sequence:**

1. `bash scripts/generate-secrets.sh`
2. Fill in `users_database.yml` password hash
3. `docker compose up -d authelia authelia-redis`
4. Visit `http://100.106.40.5:9091` → log in → enroll TOTP
5. Back up `config/authelia/` after setup

---

## Cloudflare Tunnel — Public Hostname Routes

All routes point to Caddy. Caddy routes to correct backend + applies `forward_auth`.

| Subdomain | Domain           | Type  | URL       |
| --------- | ---------------- | ----- | --------- |
| jellyfin  | andreasmaita.com | HTTPS | caddy:443 |
| immich    | andreasmaita.com | HTTPS | caddy:443 |
| vault     | andreasmaita.com | HTTPS | caddy:443 |
| music     | andreasmaita.com | HTTPS | caddy:443 |
| abs       | andreasmaita.com | HTTPS | caddy:443 |
| git       | andreasmaita.com | HTTPS | caddy:443 |
| seerr     | andreasmaita.com | HTTPS | caddy:443 |
| join      | andreasmaita.com | HTTPS | caddy:443 |
| auth      | andreasmaita.com | HTTPS | caddy:443 |

**Caddy `forward_auth` pattern (for tunnel-protected services):**

```caddyfile
radarr.andreasmaita.com {
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://auth.andreasmaita.com
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy radarr:7878
}
```

Note: radarr is NOT in the tunnel table above — this is just the pattern. Only services in the table above are publicly exposed.

---

## Resource Estimates

| Tier                     | Services                                                          | Est. RAM   |
| ------------------------ | ----------------------------------------------------------------- | ---------- |
| Heavy                    | immich-server (2G), jellyfin (1G)                                 | ~3G        |
| Medium                   | paperless, radarr, sonarr, lidarr, komga, home-assistant, grafana | ~2.5G      |
| Light                    | ~42 other containers                                              | ~3G        |
| System + Docker overhead |                                                                   | ~2G        |
| **Total**                |                                                                   | **~10.5G** |
| Headroom                 | 14G total - 10.5G = ~3.5G                                         |            |

**Jellyfin hardware transcoding:**

```yaml
jellyfin:
 devices:
  - /dev/dri:/dev/dri
 group_add:
  - "video"
  - "render"
```

In Jellyfin: Playback → Hardware Acceleration → VA-API → `/dev/dri/renderD128`

**Host tuning (add to `/etc/sysctl.d/99-homelab.conf`):**

```
vm.swappiness = 10
vm.vfs_cache_pressure = 50
```

**NVMe I/O scheduler (`/etc/udev/rules.d/60-scheduler.rules`):**

```
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
```

---

## Implementation Order

> Complete and verify each phase before starting the next. Stop at phase boundaries if context is running low — each phase is fully self-contained.

| Order | Task                                                                                                        | Risk   |
| ----- | ----------------------------------------------------------------------------------------------------------- | ------ |
| 1     | **Quick wins:** TZ → `.env`, `BAZARR_PORT` → `.env`, stop `docker-model-runner`, pin `IMMICH_VERSION`       | None   |
| 2     | **Backup:** run `backup-dbs.sh`, set up Restic + `backup.sh`, git push                                      | None   |
| 3     | **Add to existing arr stack:** Unpackerr, Cleanuparr, autobrr, Listenarr, Wizarr                            | None   |
| 4     | **Add to existing arr stack:** Profilarr (remove Recyclarr after QP verification)                           | Low    |
| 5     | **Add Youtarr** to arr stack; configure @fireship channel in WebUI                                          | None   |
| 6     | **Book management:** remove LazyLibrarian; add Komga + Calibre-Web + BookBounty                             | Low    |
| 7     | **Add Maintainerr** to media stack                                                                          | None   |
| 8     | **Phase 6 — file structure:** `dockerfiles/` → `stacks/`, `config-templates/` → `config/`                   | Low    |
| 9     | **Phase 1 — stack consolidation:** 11 → 6 stacks; write Phase 2 network config simultaneously (see note)    | Medium |
| 10    | **Phase 2 — networking:** network segmentation + Caddy container (LAN subdomains optional)                  | Medium |
| 11    | **Phase 5 — monitoring:** Prometheus + Grafana + Scrutiny + node-exporter; import dashboards 1860 + 893     | None   |
| 12    | **Phase 7/12 — access layer:** Caddyfile routes for tunnelled services; configure Cloudflare tunnel → Caddy | Low    |
| 13    | **Phase 11 — Authelia:** compose up, enroll TOTP, add `forward_auth` to Caddyfile for tunnelled services    | Low    |
| 14    | **Phase 8 — resource tuning:** enable VA-API, set swappiness, NVMe scheduler                                | None   |

**Critical note on steps 9+10:** Write the Phase 2 final network config into the arr stack compose file during Phase 1. Introducing networks to an existing stack later requires recreating all containers (second downtime window).

---

## Services Removed / Not Added

| Service             | Reason                                                                           |
| ------------------- | -------------------------------------------------------------------------------- |
| SABnzbd             | Usenet removed from scope entirely                                               |
| LazyLibrarian       | Upstream dead since 2018; replaced by Komga + Calibre-Web + BookBounty           |
| Readarr             | **Officially retired by Servarr team, June 2025. Do not add.**                   |
| Kavita              | Subscription gates basic features; replaced by Komga (MIT, free)                 |
| Recyclarr           | CLI-only config; replaced by Profilarr (WebUI)                                   |
| NPM                 | SQLite config not git-trackable; replaced by Caddy (Caddyfile)                   |
| immich-ml           | Not used (face recognition / smart search); disabled, saves 2GB RAM              |
| Kapowarr            | Comics deferred — no current collection. Add later when comics collection starts |
| SuggestArr          | Explicitly not wanted                                                            |
| Tdarr               | Too resource-intensive on laptop hardware                                        |
| Watcharr            | Overlaps with yamtrack (already in stack)                                        |
| Dispatcharr         | No IPTV use case                                                                 |
| docker-model-runner | Docker Desktop AI feature; remove immediately                                    |
