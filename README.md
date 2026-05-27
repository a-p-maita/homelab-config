# Homelab - a setup to repurpose my old laptop

## Service Stacks

- **Generally each service will be listed by level of importance and recommendation**

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
- [Dockge](https://dockge.kuma.pet/) - Web-UI docker compose file manager
  - [DOCUMENTATION](https://github.com/louislam/dockge#readme)
- [Uptime Kuma](https://uptime.kuma.pet/) - Service uptime monitoring, and all that
  - [DOCUMENTATION](https://github.com/louislam/uptime-kuma/wiki)
- [Watchtower](https://containrrr.dev/watchtower/) - Automatic nightly docker image updates
- [Dozzle](https://github.com/amir20/dozzle) - Real-time log viewer
  - [DOCUMENTATION](https://github.com/amir20/dozzle#README)

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

### Cloud

- **Purpose: Cloud-based services and automation**
- [Vaultwarden](https://github.com/dani-garcia/vaultwarden) - Password manager
  - [DOCUMENTATION](https://github.com/dani-garcia/vaultwarden/wiki)
  - Server-side software for Bitwarden, can connect to extension and mobile app but the data is separate fromt the official one so keep that in mind
- [Immich](https://immich.app/)- Photos and images, replacement for google photos
  - [DOCUMENTATION](https://docs.immich.app/)
  - Limitation is through cloudflare domain there's upload size limits so it struggles with videos etc.
    - Chunking would help this but it was said to be out-of-scope for Immich
- [Forgejo](https://forgejo.org/) - Git repository and GitHub replacement
  - [DOCUMENTATION](https://forgejo.org/docs/)
- [Paperless-NGX](https://docs.paperless-ngx.com/) - Document management & OCR
  - [DOCUMENTATION](https://docs.paperless-ngx.com/)
- [NextCloud](https://nextcloud.com/) - File sync/sharing, document office, calendar, contacts etc.
  - [DOCUMENTATION](https://docs.nextcloud.com/)
- [Home Assistant](https://www.home-assistant.io/) - Home automation platform
  - [DOCUMENTATION](https://www.home-assistant.io/docs/)

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
- [Actual Budget](https://actualbudget.org/) - Local-first personal finance manager
  - [DOCUMENTATION](https://docs.actualbudget.org/)
- [Habitica](https://github.com/HabitRPG/habitica) - Game-mode task/habit tracker
  - [DOCUMENTATION](https://github.com/HabitRPG/habitica/wiki)
  - Not self-hosted but has a public API and is a neat way to manage tasks and all that
- [Monica](https://github.com/monicahq/monica) - Personal relationship manager aka CRM
  - [DOCUMENTATION](https://www.monicahq.com/docs/)
  - Used to keep track of family/friend/acquaintance details - useful anti-altzheimers tool lol

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
- [Jackett](https://github.com/Jackett/Jackett)
  - Torrent indexer proxy (More indexers than Prowlarr, less integrated tho)
  - Auto-restarts qBittorrent when VPN stalls
- [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) - Cloudflare anti-bot solver for indexers
  - [DOCUMENTATION](https://github.com/FlareSolverr/FlareSolverr/wiki)
- [Sonarr](https://sonarr.tv/)
  - [DOCUMENTATION](https://wiki.servarr.com/sonarr)
  - Automated TV series collection manager
- [Radarr](https://radarr.video/)
  - [DOCUMENTATION](https://wiki.servarr.com/radarr)
  - Automated movie collection manager
- [Lidarr](https://lidarr.audio/)
  - [DOCUMENTATION](https://wiki.servarr.com/lidarr)
  - Automated music collection manager
- [Bazarr](https://www.bazarr.media/)
  - [DOCUMENTATION](https://wiki.servarr.com/bazarr)
  - Subtitle manager for Sonarr/Radarr
- [Profilarr](https://github.com/Dictionarry-Hub/Profilarr/) - Media quality/format manager for Radarr/Sonarr
  - [DOCUMENTATION](https://github.com/Dictionarry-Hub/Profilarr/wiki)
  - Can be set up to use tip top best [TRaSH Guides](https://trash-guides.info/) see [this repo](https://github.com/johman10/profilarr-trash-guides)
  - Still waiting on Lidarr integration
- [Decluttarr](https://github.com/ManiMatter/decluttarr) - Autoclears download queues and downloads from \*arr stack
  - [DOCUMENTATION](https://github.com/ManiMatter/decluttarr#readme)

### Apps

- **Purpose: General apps that don't fit in another category**
- [Kiwix](https://www.kiwix.org/) - Offline Wikipedia & ZIM content reader
  - [DOCUMENTATION](https://wiki.kiwix.org/wiki/Documentation)
- [Jitsi Meet](https://jitsi.org/jitsi-meet/) - Video conferencing
  - [DOCUMENTATION](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker)
- [Rustdesk](https://rustdesk.com/) - Remote desktop server
  - [DOCUMENTATION](https://rustdesk.com/docs/)
- [Draw.io](https://github.com/jgraph/drawio) - Diagram editor
- [Excalidraw](https://excalidraw.com/) - Collaborative whiteboard
- [IT-Tools](https://github.com/CorentinTh/it-tools) - Developer utilities collection

## Setup and Getting it Running

**File structure:**

```markdown
.
|-- .gitignore
|-- README.md
|-- backups/
|-- secrets-example/
|-- data/
    |-- app_data/
        |-- app1/
        |-- .../
    |-- media/
        |-- audiobooks/
        |-- books/
        |-- documents/
        |-- games/
        |-- movies/
        |-- music/
        |-- other/
        |-- photos/
        |-- tv/
        |-- videos/
    |-- personal/
        |-- area/
        |-- archive/
        |-- documents/
        |-- downloads/
        |-- other/
        |-- photos/
        |-- projects/
        |-- resource/
        |-- videos/
    |-- torrents/
        |-- incomplete/
        |-- complete/
            |-- audiobooks/
            |-- .../
            |-- videos/
    |-- usenet/
         |-- incomplete/
         |-- complete/
             |-- audiobooks/
             |-- .../
             |-- videos/
|-- stacks/
    |-- apps/
        |-- .gitignore
        |-- compose.yaml
        |-- secrets-example/
    |-- example_category/
        |-- .gitignore
        |-- compose.yaml
        |-- secrets-example/
```

<!-- Layout:

- Repo holds many docker compose files under `stacks/category_example/compose.yaml`
- Persistent/long-term app data is stored in `data/`
- Global runtime secrets are held in the `secrets/`
  - Each category has own secrets file under `stacks/category/compose.yaml`
  - These use the global secrets but can also define category-specific ones -->

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
