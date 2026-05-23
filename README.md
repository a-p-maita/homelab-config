A homelab setup to repurpose my old laptop.

Uses a variety of microservices that I deem essential but will eventually add onto.

Depends on/creates another directory one step up called `data/` which holds all the permanent data being written like images, audiobooks and databases (all gitignored). Ports are set to high, non-standard values to avoid errors.

## What's running

### Arr (torrent automation)

| Service                                                                         | Purpose                                                                 |
| ------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| [qBittorrent](https://www.qbittorrent.org/)                                     | Torrent client                                                          |
| [Prowlarr](https://prowlarr.com/)                                               | Indexer manager — syncs trackers to all \*arr apps                      |
| [Radarr](https://radarr.video/)                                                 | Automated movie collection manager                                      |
| [Sonarr](https://sonarr.tv/)                                                    | Automated TV series collection manager                                  |
| [Readarr](https://readarr.com/)                                                 | Automated book/ebook collection manager                                 |
| [Lidarr](https://lidarr.audio/)                                                 | Automated music collection manager                                      |
| [Jackett](https://github.com/Jackett/Jackett)                                   | Torrent indexer proxy (legacy — use Prowlarr for new indexers)          |
| [Audiobookbay Downloader](https://github.com/moonblade/audiobookbay-downloader) | Search and download audiobooks via AudiobookBay                         |
| [Gluetun](https://github.com/qdm12/gluetun) _(optional)_                        | VPN client (ProtonVPN WireGuard) — enable with `USE_VPN=true` in `.env` |
| [deunhealth](https://github.com/qdm12/deunhealth) _(optional)_                  | Auto-restarts qBittorrent when VPN stalls                               |

### Media

| Service                                               | Purpose                                                                  |
| ----------------------------------------------------- | ------------------------------------------------------------------------ |
| [Audiobookshelf](https://www.audiobookshelf.org/)     | Audiobook & podcast library with streaming                               |
| [Yamtrack](https://github.com/FuzzyGrim/Yamtrack)     | Media tracker (TV, movies, games, manga, books)                          |
| [CrossWatch](https://github.com/FuzzyGrim/crosswatch) | Sync watch history across Trakt, AniList, Jellyfin, Simkl                |
| [Navidrome](https://www.navidrome.org/)               | Music streaming server (Subsonic API)                                    |
| [Octo-Fiesta](https://github.com/V1ck3s/octo-fiesta)  | Subsonic API proxy — on-the-fly hi-res streaming from Deezer/Qobuz/Tidal |
| [Feishin](https://github.com/jeffvli/feishin)         | Modern web UI for Navidrome                                              |

### Entertainment

| Service                           | Purpose                  |
| --------------------------------- | ------------------------ |
| [Jellyfin](https://jellyfin.org/) | Media server (video, TV) |

### Documents

| Service                                          | Purpose                         |
| ------------------------------------------------ | ------------------------------- |
| [Paperless-NGX](https://docs.paperless-ngx.com/) | Document management & OCR       |
| [Stirling PDF](https://stirlingpdf.io/)          | PDF manipulation tools          |
| [Kiwix](https://www.kiwix.org/)                  | Offline Wikipedia & ZIM content |

### Tools

| Service                                                   | Purpose                                 |
| --------------------------------------------------------- | --------------------------------------- |
| [Draw.io](https://github.com/jgraph/drawio)               | Diagram editor                          |
| [Excalidraw](https://excalidraw.com/)                     | Collaborative whiteboard                |
| [IT-Tools](https://github.com/CorentinTh/it-tools)        | Developer utilities collection          |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | Password manager (Bitwarden-compatible) |
| [Actual Budget](https://actualbudget.org/)                | Local-first personal finance            |
| [Joplin Server](https://joplinapp.org/)                   | Note-taking sync server                 |

### Personal

| Service                      | Purpose                       |
| ---------------------------- | ----------------------------- |
| [Mealie](https://mealie.io/) | Recipe manager & meal planner |

### Home

| Service                                          | Purpose         |
| ------------------------------------------------ | --------------- |
| [Home Assistant](https://www.home-assistant.io/) | Home automation |

### Infrastructure

| Service                                                                                       | Purpose                                                    |
| --------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| [Immich](https://immich.app/)                                                                 | Self-hosted photo and video backup                         |
| [Forgejo](https://forgejo.org/)                                                               | Self-hosted git repository                                 |
| [Homepage](https://gethomepage.dev/)                                                          | Dashboard with live container health                       |
| [Uptime Kuma](https://uptime.kuma.pet/)                                                       | Service uptime monitoring                                  |
| [Cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Cloudflare tunnel for external access (no port forwarding) |
| [Watchtower](https://containrrr.dev/watchtower/)                                              | Automatic nightly image updates                            |

## Hardware

Running on an old laptop repurposed as a headless server.

| Component | Spec                                                   |
| --------- | ------------------------------------------------------ |
| CPU       | AMD Ryzen 5 5500U — 6 cores, 12 threads, up to 4.0 GHz |
| RAM       | 14 GB DDR4 + 14 GB zram swap                           |
| Storage   | NVMe SSD ~930 GB (main) + 120 GB SSD (secondary)       |
| OS        | Linux                                                  |

### Resource allocation

Every container has `deploy.resources.limits` set. The budget leaves ~2 cores and ~2 GB RAM free for the OS. Key allocations:

| Tier     | Services                                                          | CPU limit  | RAM limit     |
| -------- | ----------------------------------------------------------------- | ---------- | ------------- |
| Heavy    | Immich server/ML, Jellyfin, Paperless-NGX                         | 2.0        | 2 GB          |
| Medium   | Audiobookshelf, qBittorrent, Lidarr, Stirling PDF, Home Assistant | 1.0        | 512 M – 1 G   |
| Light    | Most other services                                               | 0.25 – 0.5 | 128 M – 512 M |
| DB/cache | postgres, redis, mysql                                            | 0.25 – 0.5 | 256 M – 1 G   |

Limits are soft ceilings — containers can burst when idle headroom is available. Reservations are set low so Docker does not pre-allocate memory.

## Setup

```bash
git clone https://github.com/Andreas-PM/homelab-config.git
cd homelab-config
cp .env.example .env
# Fill in .env with your credentials and tokens
```

A few services need config files seeded before first start, or they'll ignore settings like save paths and proxy headers. Templates are in `config-templates/`. Most are **auto-seeded by `up-all.sh`** — the ones below need manual placement:

```bash
# qBittorrent
mkdir -p data/qbittorrent/config/qBittorrent
cp config-templates/qbittorrent/qBittorrent.conf data/qbittorrent/config/qBittorrent/qBittorrent.conf
cp config-templates/qbittorrent/categories.json  data/qbittorrent/config/qBittorrent/categories.json
# Set WebUI\Username in the .conf. Password hash is written automatically on first login.

# Jackett
mkdir -p data/jackett/config/Jackett
cp config-templates/jackett/ServerConfig.json data/jackett/config/Jackett/ServerConfig.json
# Set APIKey in ServerConfig.json to match JACKETT_API_KEY in your .env.

```

The following templates are seeded automatically by `up-all.sh` on first run (only if the file doesn't already exist):

- `config-templates/homepage/` → `data/homepage/config/` (services, settings, docker, widgets, bookmarks)
- `config-templates/stirling-pdf/settings.yml` → `data/stirling-pdf/configs/settings.yml`
- `config-templates/crosswatch/config.json` → `data/crosswatch/config.json`

Then bring everything up:

```bash
./scripts/up-all.sh
```

> **First run:** Several services require manual steps after startup (setting credentials, completing wizards, etc.). See **[FIRST-RUN.md](FIRST-RUN.md)** for the complete guide.

## Cloudflare tunnel

Services exposed via Cloudflare tunnel (configured in Zero Trust → Networks → Tunnels → Public Hostnames):

| Subdomain                         | Internal service            | Auth                                 |
| --------------------------------- | --------------------------- | ------------------------------------ |
| `abs.andreasmaita.com` | `http://audiobookshelf:80`  | Audiobookshelf own login             |
| `music.andreasmaita.com`      | `http://navidrome:4533`     | Navidrome own login                  |
| `octo-fiesta.andreasmaita.com`    | `http://octo-fiesta:8080`   | Navidrome own login (Subsonic proxy) |
| `feishin.andreasmaita.com`        | `http://feishin:9180`       | Navidrome own login (via Feishin)    |
| `immich.andreasmaita.com`         | `http://immich-server:2283` | Immich own login                     |
| `git.andreasmaita.com`        | `http://forgejo:3000`       | Forgejo own login                    |
| `homepage.andreasmaita.com`       | `http://homepage:3000`      | None (internal dashboard)            |

**Feishin `SERVER_URL`:** Set `NAVIDROME_EXTERNAL_URL` in `.env` to the public Navidrome tunnel URL. Feishin's browser client connects to Navidrome from the user's device, not from Docker, so it must be a publicly reachable URL.

**Cloudflare Access bypass for Navidrome API paths (required for mobile Subsonic clients):**

Mobile music apps (Symfonium, Ultrasonic, etc.) can't complete a browser-based Access challenge. Bypass Access for the API paths only so clients can authenticate directly with Navidrome:

1. Zero Trust → Access → Applications → Add application → Self-hosted
2. Set application domain: `music.andreasmaita.com`
3. Under **Policies**, add a rule:
   - Action: **Bypass**
   - Include rule: **Everyone**
   - Path: `/rest/*`
4. Add a second Bypass rule for path `/api/*` (used by Feishin native mode)
5. Add a third Bypass rule for path `/ping` (healthcheck)
6. Add your normal Allow policy (email OTP etc.) — this catches everything else like the web UI

With this setup: web UI at `/app` requires Access auth, but `/rest/*` and `/api/*` are open to Navidrome's own auth (username/password/token).

## Music stack first-run

After `up-all.sh`, the music services need one-time setup:

| Service         | URL      | What to do                                                                                                                                                                                                                                      |
| --------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Navidrome**   | `:20070` | Create your admin account on first visit                                                                                                                                                                                                        |
| **Octo-Fiesta** | `:20076` | Point your Subsonic clients here instead of Navidrome to enable transparent hi-res downloads. Configure the music provider via `OCTOFIESTA_MUSIC_SERVICE` in `.env` (default: SquidWTF — no credentials needed)                                 |
| **Lidarr**      | `:20059` | Complete the setup wizard. Add Prowlarr as indexer sync source (see FIRST-RUN.md §10). Add qBittorrent as download client (`http://qbittorrent:20050`, credentials from `.env`, category `music`). Set music root folder to `/data/media/music` |

**Feishin** (`:20072`) is pre-locked to Navidrome — just log in with your Navidrome credentials.

**Octo-Fiesta** acts as a transparent Subsonic proxy: point your mobile music clients (Symfonium, Ultrasonic, etc.) at `octo-fiesta:20076` instead of Navidrome. When you play a track, octo-fiesta fetches the hi-res version from your configured provider and streams it. The downloaded file is saved to the shared music library so Navidrome picks it up on next scan.

## Notes

- All ports are configurable via `.env` — see `.env.example` for the full list
- Ports are intentionally in the `20000–20340` range to avoid conflicts with well-known services
- Immich uses its default port (`2283`) for app compatibility
- First-time setup for all services is documented in **[FIRST-RUN.md](FIRST-RUN.md)**
