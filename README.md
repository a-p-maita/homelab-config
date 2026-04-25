A homelab setup to repurpose my old laptop.

Uses a variety of microservices that I deem essential but will eventually add onto.

Depends on/creates another directory one step up called `homelab-data/` which holds all the permanent data being written like images, audiobooks and databases (all gitignored). Ports are set to high, non-standard values to avoid errors.

## What's running

| Service | Purpose |
|---|---|
| [Audiobookshelf](https://www.audiobookshelf.org/) | Audiobook & podcast library with streaming |
| [Immich](https://immich.app/) | Self-hosted photo and video backup |
| [Ryot](https://github.com/ignisda/ryot) | Media tracker (books, TV, movies, audiobooks) |
| [qBittorrent](https://www.qbittorrent.org/) | Torrent client |
| [Jackett](https://github.com/Jackett/Jackett) | Torrent indexer proxy (for Audiobookbay downloader) |
| [Audiobookbay Downloader](https://github.com/moonblade/audiobookbay-downloader) | Search and download audiobooks via AudiobookBay |
| [Navidrome](https://www.navidrome.org/) | Music streaming server (Subsonic API) |
| [Feishin](https://github.com/jeffvli/feishin) | Modern web UI for Navidrome |
| [Deemix](https://github.com/bambanah/deemix) | Download music from Deezer (FLAC with HiFi subscription) |
| [Lidarr](https://lidarr.audio/) | Automated music collection manager via torrents |
| [Soulseek (slskd)](https://github.com/slskd/slskd) | P2P music sourcing for rare and lossless files |
| [Homepage](https://gethomepage.dev/) | Dashboard with live container health |
| [Uptime Kuma](https://uptime.kuma.pet/) | Service uptime monitoring |
| [Cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Cloudflare tunnel for external access since I can't port forward |
| [Watchtower](https://containrrr.dev/watchtower/) | Automatic nightly image updates |
| [Forgejo](https://forgejo.org/) | Self-hosted git repository |

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
# Fill in your Soulseek network credentials and desired slskd web UI password.
```

Then bring everything up:

```bash
./scripts/up-all.sh
```

To set up Uptime Kuma monitors automatically, run `./scripts/setup-uptime-kuma.sh` after the stack is healthy. Update `UK_PASS` in the script to your real password first.

## Music stack first-run

After `up-all.sh`, a few music services need one-time setup via their web UIs:

| Service | URL | What to do |
|---|---|---|
| **Navidrome** | `:20070` | Create your admin account on first visit |
| **Deemix** | `:20071` | Go to Settings → paste your Deezer `arl` cookie value. Get it from deezer.com → F12 → Application → Cookies → `arl`. Free account = 128kbps MP3; paid HiFi = FLAC |
| **Lidarr** | `:20073` | Complete the setup wizard. Add Jackett as indexer (`http://jackett:9117`, API key from `.env`). Add qBittorrent as download client (`http://qbittorrent:20050`, credentials from `.env`). Set music root folder to `/music` |
| **slskd** | `:20075` | Log in with the credentials from `homelab-data/slskd/slskd.yml`. Search and download music directly to the shared music library |

**Feishin** (`:20072`) is pre-locked to Navidrome — just log in with your Navidrome credentials.

To bootstrap your Spotify playlists (256kbps MP3, no FLAC), run spotDL ad-hoc:

```bash
docker run --rm \
  -v /home/a-p-maita/homelab-config/homelab-data/music:/music \
  spotdl/spotdl:latest \
  sync "https://open.spotify.com/playlist/YOUR_PLAYLIST_ID" \
  --output "/music/{artists}/{album}/{title}.{output-ext}" \
  --save-file /music/.spotdl-sync.spotdl
```

Replace `sync` with `download` for a one-shot import, or keep `sync` to re-run and skip already-downloaded tracks.


## Notes

- Ports are all configurable via `.env` — see `.env.example` for the full list
- Immich uses its default port (`2283`) for app compatibility
- Some of the services need first time logins to be configured on the webui and such so do that after the first run.