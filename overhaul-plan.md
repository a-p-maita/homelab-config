# Homelab Overhaul Plan

**Context:** AMD Ryzen 5 5500U laptop, ~930GB NVMe, single drive, Tailscale + Cloudflare Tunnel, future-proof for static IP / port forwarding.  
**Reference:** TechHutTV/homelab as structural baseline — critically adapted for single-machine laptop constraints.  
**Scope:** This plan covers what to change, why, and in what order. Implementation is phase-by-phase.  
**Revision note (v2):** Revised to correct stack consolidation over-simplification, add missing critical apps (Unpackerr, Maintainerr, autobrr), replace NPM with Caddy, and add backup strategy.  
**Revision note (v4):** Added Phase 10 (Usenet), Known Plan Pain Points section, and corrected Readarr retirement throughout.  
**Revision note (v5):** Evaluated expanded \*arr app list; added Wizarr, Cleanuparr, Listenarr, Lingarr, Posterizarr verdicts; updated Profilarr status; added Phase 11 (Real-Debrid).

---

## Executive Summary of Problems Found

| Area                  | Current State                                         | Problem                                                                                                                                                                                                                                                                                                             |
| --------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Stack count           | 11 separate compose stacks                            | Excessive overhead — 11 `docker compose up` calls, 11 networks to reason about                                                                                                                                                                                                                                      |
| Networking            | Single flat `homelab_net` bridge                      | No isolation between security domains; all services can reach all others                                                                                                                                                                                                                                            |
| Access layer          | Cloudflare tunnel + Tailscale, no local reverse proxy | No LAN subdomains, SSL termination is all-or-nothing; no modular switch path to static IP                                                                                                                                                                                                                           |
| VPN network           | Compose overlay pattern (`compose.vpn.yaml`)          | Elegant but fragile: `!reset` syntax requires **Docker Compose v2.24.0+** — breaks silently on older installs (Ubuntu 22.04 ships v2.17 by default); minimum version never documented; no fallback specified                                                                                                        |
| Unpackerr             | **Missing entirely**                                  | **Critical gap** — RAR/ZIP-packed downloads (common on private trackers) silently fail to import into \*arr apps without extraction                                                                                                                                                                                 |
| Maintainerr           | Missing                                               | No automated media cleanup; with Seerr requests enabled, disk space on the single NVMe will be exhausted by unwatched content                                                                                                                                                                                       |
| Jackett               | Running alongside Prowlarr                            | Redundant for all \*arr apps; only kept for audiobookbay-downloader                                                                                                                                                                                                                                                 |
| LazyLibrarian         | Running                                               | Upstream source code dead (last commit 2018); LinuxServer Docker image is still maintained but the application itself is abandoned                                                                                                                                                                                  |
| autobrr               | Missing                                               | IRC/announce-based torrent grabbing for private tracker ratio maintenance                                                                                                                                                                                                                                           |
| Recyclarr             | Working but no profile alternative noted              | Profilarr (Dictionarry) is an alternative worth knowing about — **now 2.1k ⭐, V2 actively developed; upgrade path when V2 stable**                                                                                                                                                                                 |
| Reverse proxy         | NPM recommended in v1 of this plan                    | **Wrong choice for a git-tracked homelab** — NPM stores config in SQLite which can't be version-controlled; Caddy uses a plain-text `Caddyfile`                                                                                                                                                                     |
| Monitoring            | Homepage + Uptime Kuma + Watchtower only              | No metrics, no disk SMART monitoring; Watchtower auto-updates all containers unguarded                                                                                                                                                                                                                              |
| Backup                | **No backup strategy**                                | **Critical on a single NVMe** — no redundancy means a drive failure loses everything                                                                                                                                                                                                                                |
| `up-all.sh`           | 200+ line bash script                                 | Single failure stops all subsequent stacks (`set -e`); no parallelism                                                                                                                                                                                                                                               |
| TZ                    | `Europe/London` hardcoded in every service            | Should be one `.env` variable `TZ=Europe/London`                                                                                                                                                                                                                                                                    |
| Readarr               | ~~Missing~~ **RETIRED**                               | **⚠️ RETIRED by the Servarr team** — metadata source broken, project archived June 2025; do not add. See Phase 3 for book management strategy.                                                                                                                                                                      |
| Hardlinks             | Not documented anywhere in plan                       | Critical for single-drive setup — without hardlinks across the same filesystem, *arr apps copy files during import (a 50GB movie temporarily requires 100GB). The `${DATA_ROOT}:/data` mount is already correct; it must be consistently applied to all *arr apps AND both download clients (qBittorrent + SABnzbd) |
| Usenet                | Missing from stack entirely                           | No Usenet download client. Torrent-only means no access to Usenet-exclusive content, 4000+ day retention, or full-speed no-ratio downloads. SABnzbd is the correct active client (NZBGet was archived Nov 2022)                                                                                                     |
| Immich + Watchtower   | `IMMICH_VERSION=release`, Watchtower covers all       | Immich runs DB schema migrations on every minor version bump. A Watchtower auto-update can corrupt the database requiring manual `pg_upgrade`. Immich (all four containers) **must** be excluded from Watchtower's opt-in list                                                                                      |
| `docker-model-runner` | Running (Docker Desktop feature)                      | Not part of this homelab; consuming RAM unnecessarily                                                                                                                                                                                                                                                               |

---

## Known Plan Pain Points & Corrections

These issues were identified during a post-draft review. Each is addressed in the relevant phase below, but they are summarised here for awareness before diving into implementation.

### 1. Docker Compose Version Requirement (`!reset` syntax)

The `compose.vpn.yaml` overlay uses `!reset` YAML tags (`networks: !reset null`, `ports: !reset []`). This syntax was introduced in **Docker Compose v2.24.0** (January 2024). Ubuntu 22.04 ships Compose v2.17 by default — the overlay will fail with a cryptic YAML parse error, or silently ignore the reset and leave ports exposed outside the VPN tunnel.

**Check before Phase 1:**

```bash
docker compose version
# Must be ≥ 2.24.0
# Update: sudo apt-get update && sudo apt-get install --only-upgrade docker-compose-plugin
```

### 2. Hardlinks — Critical for Single-Drive Import

Without hardlinks, Sonarr/Radarr copy completed downloads to the media library on import. A 50GB movie temporarily requires 100GB while both the source (in `/data/torrents/movies/`) and the imported copy (in `/data/media/movies/`) exist simultaneously. On a near-full 930GB NVMe this will silently abort imports.

**The fix is already structurally in place** — the `${DATA_ROOT}:/data` volume mount gives all containers the same filesystem path, making hardlinks work automatically (instantaneous import, zero extra space). The **critical requirement** is consistency: every \*arr app AND every download client (qBittorrent, SABnzbd) must mount `${DATA_ROOT}` at exactly `/data` inside the container. If any service mounts only a sub-path, hardlinks break for that service. Verify this when migrating to the new stack structure.

