A homelab setup to repurpose my old laptop.

Layout:

- Repo holds many docker compose files under `stacks/service_category_etc`
- Persistent/long-term app data is stored in `data/`
- runtime secrets are held in the `secrets`

## Homelab Service Stack

### Infrastructure

- **Purpose: What's essential to run the homelab and expose services**
- [Traefik](https://traefik.io/) - Reverse proxy to link services to subdomains and handle TLS, also obscures service ports and does nice obscurity in a nutshell
  - [DOCUMENTATION](https://doc.traefik.io/traefik/)
  - Might be a bit heavy but it's nice and supported and declarative
- [Authentik](https://goauthentik.io/)- Lets me guard exposed services/subdomains for peace of mind and all that
  - [DOCUMENTATION](https://goauthentik.io/docs/)
  - Identity provider for single sign-on to all services
  - Would like to add 2FA eventually but it's a bit of a pain to set up and maintain so maybe later
- [Cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) - Cloudflare daemon tunnel for external access
  - [DOCUMENTATION](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/install-and-setup/tunnel-guide/)
  - Good way to get around port forwarding, again
  - Requires setting up tunnels for each subdomain/service through the [Cloudflare dashboard](https://dash.cloudflare.com/) but it's easy enough

### Maintenance

- **Purpose: Maintenance and monitoring tools for the homelab**
- [Homepage](https://gethomepage.dev/) - Dashboard for quick links to internal/external services
  - [DOCUMENTATION](https://gethomepage.dev/configs/)
  - Would like one that automatically attaches to services this would be nice
- [Uptime Kuma](https://uptime.kuma.pet/) - Service uptime monitoring
- [Watchtower](https://containrrr.dev/watchtower/) - Automatic nightly docker image updates

### Media

- **Purpose: Media streaming and downloading**
- [Audiobookshelf](https://www.audiobookshelf.org/) - Audiobook server, godly piece of tech highly recommend genuinely can't live without it
  - [DOCUMENTATION](https://www.audiobookshelf.org/docs/)
  - Has mobile client in beta too, a bit limited but mostly perfect honestly for what it needs
- [Jellyfin](https://jellyfin.org/) - Media streaming/downloading server
  - [DOCUMENTATION](https://jellyfin.org/docs/)
  - Supports movies, tv shows, music, audiobooks, podcasts and allthat but I'd rather use purpose-built stuff who knos though it's a good fallback
- [Navidrome](https://www.navidrome.org/) - Music streaming server
  - [DOCUMENTATION](https://www.navidrome.org/docs/)
  - Uses a Subsonic API so it's compatible with many-a-thing

### *Arr

- **Purpose: Automated media downloading and management**
- [qBittorrent](https://www.qbittorrent.org/)
  - [DOCUMENTATION](https://www.qbittorrent.org/docs/)
  - Torrent client
  - Goes hand-in-hand with [Gluetun](https://github.com/qdm12/gluetun) _(optional)_
    - My VPN client is ProtonVPN WireGuard - enabled by setting `secrets/vpn_enabled.secret` to `true`
- [Prowlarr](https://prowlarr.com/)
  - [DOCUMENTATION](https://wiki.servarr.com/prowlarr)
  - Indexer manager — syncs trackers to all \*arr apps
- [Radarr](https://radarr.video/)
  - [DOCUMENTATION](https://wiki.servarr.com/radarr)
  - Automated movie collection manager
- [Sonarr](https://sonarr.tv/)
  - [DOCUMENTATION](https://wiki.servarr.com/sonarr)
  - Automated TV series collection manager
- [Lidarr](https://lidarr.audio/)
  - [DOCUMENTATION](https://wiki.servarr.com/lidarr)
  - Automated music collection manager
- [Jackett](https://github.com/Jackett/Jackett)
  - Torrent indexer proxy (More indexers than Prowlarr, less integrated tho)
  - Auto-restarts qBittorrent when VPN stalls
- [Bazarr](https://www.bazarr.media/)
  - [DOCUMENTATION](https://wiki.servarr.com/bazarr)
  - Subtitle manager for Sonarr/Radarr
- [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) - Cloudflare anti-bot solver for indexers
  - [DOCUMENTATION](https://github.com/FlareSolverr/FlareSolverr/wiki)

### Trackers

- **Purpose: Trackers for anything and everything to log in life**
- [Yamtrack](https://github.com/FuzzyGrim/Yamtrack) - Everything media tracker very good
  - [DOCUMENTATION](https://github.com/FuzzyGrim/Yamtrack/wiki)
  - Has scheduled sync with Trakt, AniList so it's hella convenient
  - Has calendar to sync upcoming stuff which is neat
  - Tracks tv shows, anime, movies, games, manga, books
    - I'm holding out for the day audiobooks and ABS are suported
- [Mealie](https://mealie.io/) - Recipe manager & meal planner
  - [DOCUMENTATION](https://docs.mealie.io/)

### Apps

- **Purpose: General apps that don't fit in another category**
- [Paperless-NGX](https://docs.paperless-ngx.com/) - Document management & OCR
  - [DOCUMENTATION](https://docs.paperless-ngx.com/)
- [Kiwix](https://www.kiwix.org/) - Offline Wikipedia & ZIM content
- [Draw.io](https://github.com/jgraph/drawio) - Diagram editor
- [Excalidraw](https://excalidraw.com/) - Collaborative whiteboard
- [IT-Tools](https://github.com/CorentinTh/it-tools) - Developer utilities collection
- [Vaultwarden](https://github.com/dani-garcia/vaultwarden) - Password manager (Bitwarden-compatible)
- [Actual Budget](https://actualbudget.org/) - Local-first personal finance manager

### Cloud

- **Purpose: Cloud-based services and automation**
- [Immich](https://immich.app/)- Photos and images, replacement for google photos
  - [DOCUMENTATION](https://docs.immich.app/)
  - Limitation is through cloudflare domain there's upload size limits so it struggles with videos etc.
    - Chunking would help this but it was said to be out-of-scope for Immich
- [Forgejo](https://forgejo.org/) - Git repository and GitHub replacement
  - [DOCUMENTATION](https://forgejo.org/docs/)
- [Home Assistant](https://www.home-assistant.io/) - Home automation platform
  - [DOCUMENTATION](https://www.home-assistant.io/docs/)
- [NextCloud](https://nextcloud.com/) - File sync/sharing, document office, calendar, contacts etc.
  - [DOCUMENTATION](https://docs.nextcloud.com/)
- [Jitsi Meet](https://jitsi.org/jitsi-meet/) - Video conferencing
  - [DOCUMENTATION](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker)
- [Rustdesk](https://rustdesk.com/) - Remote desktop server
  - [DOCUMENTATION](https://rustdesk.com/docs/)

## Hardware

Running on an old laptop repurposed as a server:

- **CPU:** AMD Ryzen 5 5500U - 6 cores, 12 threads, 4.0 GHz
- **RAM:** 14 GB DDR4 + 14 GB ZRAM swap
  - 16 GB physically/technically
- **Storage:** NVMe SSD 930 GB
- **OS:** Linux
  - Trying to make it work for both Arch and Debian
  - May switch to Proxmox eventually when the homelab is stable

<!-- ### Resource allocation

Every container has `deploy.resources.limits` set. The budget leaves ~2 cores and ~2 GB RAM free for the OS. Key allocations:

| Tier     | Services                                                          | CPU limit  | RAM limit     |
| -------- | ----------------------------------------------------------------- | ---------- | ------------- |
| Heavy    | Immich server/ML, Jellyfin, Paperless-NGX                         | 2.0        | 2 GB          |
| Medium   | Audiobookshelf, qBittorrent, Lidarr, Stirling PDF, Home Assistant | 1.0        | 512 M – 1 G   |
| Light    | Most other services                                               | 0.25 – 0.5 | 128 M – 512 M |
| DB/cache | postgres, redis, mysql                                            | 0.25 – 0.5 | 256 M – 1 G   | -->
