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
| [Homepage](https://gethomepage.dev/) | Dashboard with live container health |
| [Uptime Kuma](https://uptime.kuma.pet/) | Service uptime monitoring |
| [Cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Cloudflare tunnel for external access since I can't port forward |
| [Watchtower](https://containrrr.dev/watchtower/) | Automatic nightly image updates |
| [Forgejo](https://forgejo.org/) | Self-hosted git (work in progress) |

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
```

Then bring everything up:

```bash
./scripts/up-all.sh
```

To set up Uptime Kuma monitors automatically, run `./scripts/setup-uptime-kuma.sh` after the stack is healthy. Update `UK_PASS` in the script to your real password first.


## Notes

- Ports are all configurable via `.env` — see `.env.example` for the full list
- Immich uses its default port (`2283`) for app compatibility
- Some of the services need first time logins to be configured on the webui and such so do that after the first run.