Reference: [TRaSH Guides — Hardlinks and Instant Moves](https://trash-guides.info/File-and-Folder-Structure/Hardlinks-and-Instant-Moves/)

### 3. `up-all.sh` Cascade Failure

The current `up-all.sh` uses `set -e` — any single `docker compose up` failure aborts all subsequent stacks silently. Reducing to 6 stacks makes this less likely but doesn't fix it. Replace with a trap-based error collector:

```bash
#!/usr/bin/env bash
set -uo pipefail   # -e removed; collect failures instead

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

### 4. Immich + Watchtower is Dangerous

Immich performs DB schema migrations on every startup after an upgrade. A Watchtower-triggered update at 3am with no attention can corrupt the PostgreSQL database with no rollback path. **Immich's four containers must never receive the Watchtower opt-in label:**

```yaml
# NEVER add to these services:
# immich-server, immich-machine-learning, immich-postgres, immich-redis
# com.centurylinklabs.watchtower.enable=true   ← DO NOT ADD
```

Update Immich manually: bump `IMMICH_VERSION` in `.env` after reading the release notes, then `docker compose pull && docker compose up -d`.

### 5. Phase 1 + Phase 2 Arr Network Interaction

Phase 1 puts all arr services on `homelab_net`. Phase 2 adds `arr_internal`. Introducing a new network to an existing stack requires **recreating all containers** in that stack. To avoid a second downtime window for the download pipeline, write the final Phase 2 network config into the arr stack's compose file at the same time as Phase 1 consolidation.

### 6. `services` Stack Size

Consolidating documents + tools + personal + productivity into one `services` stack produces ~15 services. `docker compose down services` will impact all of them simultaneously. If issues arise during debugging, consider a `services-db` split (postgres instances) from `services` (app layer) to allow restarting apps without touching databases.

### 7. Recyclarr `!env_var` YAML Syntax

Recyclarr uses a custom YAML extension tag `!env_var` in its config file (e.g. `api_key: !env_var RADARR_API_KEY`). This is not standard YAML — generic YAML linters will reject it. Only edit `recyclarr.yml` knowing this tag is Recyclarr-specific and requires the Recyclarr binary to parse correctly.

---

## Phase 1 — Stack Consolidation (High Impact, Low Risk)

### Critique of v1 proposal (5 stacks)

The original plan proposed collapsing everything into 5 stacks, including a single `media` stack with 18+ services (jellyfin, seerr, audiobookshelf, navidrome, all \*arrs, gluetun, qbittorrent, byparr, recyclarr...). This is **worse** than the current 11-stack split for operational reasons:

- `docker compose restart jellyfin` works, but `docker compose down media` takes the entire download pipeline offline
- The VPN layer (gluetun/qbittorrent) has very different restart semantics from a media player
- A single 400-line compose file is harder to reason about than purpose-specific files
- TechHutTV themselves keep their media server and download pipeline in separate concerns

### Target: 6 stacks instead of 11

The correct grouping criterion is **restart independence** — services that are always restarted together belong in one stack:

```
current (11)                    → proposed (6)
───────────────────────────────────────────────
core/           (cloudflared)   → infrastructure
monitoring/     (homepage etc)  → infrastructure
arr/            (*arr + gluetun)→ arr        ← keep isolated (VPN complexity)
entertainment/  (jellyfin,seerr)→ media      ← merge entertainment + media + audiobooks
media/          (abs,navidrome) → media
immich/                         → cloud      ← keep isolated (complex internal network)
documents/      (paperless etc) → services   ← merge docs + tools + personal + productivity
tools/          (vaultwarden etc)→ services
personal/       (mealie)        → services
productivity/   (forgejo)       → services
home/           (homeassistant) → home       ← keep isolated (may need host networking)
```

**Proposed 6 stacks:**

| Stack            | Services                                                                                                                                                                         | Why separate                                                                                 |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `infrastructure` | cloudflared, caddy, homepage, uptime-kuma, watchtower, scrutiny                                                                                                                  | Start first; everything depends on DNS/routing being up                                      |
| `arr`            | gluetun, deunhealth, qbittorrent, sabnzbd\*, prowlarr, byparr, radarr, sonarr, lidarr, bookbounty\*, bazarr, jackett\*, recyclarr, unpackerr, autobrr\*, cleanuparr, listenarr\* | VPN namespace requires gluetun+qbittorrent in same compose; all download automation together |
| `media`          | jellyfin, seerr, audiobookshelf, navidrome, feishin, octo-fiesta, crosswatch, yamtrack, maintainerr, kavita\*                                                                    | Pure playback/streaming/tracking; no VPN dependency                                          |
| `cloud`          | immich-server, immich-ml, immich-postgres, immich-redis                                                                                                                          | Isolated internal network; ML workloads separate                                             |
| `services`       | vaultwarden, actual-budget, joplin+postgres, paperless+redis+postgres, stirling-pdf, kiwix, mealie, forgejo, drawio, excalidraw, it-tools, wizarr                                | All productivity/personal services                                                           |
| `home`           | home-assistant                                                                                                                                                                   | May need `network_mode: host` for mDNS/Zigbee; keep isolated                                 |

\ \* jackett: pending audiobookbay-downloader/listenarr migration decision. autobrr: optional. bookbounty: optional if ebook automation desired. kavita: optional if ebook/comics reading needed. sabnzbd: add when Usenet is set up (Phase 10). listenarr: beta software — run alongside abb-downloader initially.

**Why `arr` stays separate from `media`:**

- `network_mode: service:gluetun` only works within the same compose project — gluetun and qbittorrent MUST be in the same stack. All \*arr apps belong alongside them for operational coherence.
- Sonarr/Radarr → Seerr communication works cross-stack via Docker DNS on the shared `homelab_net` bridge; `depends_on` is not required for this.
- Restart/update cadence: \*arr apps update frequently and independently of jellyfin.

**Why `media` is now clean:**

- No VPN services, no databases, purely stateless-ish services
- `jellyfin` + `seerr` in the same stack means `depends_on: jellyfin` works for seerr
- `maintainerr` talks to jellyfin + seerr + sonarr/radarr — it belongs in the media stack since it queries sonarr/radarr over the network, not via Docker dependencies

**Improvement to `up-all.sh`:**

- Goes from 11 sequential commands to 6
- Can launch `infrastructure` → then `arr`, `media`, `cloud`, `services`, `home` in parallel (they only depend on infrastructure being up)

---

## Phase 2 — Networking Overhaul (High Impact, Medium Risk)

### Current: single flat network

All 40+ containers are on `homelab_net`. A compromised container (e.g. a public-facing service) can reach internal services like Vaultwarden directly.

### Proposed: network segmentation

```
homelab_net (external bridge — services that need to communicate cross-stack)
  ├── infrastructure: caddy, cloudflared, homepage, uptime-kuma
  ├── arr: prowlarr, radarr, sonarr, lidarr, bookbounty, bazarr, recyclarr
  │         gluetun (also on homelab_net for WebUI access)
  │         qbittorrent (via gluetun network namespace — NOT directly on homelab_net)
  ├── media: jellyfin, seerr, audiobookshelf, navidrome, maintainerr
  └── services: vaultwarden, forgejo, mealie, joplin, paperless

arr_internal (internal — no external exposure)
  ├── prowlarr, radarr, sonarr, lidarr, bookbounty, bazarr
  └── qbittorrent (via gluetun namespace)
  [services that only talk to each other, no public internet needed]

services_internal (internal — databases + their apps only)
  ├── paperless-postgres, paperless-redis, paperless-ngx
  ├── joplin-postgres, joplin-server
  └── yamtrack-redis, yamtrack

immich_internal (already exists — keep)
```

**Key rule:** Join `homelab_net` only if the service needs cross-stack communication (Caddy routing, Homepage monitoring, Seerr→Radarr calls). Internal databases never join `homelab_net`.

### Caddy, not Nginx Proxy Manager

**Why Caddy over NPM (correction from v1 plan):**

NPM stores all its proxy configuration in a SQLite database inside the container. This means:

- Configuration cannot be version-controlled in git
- Restoring after data loss requires the entire database file
- No diff, no code review, no rollback of routing changes

Caddy uses a plain-text `Caddyfile` that sits in your repo, is version-controlled, and can be reviewed like any other config file. For a git-tracked homelab, this is the correct choice.

NPM's web UI advantage is irrelevant when your routing config is simple and stable (≤20 services).

**Caddy compose service:**

```yaml
caddy:
 image: caddy:alpine
 container_name: caddy
 restart: unless-stopped
 ports:
  - "80:80"
  - "443:443"
  - "443:443/udp" # HTTP/3
 volumes:
  - ../../config/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
  - ../../data/caddy/data:/data
  - ../../data/caddy/config:/config
 networks:
  - homelab_net
```

**`config/caddy/Caddyfile` (example, version-controlled):**

```caddyfile
# Global options
{
  email admin@andreasmaita.com
  # Uncomment when using Cloudflare DNS challenge (for future static IP):
  # acme_dns cloudflare {env.CF_API_TOKEN}
}

# Public services (Cloudflare tunnel handles TLS termination externally)
# These are accessed via localhost since Cloudflare tunnel connects internally:
jellyfin.andreasmaita.com {
  reverse_proxy jellyfin:8096
}

immich.andreasmaita.com {
  reverse_proxy immich-server:2283
}

# LAN-only services (Tailscale IP or local network)
# Caddy issues self-signed certs for .local domains automatically:
homepage.home.arpa {
  reverse_proxy homepage:3000
}

radarr.home.arpa {
  reverse_proxy radarr:7878
}

sonarr.home.arpa {
  reverse_proxy sonarr:8989
}
```

**Modular access switching (Cloudflare tunnel → static IP):**

```
Current:    service → Cloudflare tunnel → public internet
            service → Tailscale → remote access

Phase 2:    service → Caddy → LAN subdomains (self-signed or Cloudflare DNS cert)
            public services still via Cloudflare tunnel

Future:     Open ports 80/443 → Caddy
            Update Caddyfile global block: remove acme_dns comment
            Update DNS: CNAME tunnel → A record static IP
            Remove cloudflared container (or leave dormant)
```

The Caddyfile stays identical. The only change is DNS records and who's terminating TLS on port 443. This is the modular handoff.

**Note on Cloudflare tunnel + Caddy coexistence:** Cloudflare tunnel connects directly to the container port without going through Caddy — cloudflared's config specifies `http://jellyfin:8096` directly. Caddy is for LAN/Tailscale access. Both can coexist.

---

## Phase 3 — \*arr Stack Overhaul

### Full \*arr ecosystem map (selfh.st/apps/?tag=\*arr reviewed)

> **Note on GitHub verification (April 2026):** All tools below have been checked against GitHub activity. Stars, last push date, and archived status confirmed via GitHub API.

| App               | Role                                                        | GitHub Status (Apr 2026)                                                            | Verdict                                                                                                                                                                                                         |
| ----------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Sonarr**        | TV show PVR                                                 | 13.7k ⭐, active, not archived                                                      | ✅ Keep — core                                                                                                                                                                                                  |
| **Radarr**        | Movie PVR                                                   | 13.5k ⭐, active, not archived                                                      | ✅ Keep — core                                                                                                                                                                                                  |
| **Lidarr**        | Music PVR                                                   | 5.3k ⭐, active, not archived                                                       | ✅ Keep — core                                                                                                                                                                                                  |
| **Bazarr**        | Subtitle automation                                         | 3.9k ⭐, active, not archived                                                       | ✅ Keep — integrated with Sonarr/Radarr                                                                                                                                                                         |
| **Prowlarr**      | Indexer aggregator (torrent **and Usenet**)                 | 6.4k ⭐, active, not archived                                                       | ✅ Keep — handles both torrent trackers AND Usenet indexers (Newznab protocol); no NZBHydra2 needed                                                                                                             |
| **Byparr**        | Cloudflare bypass (FlareSolverr replacement)                | 1.4k ⭐, active, not archived                                                       | ✅ Keep — actively maintained                                                                                                                                                                                   |
| **Recyclarr**     | Quality profile/format sync (TRaSH guides)                  | 1.9k ⭐, active, not archived                                                       | ✅ Keep — already working                                                                                                                                                                                       |
| **Unpackerr**     | RAR/ZIP extraction for \*arr imports                        | 1.4k ⭐, active, not archived                                                       | ✅ **Add immediately** — critical gap                                                                                                                                                                           |
| **Seerr**         | Media request portal (Overseerr + Jellyseerr fork)          | 11k ⭐, active, not archived                                                        | ✅ Keep — running (note: upstream Overseerr is archived; Seerr is the correct active continuation)                                                                                                              |
| **Maintainerr**   | Automated cleanup of unwatched media                        | 1.9k ⭐, active, not archived                                                       | ✅ Add — disk space critical                                                                                                                                                                                    |
| **autobrr**       | IRC announce-based torrent grabbing                         | 2.7k ⭐, active, not archived                                                       | 🟡 Optional — for private tracker ratio                                                                                                                                                                         |
| **Jackett**       | Legacy indexer proxy                                        | Active but superseded by Prowlarr                                                   | ⚠️ Remove if audiobookbay-downloader migrates                                                                                                                                                                   |
| **Kavita**        | Ebook / comics / manga reading server                       | 10.4k ⭐, active, not archived                                                      | ✅ Add — modern reading server, replaces LazyLibrarian's UI                                                                                                                                                     |
| **BookBounty**    | Automated ebook download from Library Genesis               | 275 ⭐, active (Apr 2026)                                                           | 🟡 Optional — fills Readarr gap for ebook automation                                                                                                                                                            |
| **LazyLibrarian** | Book manager                                                | Upstream dead since 2018; Docker OK                                                 | ❌ Remove — upstream abandoned 2018; replace with Kavita + BookBounty                                                                                                                                           |
| **Readarr**       | Books/ebooks PVR (\*arr-style)                              | **ARCHIVED Jun 2025** — metadata broken                                             | ❌ **Do not add** — officially retired by the Servarr team; metadata source broken                                                                                                                              |
| **Profilarr**     | Profile/format sync; build/test/deploy configs              | **2.1k ⭐**, V1 stable (v1.1.4 Jan 2026), **V2 actively developed (commits daily)** | ✅ Upgrade path — V1 usable now; V2 adds automated upgrades, renames, jobs. Migrate when V2 goes stable. More capable than Recyclarr long-term.                                                                 |
| **Kapowarr**      | Comic book automated downloading                            | 943 ⭐, active, not archived                                                        | 🟡 Add if comics are in use (pairs with Komga/Kavita)                                                                                                                                                           |
| **Komga**         | Comic/manga reading server                                  | 6.1k ⭐, active, not archived                                                       | 🟡 Alternative to Kavita for comics-only setups                                                                                                                                                                 |
| **SuggestArr**    | Auto-request recommendations from watch history             | Active                                                                              | 🟡 Optional quality-of-life                                                                                                                                                                                     |
| **Tdarr**         | Distributed transcoding automation                          | 4k ⭐, active                                                                       | ❌ Skip — too resource-intensive on laptop                                                                                                                                                                      |
| **Youtarr**       | YouTube channel mirroring                                   | Active                                                                              | 🟡 Optional — only if needed                                                                                                                                                                                    |
| **Wizarr**        | Automated user invitation for Jellyfin/ABS/Kavita           | **2.8k ⭐**, active (v2026.4.0, 29 days ago), 120 contributors                      | ✅ **Add** — automates Jellyfin (+ Audiobookshelf, Kavita, Romm) user onboarding; send a link, user is added automatically with guided setup wizard                                                             |
| **Cleanuparr**    | Removes stalled/blocked/malware downloads from \*arr queues | **2.2k ⭐**, active (v2.9.10, 3 days ago), 131 releases                             | ✅ **Add** — **distinct role from Maintainerr**: Maintainerr manages the _library_ (unwatched content), Cleanuparr manages the _download queue_ (blocked, stalled, malware-flagged torrents that need removing) |
| **Listenarr**     | Audiobook PVR — Sonarr/Radarr but for audiobooks            | **709 ⭐**, active (v0.2.75, yesterday), C# + Vue; **beta software**                | ✅ **Add (user-requested)** — run alongside `audiobookbay-downloader` initially; replace abb-downloader once confirmed stable. **Note:** developer-labeled beta; maintain abb-downloader as fallback.           |
| **Lingarr**       | Automated subtitle translation (local + SaaS)               | **763 ⭐**, active (7 days ago), C#                                                 | 🟡 Optional — useful if non-English subtitle translation is needed; supports local models + DeepL/OpenAI                                                                                                        |
| **Posterizarr**   | Automated textless poster artwork for Jellyfin              | **849 ⭐**, active (v2.2.39, 2 weeks ago), 240 releases                             | 🟡 Optional — fetches textless posters from Fanart.tv/TMDB/TVDB; web UI; triggers from Sonarr/Radarr; PowerShell-based                                                                                          |
| **Dispatcharr**   | IPTV/EPG stream management                                  | 3.2k ⭐, active (v0.23.0, 2 weeks ago)                                              | ❌ Skip — IPTV stream aggregator; no IPTV use case in this homelab                                                                                                                                              |
| **Watcharr**      | Watched-list tracker (movies/TV/anime/games)                | 1.3k ⭐, active (v3.0.1, Mar 2026)                                                  | ❌ Skip — overlaps with yamtrack (already in stack); yamtrack covers the same use case                                                                                                                          |
| **Homarr**        | Dashboard alternative to Homepage                           | **3.7k ⭐** (homarr-labs/homarr), v1.59.3 last week, extremely active               | ❌ Skip — Homepage already in stack. Homarr (v1+, new repo `homarr-labs/homarr`) is a more capable alternative (40+ integrations, OIDC, WebSocket updates) but not worth switching dashboards                   |
| **Riven**         | All-in-one Real-Debrid integration + VFS                    | 784 ⭐, last release Aug 2025 (8 months ago)                                        | ⚠️ Watch — impressive scope but activity slowing; Plex-primary; complex FUSE setup. See Phase 11 for RD strategy.                                                                                               |

---

### Priority 1: Add Unpackerr (Critical)

Many private tracker releases are packaged as RAR archives. Without Unpackerr, qBittorrent downloads these correctly, but Radarr/Sonarr/Lidarr cannot import them — they sit in the download queue indefinitely.

Unpackerr monitors the *arr apps' download queues and extracts archives as soon as a torrent completes, then signals the *arr app to re-import.

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
```

No ports needed — Unpackerr communicates with \*arr apps via their APIs and watches the download paths.

---

### Priority 2: Add Maintainerr (Disk Space Critical)

With Seerr allowing media requests, the single 930GB NVMe will fill up. Maintainerr integrates with Jellyfin + Seerr + Sonarr/Radarr to:

- Identify media that's been added but never watched
- Build rule-based collections (e.g. "added 60 days ago, never played, requested by X")
- Optionally: delete from disk and remove from Seerr request queue

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
```

Configure rules in the Maintainerr UI pointing to Jellyfin, Sonarr, Radarr, and Seerr.

---

### Priority 3: Book Management — Replace LazyLibrarian with Kavita + BookBounty

> **⚠️ IMPORTANT:** The previous version of this plan recommended replacing LazyLibrarian with Readarr. **Readarr has been officially retired by the Servarr team** (archived June 2025). Their README states: _"the project's metadata has become unusable, we no longer have the time to remake or repair it"_. Do not add Readarr.

**State of book automation (as of April 2026):**

This is a genuine community-wide gap. The two most common book tools are either retired or abandoned:

- **Readarr** — officially retired by Servarr; metadata source broken
- **LazyLibrarian** (DobyTang upstream) — last upstream commit was December 2018; LinuxServer builds a Docker image from it but the application itself is effectively abandoned

The selfhosted community has no direct \*arr-equivalent for ebooks that is still active.

**Recommended book stack (two options, pick based on your usage):**

**Option A — Kavita only (if mostly reading, not heavy automated downloading):**

Kavita (10.4k ⭐, actively maintained) is the correct modern replacement for a book-reading server. It handles ebooks (EPUB, PDF), comics, and manga from a single web UI — similar to what Jellyfin is for video. No \*arr-integration needed; you manage a folder and Kavita serves it.

```yaml
kavita:
 image: lscr.io/linuxserver/kavita:latest
 container_name: kavita
 environment:
  - PUID=${PUID}
  - PGID=${PGID}
  - TZ=${TZ}
 volumes:
  - ../../data/kavita/config:/config
  - ${DATA_ROOT}/media/books:/data/books
  - ${DATA_ROOT}/media/comics:/data/comics
 ports:
  - "${KAVITA_PORT}:5000"
 restart: unless-stopped
 networks:
  - homelab_net
```

**Option B — Kavita + BookBounty (if you want automated ebook downloading):**

BookBounty (275 ⭐, actively maintained, last pushed April 2026) was specifically created to fill the gap left by Readarr. It searches Library Genesis for missing books and downloads them. It monitors a Readarr-compatible library path, making it a drop-in workflow replacement.

```yaml
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
```

**Decision table:**

| Scenario                            | Action                                        |
| ----------------------------------- | --------------------------------------------- |
| Audiobooks only                     | audiobookshelf already handles this ✅        |
| Ebooks — reading server only        | Add Kavita, remove LazyLibrarian              |
| Ebooks — want automated downloading | Add Kavita + BookBounty, remove LazyLibrarian |
| Comics/manga                        | Kavita handles these natively too             |
| No active ebook usage               | Remove LazyLibrarian, skip Kavita             |

**Migration from LazyLibrarian:**

LazyLibrarian's book library at `${DATA_ROOT}/media/books` can be pointed to directly by Kavita as a library folder. Kavita will scan and display all existing files. No import needed.

---

### Priority 4: Remove Jackett (pending one test)

Test whether audiobookbay-downloader accepts a Prowlarr Torznab feed URL. The Prowlarr Torznab endpoint format is:

```
http://prowlarr:9696/{indexer-id}/api?apikey={key}&t=search&q={query}
```

If audiobookbay-downloader supports Torznab, remove `jackett`. If not, keep it — it's a small container.

---

### Recyclarr vs Profilarr — Keep Recyclarr

**Recyclarr** syncs quality profiles and custom formats from the TRaSH Guides community database. It's established, well-documented, and already working in this setup.

**Profilarr** (from Dictionarry.dev) is a newer alternative that pulls from the Dictionarry profile database. It uses a more scientific approach to quality scoring (efficiency metrics, Golden Popcorn standards) but requires reconfiguring from scratch and the database is less mature.

**Verdict:** Keep Recyclarr. The TRaSH guide profiles are production-tested for years. Note Profilarr as a future upgrade path if you want to move to Dictionarry's quality methodology.

---

### autobrr — Optional

autobrr monitors IRC announcement channels and grabs new torrents the moment they're uploaded, getting you into the initial seeding swarm for better ratio on private trackers. It integrates with qBittorrent and all \*arr apps.

Only add this if:

1. You use private trackers that require ratio maintenance
2. You're using IRC-announcing indexers (BTN, RED, PTP, etc.)

If your setup is primarily public trackers or Usenet, skip it. autobrr is lightweight (Go binary, ~50MB RAM) so it doesn't meaningfully affect resource usage.

---

### Priority 5: Add Wizarr (User Invitation System)

Wizarr (`wizarrrr/wizarr`) automates adding users to Jellyfin, Audiobookshelf, Kavita, and Romm. Instead of manually creating accounts and explaining the setup, you send a time-limited invite link — the user clicks it, enters their name, and is automatically added to all configured media services. The wizard guides them through downloading apps, setting up the request system (Seerr), etc.

Supports: Plex, Jellyfin, Emby, Audiobookshelf, Romm, Komga, Kavita, OIDC SSO.

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
```

Add to `.env`:

```dotenv
WIZARR_PORT=20071
```

---

### Priority 6: Add Cleanuparr (Download Queue Cleanup)

> **⚠️ Cleanuparr and Maintainerr have different, complementary roles:**
>
> - **Maintainerr** — library-level cleanup: finds and removes _content you've already watched and no longer need_ from Jellyfin, Sonarr, Radarr
> - **Cleanuparr** — queue-level cleanup: removes _download queue entries that are stalled, blocked, contain malware, or have been sitting forever_ from qBittorrent and the \*arr apps

Cleanuparr addresses a real common problem: malicious `.lnk`/`.zipx` files from bad actors on public trackers that get downloaded, fail to import, and pile up in the \*arr queue requiring manual intervention. It also handles slow/stalled torrents, orphaned downloads, and quality upgrade cleanup.

Key features:

- Strike system: marks bad downloads; removes and blacklists after N strikes
- Removes downloads blocked by qBittorrent (tracked as malware/malicious)
- Removes stalled downloads and metadata-stuck downloads
- Removes downloads failing to import (bad file structure, wrong codec, etc.)
- Proactively searches for missing/cutoff-unmet items after cleanup
- Seeding time limits for completed downloads
- Supports Sonarr, Radarr, Lidarr, qBittorrent, Transmission, Deluge

```yaml
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
```

Add to `.env`:

```dotenv
CLEANUPARR_PORT=20072
```

Configure via the web UI at `http://localhost:20072`. Point it at your qBittorrent instance and each \*arr app.

---

### Priority 7: Add Listenarr (Audiobook Management — User-Requested)

> **User request:** Add Listenarr alongside `audiobookbay-downloader`. Run both in parallel — migrate to Listenarr once it's confirmed stable, then retire abb-downloader.

**What it is:** Listenarr (`Listenarrs/Listenarr`) is an automated audiobook collection manager modelled directly on Sonarr/Radarr. It searches multiple torrent/NZB indexers for audiobooks, manages downloads via qBittorrent/SABnzbd/Transmission, organises files with intelligent naming, and enriches metadata from Audible.

**Current state (as of April 2026):**

- 709 ⭐, actively developed (commits daily, v0.2.75)
- Developer self-labels it **beta software**: _"There may be security exploits despite best efforts. Expose this software to the internet at your own risk."_
- Developer transparency note: _"This is just a fun side project... I will choose my work, family, and mental health before this project"_
- No `latest`/`stable` Docker tag yet — only `canary` (pre-release) and `beta` tags
- Roadmap includes Audiobookshelf integration (not yet implemented)
- Supports: qBittorrent, Transmission, SABnzbd, NZBGet

**Strategy:** Run Listenarr on `canary` tag alongside abb-downloader. Use it for new audiobook requests. If it handles your audiobook series well for 4–8 weeks, retire abb-downloader. Keep Jackett until Listenarr is confirmed working with Prowlarr indexers.

```yaml
listenarr:
 image: ghcr.io/listenarrs/listenarr:canary
 container_name: listenarr
 environment:
  - PUID=${PUID}
  - PGID=${PGID}
  - UMASK=022
  - TZ=${TZ}
  - LISTENARR_PUBLIC_URL=https://listenarr.yourdomain.com # optional, for Discord bot
 volumes:
  - ../../data/listenarr/config:/app/config
  - ${DATA_ROOT}/media/audiobooks:/audiobooks
  - ${DATA_ROOT}/torrents/audiobooks:/downloads/torrents # qBittorrent staging
  - ${DATA_ROOT}/usenet/audiobooks:/downloads/usenet # SABnzbd staging (if using Usenet)
 ports:
  - "${LISTENARR_PORT}:4545"
 restart: unless-stopped
 networks:
  - homelab_net
```

Add to `.env`:

```dotenv
LISTENARR_PORT=20073
```

**Note on Jackett:** Keep Jackett running while testing Listenarr. If Listenarr integrates cleanly with Prowlarr (via Torznab indexers), remove Jackett at that point.

**Note on audiobookbay-downloader:** Keep it running in parallel during the evaluation period. Both can coexist without conflict as they use separate library paths and download queues.

--- (Critical on Single NVMe)

This was missing from the original plan. On a single NVMe with no RAID or redundancy, a drive failure is total data loss. Backup must be implemented before doing any structural overhaul.

### What to back up

| Data                                 | Size estimate  | Priority                      |
| ------------------------------------ | -------------- | ----------------------------- |
| `homelab-data/` (configs, HA config) | < 100MB        | Critical — git push is enough |
| `data/immich_upload/`                | Large (photos) | Critical — irreplaceable      |
| `data/paperless/`                    | Medium         | Critical — documents          |
| `data/vaultwarden/`                  | Small          | Critical — passwords          |
| `data/forgejo/`                      | Medium         | High — code repos             |
| `data/joplin/`                       | Small          | High — notes                  |
| `data/actual-budget/`                | Small          | High                          |
| `data/mealie/`                       | Small          | Medium                        |
| `data/home-assistant/`               | Small          | Medium                        |
| `data/media/` (movies/TV)            | Very large     | Low — re-downloadable         |
| `data/music/`                        | Large          | Medium — harder to replace    |
| `data/audiobooks/`                   | Large          | Medium                        |

### Backup approach

**Tier 1 — Offsite (rclone → Backblaze B2 / Cloudflare R2):**

```yaml
# In services stack:
rclone:
 image: rclone/rclone:latest
 container_name: rclone-backup
 environment:
  - TZ=${TZ}
 volumes:
  - ../../data:/source:ro
  - ../../config/rclone:/config/rclone:ro
  - /tmp/rclone:/tmp
 # Run daily via cron in a wrapper script, not as daemon
 # docker run --rm rclone/rclone:latest sync /source/vaultwarden r2:backup-bucket/vaultwarden
 profiles:
  - backup # opt-in: docker compose --profile backup run rclone
 networks:
  - homelab_net
```

Better: a dedicated `scripts/backup.sh` that runs `rclone sync` for critical directories:

```bash
#!/usr/bin/env bash
# backup.sh — run via cron: 0 3 * * * /home/a-p-maita/homelab-config/scripts/backup.sh
set -euo pipefail

CRITICAL_DIRS="vaultwarden paperless/media paperless/export immich_upload forgejo/git joplin actual-budget"
DATA_ROOT="/home/a-p-maita/homelab-config/data"
REMOTE="r2:homelab-backup"  # or "b2:bucket-name"

for dir in $CRITICAL_DIRS; do
  echo "[backup] Syncing $dir..."
  docker run --rm \
    -v "${DATA_ROOT}:/source:ro" \
    -v "${HOME}/.config/rclone:/config/rclone:ro" \
    rclone/rclone:latest sync "/source/${dir}" "${REMOTE}/${dir}" \
    --transfers=4 --checksum --log-level=INFO
done

echo "[backup] Git push config..."
cd /home/a-p-maita/homelab-config && git add -A && git diff-index --quiet HEAD || git commit -m "auto: config backup $(date -I)" && git push
```

**Tier 2 — Local snapshots (btrfs/cp --reflink if on btrfs, or rsync):**

If the NVMe filesystem supports `--reflink` (btrfs/XFS), weekly local snapshots of `/data` cost minimal extra space.

**Tier 3 — Git (already in place for compose files + configs):**

The repo itself is the backup for all compose files and config templates. Keep pushing regularly.

### Database backup before any overhaul

Before doing Phase 1 (stack consolidation), dump all databases:

```bash
# scripts/backup-dbs.sh
docker exec immich-postgres pg_dumpall -U postgres > backups/immich-$(date -I).sql
docker exec paperless-postgres pg_dumpall -U paperless > backups/paperless-$(date -I).sql
docker exec joplin-postgres pg_dumpall -U joplin > backups/joplin-$(date -I).sql
```

---

## Phase 5 — Monitoring Upgrade

### Add Prometheus + Node Exporter + Grafana

Currently only Uptime Kuma (HTTP uptime) and Homepage (status widgets). No system metrics (CPU, RAM, disk I/O, network).

On a laptop with a single NVMe, disk health monitoring is critical:

```yaml
# Add to infrastructure stack:
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
 network_mode: host # needs host network for full system visibility
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
```

**Dashboards to import:**

- **Node Exporter Full (ID: 1860)** — CPU, RAM, disk I/O, network, thermal throttling
- **Docker container stats (ID: 893)** — per-container resource usage

### Add Scrutiny (NVMe SMART monitoring)

Single NVMe with no redundancy — early warning of drive failure is the most important monitoring this setup can have:

```yaml
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
```

Scrutiny runs scheduled SMART tests and alerts via email/webhook when attributes go out of spec. **Set up an alert webhook (Discord or email) on day one.**

### Fix Watchtower

Watchtower auto-updates ALL containers at 3am. This is dangerous for databases. A postgres major version bump can silently corrupt data that requires manual migration to recover.

**Recommended approach — opt-in mode:**

```yaml
# In monitoring stack / infrastructure stack:
watchtower:
  image: containrrr/watchtower:latest
  command: --label-enable --cleanup --schedule "0 0 3 * * *"
  ...
```

Then in each service definition, add a label to opt-in:

```yaml
labels:
 - "com.centurylinklabs.watchtower.enable=true"
```

**Never add this label to:** immich-postgres, paperless-postgres, joplin-postgres, or any database container.

---

## Phase 6 — File Structure Realignment

**Do this simultaneously with Phase 1**, not after. Building new compose files in the new location is easier than moving files after they're already wired up.

### Proposed structure

```
homelab-config/
├── .env                          # all secrets + ports (gitignored)
├── .env.example                  # tracked — document EVERY variable
├── .gitignore
├── README.md
├── FIRST-RUN.md
├── overhaul-plan.md
│
├── stacks/                       # replaces dockerfiles/ — cleaner name, same concept
│   ├── infrastructure/
│   │   └── compose.yaml          # caddy, cloudflared, homepage, uptime-kuma, watchtower,
│   │                             # prometheus, node-exporter, grafana, scrutiny
│   ├── arr/
│   │   ├── compose.yaml          # qbittorrent, prowlarr, byparr, radarr, sonarr, lidarr,
│   │   │                         # bookbounty*, bazarr, jackett*, recyclarr, unpackerr, autobrr*
│   │   └── compose.vpn.yaml      # gluetun, deunhealth overlay
│   ├── media/
│   │   └── compose.yaml          # jellyfin, seerr, audiobookshelf, navidrome, feishin,
│   │                             # octo-fiesta, crosswatch, yamtrack, maintainerr, kavita*
│   ├── cloud/
│   │   ├── compose.yaml          # immich (upstream file — update from upstream periodically)
│   │   └── compose.override.yaml # our volume paths, network, labels
│   ├── services/
│   │   └── compose.yaml          # vaultwarden, actual-budget, joplin+postgres, paperless,
│   │                             # stirling-pdf, kiwix, mealie, forgejo, drawio,
│   │                             # excalidraw, it-tools
│   └── home/
│       └── compose.yaml          # home-assistant
│
├── config/                       # replaces config-templates/ — source-of-truth seed configs
│   ├── caddy/
│   │   └── Caddyfile             # ← version-controlled routing config
│   ├── homepage/
│   ├── prometheus/
│   │   └── prometheus.yml
│   ├── qbittorrent/
│   ├── recyclarr/
│   └── ...
│
├── homelab-data/                 # KEEP this name (current live configs, partially tracked)
│   ├── home-assistant/           # HA config files — tracked
│   ├── crosswatch/               # crosswatch config — tracked
│   └── ...
│
└── scripts/
    ├── up-all.sh
    ├── down-all.sh
    ├── compose-pull-all.sh
    ├── restart-update-all.sh
    ├── seed-configs.sh           # NEW: extracted config seeding from up-all.sh
    ├── backup.sh                 # NEW: rclone offsite backup
    ├── backup-dbs.sh             # NEW: postgres dump before overhaul
    ├── setup-uptime-kuma.sh
    └── update-qbt-port.sh
```

### Key changes from current structure

| Current                            | Proposed                                | Reason                                         |
| ---------------------------------- | --------------------------------------- | ---------------------------------------------- |
| `dockerfiles/`                     | `stacks/`                               | Cleaner name; aligns with mental model         |
| `config-templates/`                | `config/`                               | These are the source of truth, not "templates" |
| `dockerfiles/arr/compose.vpn.yaml` | `stacks/arr/compose.vpn.yaml`           | Same pattern, new location                     |
| (missing)                          | `stacks/arr/` contains unpackerr        | New addition                                   |
| (missing)                          | `stacks/media/` contains maintainerr    | New addition                                   |
| (missing)                          | `stacks/infrastructure/` contains caddy | NPM → Caddy                                    |

### `data/` vs `homelab-data/`

**The naming is ambiguous and should be resolved:**

- `homelab-data/` in the workspace appears to contain LIVE configs that ARE tracked in git (HA config, crosswatch config, etc.)
- `data/` (`DATA_ROOT`) contains runtime data that is gitignored (downloads, media, postgres volumes)

**Clarification:** Keep `homelab-data/` as-is for tracked config files. The `data/` path for `DATA_ROOT` is fine — it lives outside git tracking.

### Extract `seed-configs.sh`

`up-all.sh` currently mixes "create directories + seed configs" with "launch stacks". This means re-running `up-all.sh` re-evaluates all seeding logic on every invocation. Extract to:

```bash
#!/usr/bin/env bash
# seed-configs.sh — idempotent, safe to re-run
# Copies config/ → data/ for each service, only if destination doesn't exist
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

seed_if_missing() {
  local src="$1" dst="$2"
  if [ ! -f "$dst" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "[seed] Created $dst"
  fi
}

seed_if_missing "$REPO_ROOT/config/qbittorrent/qBittorrent.conf" \
               "$REPO_ROOT/data/qbittorrent/config/qBittorrent.conf"
# ... etc
```

---

## Phase 7 — Access Layer Decisions (Modular Design)

### Service exposure matrix

| Service              | Cloudflare Tunnel          | Caddy (LAN/Tailscale)   | Notes                                      |
| -------------------- | -------------------------- | ----------------------- | ------------------------------------------ |
| Jellyfin             | ✅ Public                  | ✅ `jellyfin.home.arpa` | Family access                              |
| Immich               | ✅ Public                  | ✅ `immich.home.arpa`   | Family photos                              |
| Vaultwarden          | ✅ (Bitwarden needs HTTPS) | ✅                      | Bitwarden mobile apps require public HTTPS |
| Navidrome            | ✅ (Feishin external URL)  | ✅                      |                                            |
| Forgejo              | ✅                         | ✅                      | Git push from anywhere                     |
| Audiobookshelf       | ✅                         | ✅                      | Mobile app sync                            |
| Homepage             | ❌ Never public            | ✅ `home.home.arpa`     | Admin dashboard                            |
| Radarr/Sonarr/Lidarr | ❌                         | ✅                      | \*arr apps never public                    |
| qBittorrent WebUI    | ❌                         | Tailscale only          | Too sensitive for even LAN                 |
| Uptime Kuma          | ❌                         | ✅                      |                                            |
| Paperless            | ❌                         | ✅                      |                                            |
| Maintainerr          | ❌                         | ✅                      |                                            |
| Prowlarr/Bazarr      | ❌                         | ✅                      |                                            |
| Home Assistant       | ❌                         | ✅                      | Use HA Cloud for external                  |
| Grafana              | ❌                         | ✅                      |                                            |

### Switching from Cloudflare tunnel to static IP + port forward

When a static IP or port forwarding becomes available (the modular handoff):

1. **Keep Caddy** — it already handles SSL (via Let's Encrypt)
2. **Update Caddyfile global block:** uncomment `acme_dns cloudflare` for DNS-01 challenge
3. **Open ports 80/443** on router → Caddy container
4. **Update DNS:** Change each subdomain from CNAME pointing to tunnel to A record pointing to your IP
5. **Stop cloudflared** container (or leave dormant)

No compose file changes needed except removing/commenting `cloudflared`. This is the full handoff.

---

## Phase 8 — Resource Optimisation (Laptop-Specific)

### Memory pressure analysis

With new services added (Unpackerr, Maintainerr, autobrr, Caddy, Prometheus, Grafana, node-exporter, Scrutiny, Kavita, SABnzbd, Wizarr, Cleanuparr, Listenarr), the container count grows to ~58. Estimate:

| Tier                     | Services                                                           | Est. RAM    |
| ------------------------ | ------------------------------------------------------------------ | ----------- |
| Heavy                    | immich-ml (2G), immich-server (2G), jellyfin (1G)                  | ~5G         |
| Medium                   | paperless, radarr, sonarr, lidarr, kavita, home-assistant, grafana | ~2.5G       |
| Light                    | all others combined (~40 containers)                               | ~3G         |
| System + Docker overhead |                                                                    | ~2G         |
| **Total**                |                                                                    | ~12.5G peak |

14GB RAM — still acceptable with ~1.5G headroom. If memory pressure shows in Grafana:

- Disable `immich-machine-learning` if smart search is unused (saves 2GB)
- Set `GF_RENDERING_RENDERER_TOKEN=false` in Grafana to disable image renderer
- Check for Java-based containers with oversized heap allocations

### Jellyfin hardware transcoding (AMD Ryzen 5 5500U)

The 5500U has Vega 7 integrated graphics. Enable hardware transcoding:

```yaml
jellyfin:
 devices:
  - /dev/dri:/dev/dri # AMD GPU device
 group_add:
  - "video"
  - "render"
```

In Jellyfin dashboard: Playback → Hardware Acceleration → VA-API → `/dev/dri/renderD128`. This moves transcoding from CPU to iGPU, dramatically reducing thermal throttling.

### NVMe tuning

```bash
# /etc/udev/rules.d/60-scheduler.rules
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
```

NVMe drives perform best with the `none` (noop) I/O scheduler. The default `mq-deadline` adds unnecessary latency for direct-attached NVMe.

### `vm.swappiness`

With 14GB RAM and 50+ containers, set swappiness to push inactive pages to swap before OOM killing containers:

```bash
# /etc/sysctl.d/99-homelab.conf
vm.swappiness = 10
vm.vfs_cache_pressure = 50
```

---

## Phase 9 — Quick Wins (Can Do Anytime, No Risk)

### 1. Move `TZ` to `.env`

All services have `- TZ=Europe/London` hardcoded. Move to `.env`:

```dotenv
TZ=Europe/London
```

Then in compose files: `- TZ=${TZ}`. Affects all 11 compose files (do in one pass when migrating to new structure).

### 2. Add `BAZARR_PORT` to `.env`

Currently hardcoded in compose. Add:

```dotenv
BAZARR_PORT=20061
```

### 3. Pin Immich version

`IMMICH_VERSION=release` is fine for Watchtower-managed updates, but Immich has breaking DB migrations. Pin and update consciously:

```dotenv
IMMICH_VERSION=v1.131.0  # update intentionally
```

Remove from Watchtower's opt-in list. Update manually by bumping this version and running `docker compose pull`.

### 4. Consolidate duplicate postgres instances

Running `postgres:16-alpine` for both Joplin and Paperless separately. These can share one instance with separate databases:

- **Saves ~256MB RAM** and one postgres process
- **Simplifies backups** — one `pg_dumpall` covers both
- Requires a one-time migration (dump Joplin DB, restore into shared instance)

Only do this if comfortable with postgres administration. The RAM saving is real but the migration risk is non-zero.

### 5. `docker-model-runner` cleanup

Stop and remove: `docker stop docker-model-runner && docker rm docker-model-runner`. It's a Docker Desktop AI feature, not part of this homelab's compose definition, and will not be restarted by `up-all.sh`.

### 6. `.env.example` completeness

Every new service added (Kavita, BookBounty, Maintainerr, Unpackerr, Caddy, Prometheus, Grafana, Scrutiny, autobrr, SABnzbd) needs port and API key variables documented in `.env.example` with placeholder values and comments.

---

## Phase 10 — Usenet Integration

Usenet is a distinct download pipeline that complements torrents. It should be considered alongside the \*arr stack, not as a replacement for it.

### What is Usenet?

Usenet is a distributed content network established in 1980, operating on the NNTP protocol. Binary content (movies, TV, music, books, software) is posted to newsgroups, automatically propagated across provider server networks worldwide, and retained for days to years.

**How it differs from torrents:**

| Dimension                | Torrents                              | Usenet                                                    |
| ------------------------ | ------------------------------------- | --------------------------------------------------------- |
| Speed                    | Variable — depends on seeders         | Full line speed from provider server                      |
| Ratio requirements       | Yes (private trackers)                | None — flat monthly subscription                          |
| Retention                | Depends on seeder availability        | 4000+ days on top providers (~11 years)                   |
| Old/obscure content      | Zero seeds = unavailable              | Often still available from retention                      |
| Privacy (ISP visibility) | ISP sees encrypted traffic (with VPN) | SSL/TLS built-in — ISP sees only encrypted NNTP-over-TLS  |
| VPN requirement          | Recommended for privacy               | Not required for downloading; optional for indexer access |
| Completion               | Varies by swarm size                  | 99.9%+ on top providers                                   |

**NZB files:** The Usenet equivalent of a torrent file — an XML document listing all the message IDs of a file's parts. Sent to SABnzbd to trigger a download from your provider.

**PAR2 repair:** Posts include PAR2 parity files. If a few article parts are missing (partial propagation failure), SABnzbd reconstructs the missing data from the parity blocks automatically. This is what enables the 99.9%+ effective completion rate.

### Components Required

Three components are needed (compare: torrents need qBittorrent + Prowlarr + trackers):

1. **Provider** — A paid service giving you access to Usenet article storage over SSL. You pay monthly (~€5–15/month) or buy a data block (pay per GB, no expiry). Most EU providers retain binaries for 4000+ days.

2. **Indexer** — A website that crawls Usenet newsgroups and indexes releases into searchable NZB files. Like torrent trackers, but for Usenet. **Prowlarr already supports Usenet indexers via the Newznab protocol** — no additional aggregator needed.

3. **Download client — SABnzbd** — Receives NZBs from Prowlarr/*arr apps, connects to your provider, downloads and reassembles file parts, verifies PAR2 checksums, repairs if needed, and notifies the *arr app when complete.

### Tool Decisions

| Tool                                  | GitHub Status (Apr 2026)          | Verdict                                                                                |
| ------------------------------------- | --------------------------------- | -------------------------------------------------------------------------------------- |
| **SABnzbd**                           | 2,899 ⭐, pushed Apr 2026, active | ✅ Use — the correct active Usenet download client                                     |
| **NZBGet** (original `nzbget/nzbget`) | **ARCHIVED Nov 18, 2022**         | ❌ Do not use — unmaintained for 3+ years                                              |
| **nzbget-ng** (community fork)        | 262 ⭐, low activity              | ⚠️ Community fork; no active support infrastructure                                    |
| **NZBHydra2**                         | Active                            | ⚠️ Skip — Prowlarr already aggregates Usenet indexers natively; NZBHydra2 is redundant |

**Why skip NZBHydra2:** NZBHydra2 is a Usenet meta-indexer that aggregates multiple indexers into one API. Prowlarr already does exactly this for both torrent trackers AND Usenet indexers. Adding SABnzbd is the only new container required for complete Usenet integration.

### Provider Recommendations (EU/UK, 2026)

The r/usenet community organises providers by backbone infrastructure. The major backbones are Highwinds (owns Eweka, Newshosting, TweakNews servers in Amsterdam) and independent providers. Using two providers from **different backbones** achieves near-100% completion even when one has propagation failures.

**Primary provider (subscription):**

| Provider        | Backbone                         | Location    | Takedown policy | Recommended for                                                   |
| --------------- | -------------------------------- | ----------- | --------------- | ----------------------------------------------------------------- |
| **Eweka**       | Highwinds (Eweka AMS)            | Netherlands | NTD (Dutch law) | EU/UK — fastest EU servers; NTD law means slower forced removals  |
| **TweakNews**   | Highwinds (Tweaknews AMS)        | Netherlands | NTD             | EU/UK; slightly cheaper than Eweka; same Highwinds infrastructure |
| **Newshosting** | Highwinds (Newshosting AMS + US) | NL + US     | DMCA            | Good if you also want US servers                                  |

> **NTD vs DMCA:** Dutch Notice-and-Takedown law requires a formal legal process to remove content; DMCA (US) can be actioned faster. For practical purposes, NTD providers (Eweka, TweakNews) have better content availability on recent posts.

**Secondary/fill provider (block account — different backbone):**

| Provider          | Backbone                       | Type                          | Notes                                                                |
| ----------------- | ------------------------------ | ----------------------------- | -------------------------------------------------------------------- |
| **FrugalUsenet**  | NetNews (US)                   | Block (pay per GB, no expiry) | Very cheap; different backbone from Highwinds; perfect fill provider |
| **UsenetExpress** | UsenetExpress (independent US) | Block/sub                     | Independent backbone; good for fills                                 |

> **Starter recommendation (UK/EU):**
>
> - Primary: **Eweka** (~€7/month subscription) — full retention, EU, NTD
> - Secondary: **FrugalUsenet** block (~$5–15 one-time, lasts months) — different backbone for fills
>
> Two providers from different backbones = near-100% completion on any release.

### Indexer Recommendations

All indexers are configured in **Prowlarr** (Settings → Indexers → Add Indexer → Usenet category → Newznab protocol). Enter the indexer's URL and your API key from the indexer account. No NZBHydra2 container needed.

| Indexer                    | Registration | Cost                                 | Notes                                                      |
| -------------------------- | ------------ | ------------------------------------ | ---------------------------------------------------------- |
| **NZBGeek**                | Open signup  | ~$12/year (paid lifetime or yearly)  | Large index, active community, widely regarded on r/usenet |
| **NZBFinder**              | Open signup  | Freemium (limited free API hits/day) | Good starting point; free tier enough for testing          |
| **altHUB**                 | Open signup  | Free + paid tier                     | Decent free tier; open signup                              |
| **DrunkenSlug**            | Invite only  | Paid                                 | High quality; get invite via r/usenetinvites               |
| **NZBIndex** / **NZBKing** | Open         | Free                                 | Public indexes; lower quality but zero cost                |

> **Starter:** Sign up for **NZBFinder** (free tier for testing) and **NZBGeek** (paid, open signup). Add both to Prowlarr. Private invite-only indexers (DrunkenSlug) are worth adding once the setup is working.

### SABnzbd Compose Service

Add to the `arr` stack (`stacks/arr/compose.yaml`). SABnzbd runs on `homelab_net` directly — it does **not** route through gluetun. Usenet providers are connected to over SSL (port 563 or 443), no VPN needed:

```yaml
sabnzbd:
 image: lscr.io/linuxserver/sabnzbd:latest
 container_name: sabnzbd
 environment:
  - PUID=${PUID}
  - PGID=${PGID}
  - TZ=${TZ}
 volumes:
  - ../../data/sabnzbd/config:/config
  - ${DATA_ROOT}:/data
 ports:
  - "${SABNZBD_PORT}:8080"
 restart: unless-stopped
 networks:
  - homelab_net
```

Add to `.env`:

```dotenv
SABNZBD_PORT=20070
SABNZBD_API_KEY=  # fill after first run
```

### Path Structure — Add `/data/usenet/` Alongside `/data/torrents/`

```
${DATA_ROOT}/
├── torrents/         # existing (qBittorrent)
│   ├── movies/
│   ├── tv/
│   ├── music/
│   ├── books/
│   └── incomplete/
├── usenet/           # NEW (SABnzbd)
│   ├── movies/
│   ├── tv/
│   ├── music/
│   ├── books/
│   └── incomplete/
└── media/            # final library (unchanged)
    ├── movies/
    ├── tv/
    ├── music/
    ├── books/
    ├── audiobooks/
    └── podcasts/
```

SABnzbd categories (configured in SABnzbd → Settings → Categories):

| Category | Path in SABnzbd       | \*arr app that reads it |
| -------- | --------------------- | ----------------------- |
| `tv`     | `/data/usenet/tv`     | Sonarr                  |
| `movies` | `/data/usenet/movies` | Radarr                  |
| `music`  | `/data/usenet/music`  | Lidarr                  |
| `books`  | `/data/usenet/books`  | BookBounty              |

### Integration Steps (in order)

1. **Add SABnzbd to arr stack** — add the compose snippet above. `docker compose up -d sabnzbd`. First-run URL: `http://localhost:20070`.

2. **Configure SABnzbd — provider credentials:** Settings → Servers → Add Server. Enter your Eweka (or other provider) hostname (`news.eweka.nl`), port `563`, SSL on, your account username and password. Test connection.

3. **Configure SABnzbd — categories:** Settings → Categories. Add each category from the table above with the corresponding `/data/usenet/` path. Set the default category in the General settings.

4. **Prowlarr — add Usenet indexers:** Settings → Indexers → Add Indexer. Filter for Usenet. Select `NZBFinder` or `NZBGeek` (Newznab). Enter the indexer URL and API key from your indexer account. Sync to \*arr apps.

5. **Radarr/Sonarr/Lidarr — add SABnzbd as download client:** Settings → Download Clients → Add → SABnzbd. Host: `sabnzbd`, Port: `8080`, API key from SABnzbd settings. Each \*arr app will now route releases to either qBittorrent or SABnzbd based on the indexer source. Usenet indexers automatically route to SABnzbd.

6. **Unpackerr — add SABnzbd monitoring:** SABnzbd handles its own RAR/ZIP extraction natively (Settings → Switches → Post-Processing). Unpackerr is not required for SABnzbd extractions, but add the monitoring connection so Unpackerr can signal completion status to \*arr apps:

   ```
   UN_SABNZBD_0_URL=http://sabnzbd:8080
   UN_SABNZBD_0_API_KEY=${SABNZBD_API_KEY}
   ```

7. **Add secondary provider (optional):** In SABnzbd → Settings → Servers, add a second server (e.g. FrugalUsenet: `news.frugalusenet.com`, port `563`). Set Priority to `1` (lower priority than primary). SABnzbd will automatically fall back to it for missing articles.

### Cost Summary

| Item                         | Cost                  | Frequency                               |
| ---------------------------- | --------------------- | --------------------------------------- |
| Eweka provider               | ~€7/month (~€85/year) | Monthly subscription                    |
| FrugalUsenet block           | ~$5–15                | One-time (lasts months at moderate use) |
| NZBGeek indexer              | ~$12/year             | Annual                                  |
| NZBFinder (optional upgrade) | ~$10/year             | Annual                                  |
| **Total approximate**        | ~€100–110/year        | —                                       |

Usenet's principal advantage is **reliability for older or obscure content** that has no active seeders on any torrent tracker, combined with full line-speed downloads without VPN overhead or ratio management. For content released in the last 11 years, Usenet completion is consistently higher than any single torrent tracker.

---

## Phase 11 — Real-Debrid Integration (Optional)

> **Context:** User has Real-Debrid access and runs Stremio + RD for easy low-configuration streaming. This phase evaluates whether and how the homelab \*arr stack should also interact with Real-Debrid.

### What is Real-Debrid?

Real-Debrid (RD) is a "debrid" service: a cloud-hosted torrent caching system. When you add a magnet link to RD, if that torrent is already in their cache, the files are immediately available over HTTPS at full speed with no seeding, no ratio, and no VPN required for downloading. If it's not cached, RD downloads it to their servers on your behalf.

The practical benefit: nearly all popular torrents (movies, TV) are in the RD cache. You get instant full-speed access to them without running a torrent client or managing a seeding ratio.

### Current Setup — Keep As-Is (Recommended Starting Point)

The user's current Stremio + RD setup handles **casual streaming** beautifully: search, click, watch. No configuration needed.

**This is the correct primary use case for RD.** The homelab \*arr stack handles everything else: library organisation, subtitles (Bazarr), audiobooks, music, request management (Seerr), metadata scrapers (Recyclarr), and long-tail content.

**The two systems work independently** — there is no technical conflict between running both.

### Homelab Stack Integration Options (Evaluated)

If you want \*arr apps to also use RD as a content source (so Radarr/Sonarr search the RD cache), there are three approaches. They are listed in order of increasing complexity:

---

#### Option 1: Torrentio as a Prowlarr Indexer (Zero Extra Containers)

Torrentio is a Stremio addon that also exposes a Torznab-compatible API. It sources results from the RD cache (and other services). Prowlarr can use a Torrentio instance as a Torznab indexer.

**How it works:**

1. Add a Torrentio instance (public or self-hosted) to Prowlarr as a Torznab indexer with your RD API key
2. Radarr/Sonarr search Prowlarr → Torrentio returns cached RD links
3. A download client (e.g. `rdt-client`) intercepts RD links and triggers the RD cloud download instead of a real torrent download
4. Files arrive directly from RD servers at full speed

**Practical limitation:** This requires `rdt-client` (a small container that acts as a fake qBittorrent client but actually calls the RD API). Additional complexity for minimal gain if the main use case is already covered by Stremio.

**Verdict:** Possible but adds `rdt-client` complexity. Most useful if you want Radarr/Sonarr to automatically grab new releases via RD cache.

---

#### Option 2: Zurg + rclone FUSE Mount (Complex, Most Powerful)

**Zurg** (`debridmediamanager/zurg-testing`) mounts your entire RD torrent library as a WebDAV filesystem via rclone. Every torrent you've added to RD appears as a local directory — \*arr apps and Jellyfin see it as local files.

**Current state:**

- Public free version: `v0.9.3-final` (July 2024) — functional but 10 months behind
- Newer `v0.10.x` is sponsorware (Patreon-gated) — not freely available
- 859 ⭐ on `zurg-testing` repo

**How it works:**

```
RD cache → Zurg WebDAV → rclone FUSE mount → /mnt/realdebrid/ on host → Jellyfin/Radarr volume
```

**Implementation complexity (high):**

- Requires `user_allow_other` in `/etc/fuse.conf`
- Requires `--allow-other` on the rclone FUSE mount
- Requires the mount directory to be a bind-mount marked `rshared` (run once per boot)
- Docker volume propagation: containers need `:rshared` or `:rslave` bind mounts
- Stale mount handling after crashes (need `fusermount -uz` before restart)
- systemd unit or fstab entry to survive reboots

**Verdict:** Powerful for building a full RD-backed library, but the public version is behind and the setup complexity is non-trivial on a laptop homelab. Worth revisiting if `v0.10.x` sponsorware becomes free.

---

#### Option 3: Riven (All-in-One RD Integration)

Riven (`rivenmedia/riven`, 784 ⭐) combines RD integration, a virtual filesystem (RivenVFS), watchlist sync from Overseerr/Trakt/Plex, and scraping from Torrentio/Comet/Jackett into one container. It creates symlinks in a VFS directory; Plex/Jellyfin serve files from there while RD actually streams them.

**Current state:**

- Last stable release: `v0.23.6` (August 2025 — **8 months ago**)
- Most recent commits are 3–5 weeks old (maintenance only)
- Activity has clearly slowed compared to its peak
- Plex-primary by design; Jellyfin support is listed but less tested
- Complex startup order, shared bind mounts, FUSE requirements identical to Zurg

**Verdict:** Impressive scope but maintenance trajectory is concerning for a self-hosted dependency. Not recommended for a production homelab right now. Revisit if development resumes actively.

---

### Recommended Strategy

| Priority                 | Action                                           | Reason                                                                                     |
| ------------------------ | ------------------------------------------------ | ------------------------------------------------------------------------------------------ |
| **Immediate**            | Keep Stremio + RD as-is                          | It works perfectly for casual streaming; zero overhead                                     |
| **Optional later**       | Add `rdt-client` + Torrentio indexer in Prowlarr | If you want Radarr/Sonarr to automatically grab releases via RD cache; one extra container |
| **Future consideration** | Zurg + rclone mount                              | If `v0.10.x` becomes freely available and you want RD as your primary library source       |
| **Skip**                 | Riven                                            | Activity too slow; Plex-primary; complex FUSE setup                                        |

**The clean architecture:** Stremio + RD for "what's new and popular" (streaming). Homelab \*arr stack for "full library, long-tail content, audiobooks, music, subtitles, backlog". The two are complementary, not competing.

---

## Revised Implementation Order

The original v1 order had Phase 5 (file structure) coming after Phase 1 (consolidation), which is backwards — you want the new structure in place when writing new compose files.

| Phase                        | What                                                        | Effort | Risk   | When                                |
| ---------------------------- | ----------------------------------------------------------- | ------ | ------ | ----------------------------------- |
| Phase 9 (quick wins)         | TZ, BAZARR_PORT, docker-model-runner                        | Low    | None   | **Do now**                          |
| Phase 4 (backup)             | `backup-dbs.sh`, rclone offsite setup                       | Medium | None   | **Before any structural change**    |
| Phase 3, P1: Unpackerr       | Add to arr stack                                            | Low    | None   | **Do now**                          |
| Phase 3, P5: Wizarr          | Add to services stack                                       | Low    | None   | **Do now**                          |
| Phase 3, P6: Cleanuparr      | Add to arr stack                                            | Low    | None   | **Do now**                          |
| Phase 3, P7: Listenarr       | Add to arr stack (alongside abb-downloader initially)       | Low    | None   | **Do now — beta caveat applies**    |
| Phase 3, P3: Book management | Remove LazyLibrarian, add Kavita (+ BookBounty if desired)  | Medium | Low    | After deciding on book usage (Q2)   |
| Phase 3, P2: Maintainerr     | Add to media stack                                          | Low    | None   | After book stack stable             |
| Phase 6 (file structure)     | `dockerfiles/` → `stacks/`, `config-templates/` → `config/` | Medium | Low    | **Before Phase 1**                  |
| Phase 1 (consolidation)      | 11 → 6 stacks                                               | High   | Medium | After backup + Phase 6              |
| Phase 2 (networking + Caddy) | Network segmentation, add Caddy                             | High   | Medium | After Phase 1                       |
| Phase 5 (monitoring)         | Prometheus + Grafana + Scrutiny                             | Medium | None   | After Phase 1 (use new infra stack) |
| Phase 7 (access layer)       | Caddy routing config for all services                       | Medium | Low    | After Phase 2                       |
| Phase 8 (resource tuning)    | Hardware transcoding, swappiness, iGPU                      | Low    | None   | After Grafana shows data            |
| Phase 10 (Usenet)            | SABnzbd, provider setup, Usenet indexers in Prowlarr        | Medium | Low    | After arr stack stable (Phase 1)    |
| Phase 11 (Real-Debrid)       | Optional: rdt-client + Torrentio in Prowlarr                | Low    | None   | After arr stack stable; answer Q12  |

---

## Questions Before Proceeding

Before Phase 1 (consolidation) and Phase 2 (networking), these need answers:

1. **Jackett/audiobookbay-downloader:** Are you actively using audiobookbay-downloader? If yes, I'll test Prowlarr Torznab compatibility before removing Jackett. If no, remove both.

2. **Book management (LazyLibrarian replacement):** Readarr has been officially retired — it cannot be used. Is the current LazyLibrarian setup actively in use for ebook/audiobook downloads? Options: (a) Remove entirely if not used, (b) Add Kavita as a reading server only (no auto-download), (c) Add Kavita + BookBounty for automated downloading from Library Genesis. Audiobooks are handled by audiobookshelf already.

3. **Watchtower:** Adopt opt-in mode (recommended) or remove entirely and update manually?

4. **Postgres consolidation (quick win #4):** Are you comfortable running a postgres migration? If yes I'll write the exact migration steps. If no, skip it.

5. **Caddy DNS challenge:** Do you have a Cloudflare API token with `Zone:DNS:Edit` permissions available? Needed for wildcard certs and `*.home.arpa` local domains. If not, self-signed certs work fine for LAN.

6. **Local domain strategy:** Do you want `jellyfin.home.arpa` style subdomains on your LAN (requires adding Caddy as DNS resolver or editing `/etc/hosts` on each client), or do port-based URLs (`http://100.106.40.5:8096`) work fine for LAN access?

7. **autobrr:** Do you use any private trackers that require ratio maintenance? If yes, add autobrr. If all public trackers, skip.

8. **Comics:** Is there a comic book collection that needs management? If yes, Kavita handles comics natively; Kapowarr can automate downloading (943 ⭐, active). No separate comic server needed if Kavita is added.

9. **Immich ML:** Is face recognition / smart search actively used in Immich? If not, disabling `immich-machine-learning` frees ~2GB RAM.

10. **Stack migration approach:** Phase 1 as a single migration (downtime involved, one pass) or incremental stack-by-stack? Incremental is safer on a live system.

11. **Usenet:** Do you want to add Usenet alongside torrents? If yes: (a) Which provider — Eweka (EU, recommended) or another? (b) Do you want a secondary block provider (FrugalUsenet recommended)? (c) Any existing indexer accounts (NZBGeek, NZBFinder)? This will add SABnzbd to the arr stack and configure Prowlarr Usenet indexers.

12. **Real-Debrid homelab integration:** You already have Stremio + RD for casual streaming (keep as-is — correct choice). Do you also want *arr apps to use RD as a download source? If yes: (a) Minimal path — add `rdt-client` container + Torrentio indexer in Prowlarr (one extra container, no FUSE); (b) Full RD library path — Zurg + rclone FUSE mount (complex setup, public version is 10 months behind). Riven is not recommended due to slowing activity. Or: keep RD and the *arr stack independent (cleanest architecture).

13. **Listenarr evaluation timeline:** Listenarr is beta software. How long do you want to run it alongside `audiobookbay-downloader` before deciding whether to retire abb-downloader? Suggested: 4–8 weeks. Are there any specific audiobook series you want Listenarr to manage as an initial test?
