A homelab setup to repurpose my old laptop.

Uses a variety of microservices that I deem essential but will eventually add onto.

Depends on/creates another directory one step up called `homelab-data/` which holds all the permanent data being written like images, audiobooks and databases (all gitignored). Ports are set to high, non-standard values to avoid errors.

## What's running

| Service                                                                                       | Purpose                                                                  |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| [Audiobookshelf](https://www.audiobookshelf.org/)                                             | Audiobook & podcast library with streaming                               |
| [Immich](https://immich.app/)                                                                 | Self-hosted photo and video backup                                       |
| [Ryot](https://github.com/ignisda/ryot)                                                       | Media tracker (books, TV, movies, audiobooks)                            |
| [qBittorrent](https://www.qbittorrent.org/)                                                   | Torrent client                                                           |
| [Jackett](https://github.com/Jackett/Jackett)                                                 | Torrent indexer proxy (for Audiobookbay downloader)                      |
| [Audiobookbay Downloader](https://github.com/moonblade/audiobookbay-downloader)               | Search and download audiobooks via AudiobookBay                          |
| [Navidrome](https://www.navidrome.org/)                                                       | Music streaming server (Subsonic API)                                    |
| [Octo-Fiesta](https://github.com/V1ck3s/octo-fiesta)                                          | Subsonic API proxy — on-the-fly hi-res streaming from Deezer/Qobuz/Tidal |
| [Feishin](https://github.com/jeffvli/feishin)                                                 | Modern web UI for Navidrome                                              |
| [Lidarr](https://lidarr.audio/)                                                               | Automated music collection manager via torrents                          |
| [Soulseek (slskd)](https://github.com/slskd/slskd)                                            | P2P music sourcing for rare and lossless files                           |
| [Homepage](https://gethomepage.dev/)                                                          | Dashboard with live container health                                     |
| [Uptime Kuma](https://uptime.kuma.pet/)                                                       | Service uptime monitoring                                                |
| [Cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Cloudflare tunnel for external access since I can't port forward         |
| [Watchtower](https://containrrr.dev/watchtower/)                                              | Automatic nightly image updates                                          |
| [Forgejo](https://forgejo.org/)                                                               | Self-hosted git repository                                               |

## Setup

```bash
git clone https://github.com/Andreas-PM/homelab-config.git
cd homelab-config
cp .env.example .env
# Fill in .env with your credentials and tokens
```

A few services need config files seeded before first start, or they'll ignore settings like save paths and proxy headers. Templates are in `config-templates/`:

```bash
# qBittorrent
mkdir -p homelab-data/qbittorrent/config/qBittorrent
cp config-templates/qbittorrent/qBittorrent.conf homelab-data/qbittorrent/config/qBittorrent/qBittorrent.conf
cp config-templates/qbittorrent/categories.json  homelab-data/qbittorrent/config/qBittorrent/categories.json
# Set WebUI\Username in the .conf. Password hash is written automatically on first login.

# Jackett
mkdir -p homelab-data/jackett/config/Jackett
cp config-templates/jackett/ServerConfig.json homelab-data/jackett/config/Jackett/ServerConfig.json
# Set APIKey in ServerConfig.json to match JACKETT_API_KEY in your .env.

# slskd (Soulseek)
mkdir -p homelab-data/slskd
cp config-templates/slskd/slskd.yml homelab-data/slskd/slskd.yml
# Credentials are set via SLSKD_USERNAME / SLSKD_PASSWORD in .env — no edits needed in the yml.
```

Then bring everything up:

```bash
./scripts/up-all.sh
```

To set up Uptime Kuma monitors automatically, run `./scripts/setup-uptime-kuma.sh` after the stack is healthy. Update `UK_PASS` in the script to your real password first.

## Cloudflare tunnel

Services exposed via Cloudflare tunnel (configured in Zero Trust → Networks → Tunnels → Public Hostnames):

| Subdomain                         | Internal service            | Auth                                 |
| --------------------------------- | --------------------------- | ------------------------------------ |
| `audiobookshelf.andreasmaita.com` | `http://audiobookshelf:80`  | Audiobookshelf own login             |
| `navidrome.andreasmaita.com`      | `http://navidrome:4533`     | Navidrome own login                  |
| `octo-fiesta.andreasmaita.com`    | `http://octo-fiesta:8080`   | Navidrome own login (Subsonic proxy) |
| `feishin.andreasmaita.com`        | `http://feishin:9180`       | Navidrome own login (via Feishin)    |
| `immich.andreasmaita.com`         | `http://immich-server:2283` | Immich own login                     |
| `forgejo.andreasmaita.com`        | `http://forgejo:3000`       | Forgejo own login                    |
| `homepage.andreasmaita.com`       | `http://homepage:3000`      | None (internal dashboard)            |

**Feishin `SERVER_URL`:** Set `NAVIDROME_EXTERNAL_URL` in `.env` to the public Navidrome tunnel URL. Feishin's browser client connects to Navidrome from the user's device, not from Docker, so it must be a publicly reachable URL.

**Cloudflare Access bypass for Navidrome API paths (required for mobile Subsonic clients):**

Mobile music apps (Symfonium, Ultrasonic, etc.) can't complete a browser-based Access challenge. Bypass Access for the API paths only so clients can authenticate directly with Navidrome:

1. Zero Trust → Access → Applications → Add application → Self-hosted
2. Set application domain: `navidrome.andreasmaita.com`
3. Under **Policies**, add a rule:
   - Action: **Bypass**
   - Include rule: **Everyone**
   - Path: `/rest/*`
4. Add a second Bypass rule for path `/api/*` (used by Feishin native mode)
5. Add a third Bypass rule for path `/ping` (healthcheck)
6. Add your normal Allow policy (email OTP etc.) — this catches everything else like the web UI

With this setup: web UI at `/app` requires Access auth, but `/rest/*` and `/api/*` are open to Navidrome's own auth (username/password/token).

## Music stack first-run

After `up-all.sh`, a few music services need one-time setup via their web UIs:

| Service         | URL      | What to do                                                                                                                                                                                                                  |
| --------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Navidrome**   | `:20070` | Create your admin account on first visit                                                                                                                                                                                    |
| **Octo-Fiesta** | `:20076` | Point your Subsonic clients here instead of Navidrome to enable transparent hi-res downloads. Configure the music provider via `OCTOFIESTA_MUSIC_SERVICE` in `.env` (default: SquidWTF — no credentials needed)             |
| **Lidarr**      | `:20073` | Complete the setup wizard. Add Jackett as indexer (`http://jackett:9117`, API key from `.env`). Add qBittorrent as download client (`http://qbittorrent:20050`, credentials from `.env`). Set music root folder to `/music` |
| **slskd**       | `:20075` | Log in with the credentials from `SLSKD_USERNAME` / `SLSKD_PASSWORD` in `.env`. Search and download music directly to the shared music library                                                                              |

**Feishin** (`:20072`) is pre-locked to Navidrome — just log in with your Navidrome credentials.

**Octo-Fiesta** acts as a transparent Subsonic proxy: point your mobile music clients (Symfonium, Ultrasonic, etc.) at `octo-fiesta:20076` instead of Navidrome. When you play a track, octo-fiesta fetches the hi-res version from your configured provider and streams it. The downloaded file is saved to the shared music library so Navidrome picks it up on next scan.

## Notes

- Ports are all configurable via `.env` — see `.env.example` for the full list
- Immich uses its default port (`2283`) for app compatibility
- First-time setup per service is covered in the **Music stack first-run** table and the individual service docs linked above.
