# Homelab - a setup to repurpose my old laptop

## Service Stacks - Generally each service will be listed by level of importance and recommendation

### Infrastructure - What's essential to run the homelab and expose services

|Service|Purpose|Docs|Notes|Image|
|---|---|---|---|---|
|[Traefik](https://github.com/traefik/traefik)|Reverse proxy to link services to subdomains and handle TLS|[Documentation](https://doc.traefik.io/traefik/)|Can be a bit heavy but is supported and declarative|[traefik:latest](https://hub.docker.com/_/traefik)|
|[Authentik](https://github.com/goauthentik/authentik)|Guard exposed services/subdomains and provide SSO|[Documentation](https://docs.goauthentik.io/)|2FA manager for subdomains/exposed services links up to Traefik|[authentik/server:2026.5](https://hub.docker.com/r/authentik/server)|
|[Cloudflared](https://github.com/cloudflare/cloudflared)|Cloudflare tunnel for external access|[Documentation](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)|Helps avoid port forwarding<br>Requires separate tunnels per service|[cloudflare/cloudflared:latest](https://hub.docker.com/r/cloudflare/cloudflared)|

### Maintenance - Maintenance and monitoring tools for the homelab

|Service|Purpose|Docs|Notes|Image|
|---|---|---|---|---|
|[Homepage](https://github.com/gethomepage/homepage)|Dashboard for quick links to internal/external services|[Documentation](https://gethomepage.dev/)|Would like one that automatically attaches to services|[gethomepage/homepage:latest](https://ghcr.io/gethomepage/homepage:latest)|
|[Dockge](https://github.com/louislam/dockge)|Web UI Docker Compose file manager|[Documentation](https://github.com/louislam/dockge#readme)||[louislam/dockge:latest](https://hub.docker.com/r/louislam/dockge)|
|[Uptime Kuma](https://github.com/louislam/uptime-kuma)|Service uptime monitoring|[Documentation](https://github.com/louislam/uptime-kuma/wiki)||[louislam/uptime-kuma:latest](https://hub.docker.com/r/louislam/uptime-kuma)|
|[Watchtower](https://github.com/nicholas-fedor/watchtower)|Automatic nightly Docker image updates|[Documentation](https://hub.docker.com/r/containrrr/watchtower#readme)||[containrrr/watchtower:latest](https://ghcr.io/containrrr/watchtower:latest)|
|[Dozzle](https://github.com/amir20/dozzle)|Real-time log viewer|[Documentation](https://github.com/amir20/dozzle#README)||[amir20/dozzle:latest](https://ghcr.io/amir20/dozzle:latest)|

### Media - Media streaming and downloading

|Service|Purpose|Docs|Notes|Image|
|---|---|---|---|---|
|[Audiobookshelf](https://github.com/advplyr/Audiobookshelf)|Audiobook server|[Documentation](https://www.audiobookshelf.org/docs/)|Mobile client in beta; limited but mostly solid|[advplyr/audiobookshelf:latest](https://ghcr.io/advplyr/audiobookshelf:latest)|
|[Jellyfin](https://github.com/jellyfin/jellyfin)|Media streaming/downloading server|[Documentation](https://jellyfin.org/docs/)|Supports movies, TV, music, audiobooks, podcasts|[jellyfin/jellyfin:latest](https://ghcr.io/jellyfin/jellyfin:latest)|
|[Navidrome](https://github.com/navidrome/navidrome)|Music streaming server|[Documentation](https://www.navidrome.org/docs/)|Uses Subsonic API for broad compatibility|[deluan/navidrome:latest](https://hub.docker.com/r/deluan/navidrome)|

### Cloud - Cloud-based services and automation

|Service|Purpose|Docs|Notes|Image|
|---|---|---|---|---|
|[Vaultwarden](https://github.com/dani-garcia/vaultwarden)|Password manager|[Documentation](https://github.com/dani-garcia/vaultwarden/wiki)|Server-side Bitwarden replacement<br>Separate data from official service|[vaultwarden/server:latest](https://hub.docker.com/r/vaultwarden/server)|
|[Immich](https://github.com/immich-app/immich)|Photo and image cloud replacement|[Documentation](https://docs.immich.app/)|Cloudflare upload limits can make video uploads difficult|[altran1502/immich-server:latest](https://hub.docker.com/r/altran1502/immich-server)|
|[Forgejo](https://github.com/forgejo/forgejo)|Git repository hosting|[Documentation](https://forgejo.org/docs/)|GitHub alternative|[einherji/forgejo:latest](https://hub.docker.com/r/einherji/forgejo)|
|[Paperless-NGX](https://github.com/paperless-ngx/paperless-ngx)|Document management and OCR|[Documentation](https://docs.paperless-ngx.com/)||[paperlessngx/paperless-ngx:latest](https://hub.docker.com/r/paperlessngx/paperless-ngx)|
|[NextCloud](https://github.com/nextcloud/server)|File sync/sharing, office, calendar, contacts|[Documentation](https://docs.nextcloud.com/)||[nextcloud:latest](https://hub.docker.com/_/nextcloud)|
|[Home Assistant](https://github.com/home-assistant/core)|Home automation platform|[Documentation](https://www.home-assistant.io/docs/)||[homeassistant/home-assistant:latest](https://hub.docker.com/r/homeassistant/home-assistant)|

### Trackers - Trackers for anything and everything to log in life

|Service|Purpose|Docs|Notes|Image|
|---|---|---|---|---|
|[Actual Budget](https://github.com/actualbudget/actual)|Local-first finance manager|[Documentation](https://actualbudget.github.io/docs/)||[actualbudget/actual-server:latest](https://ghcr.io/actualbudget/actual-server:latest)|
|[Mealie](https://github.com/hay-kot/mealie)|Recipe manager and meal planner|[Documentation](https://docs.mealie.io/)||[hkotel/mealie:latest](https://hub.docker.com/r/hkotel/mealie)|
|[Wger](https://github.com/wger-project/wger)|Workout manager|[Documentation](https://wger.readthedocs.io/en/latest/installation/docker.html)|Requires NGINX to be set up<br>Hopefully works with Traefik have to research|[docker.io/wger/server:latest](https://hub.docker.com/r/wger/wger)|
|[Monica](https://github.com/monicahq/monica)|Personal CRM|[Documentation](https://www.monicahq.com/docs/)|Useful for tracking family/friend details|[linuxserver/monica:latest](https://ghcr.io/linuxserver/monica:latest)|
|[Yamtrack](https://github.com/FuzzyGrim/Yamtrack)|Everything media tracker|[Documentation](https://github.com/FuzzyGrim/Yamtrack/wiki)|Syncs with Trakt/AniList<br>Calendar support<br>Waiting for audiobook/ABS support|[fuzzygrim/yamtrack:latest](https://ghcr.io/fuzzygrim/yamtrack:latest)|
|[Habitica](https://github.com/HabitRPG/habitica)|Game-mode task/habit tracking|[Documentation](https://github.com/HabitRPG/habitica/wiki)||[habitica/habitica:latest](https://hub.docker.com/r/habitica/habitica)|

### *Arr - Automated media downloading and management

|Service|Purpose|Docs|Notes|Image|
|---|---|---|---|---|
|[qBittorrent](https://github.com/qbittorrent/qBittorrent)|Torrent client|[Documentation](https://www.qbittorrent.org/docs/)||[linuxserver/qbittorrent:latest](https://ghcr.io/linuxserver/qbittorrent:latest)|
|[Gluetun](https://github.com/qdm12/gluetun)|VPN routing client for Docker|[Documentation](https://github.com/qdm12/gluetun#readme)|Works with any OpenVPN client, I'm using ProtonVPN|[qdm12/gluetun:latest](https://ghcr.io/qdm12/gluetun:latest)|
|[Prowlarr](https://github.com/Prowlarr/Prowlarr)|Indexer manager for *arr apps|[Documentation](https://wiki.servarr.com/prowlarr)|Syncs trackers to all *arr services|[linuxserver/prowlarr:latest](https://ghcr.io/linuxserver/prowlarr:latest)|
|[Jackett](https://github.com/Jackett/Jackett)|Torrent indexer proxy|[Documentation](https://github.com/Jackett/Jackett/wiki)|Alternative indexer to Prowlarr, has more choices but not as nicely integrated|[linuxserver/jackett:latest](https://ghcr.io/linuxserver/jackett:latest)|
|[FlareSolverr](https://github.com/FlareSolverr/FlareSolverr)|Cloudflare anti-bot solver for indexers|[Documentation](https://github.com/FlareSolverr/FlareSolverr/wiki)||[flaresolverr/flaresolverr:latest](https://ghcr.io/flaresolverr/flaresolverr:latest)|
|[Sonarr](https://github.com/Sonarr/Sonarr)|TV show request & organisation manager|[Documentation](https://wiki.servarr.com/sonarr)||[linuxserver/sonarr:latest](https://ghcr.io/linuxserver/sonarr:latest)|
|[Radarr](https://github.com/Radarr/Radarr)|Movie request & organisation manager|[Documentation](https://wiki.servarr.com/radarr)||[linuxserver/radarr:latest](https://ghcr.io/linuxserver/radarr:latest)|
|[Seerr](https://github.com/seerr-team/seerr)|TV/Movie request & organisation manager|[Documentation](https://docs.seer.dev)||[seerr/seerr:latest](https://hub.docker.com/r/seerr/seerr)|
|[Lidarr](https://github.com/Lidarr/Lidarr)|Music request & organisation manager|[Documentation](https://wiki.servarr.com/lidarr)||[linuxserver/lidarr:latest](https://ghcr.io/linuxserver/lidarr:latest)|
|[Shelfmark](https://github.com/calibrain/shelfmark)|Audiobook and book request & organisation manager|[Documentation](https://github.com/calibrain/shelfmark#readme)|Readarr would've been nice but it's archived since not enough people used it<br>Has good integration with Prowlarr and other services so it's decent<br>A few difficulties since it doesn't show certain download results which are available, only ones it can fetch the metadata for so many options are excluded|[calibrain/shelfmark:latest](https://ghcr.io/calibrain/shelfmark:latest)|
|[Bazarr](https://github.com/morpheus65535/bazarr)|Subtitle manager for Sonarr/Radarr|[Documentation](https://wiki.servarr.com/bazarr)||[linuxserver/bazarr:latest](https://ghcr.io/linuxserver/bazarr:latest)|
|[Profilarr](https://github.com/Dictionarry-Hub/Profilarr/)|Media quality/format manager|[Documentation](https://github.com/Dictionarry-Hub/Profilarr/wiki)|Can use TRaSH Guides<br>Still waiting on Lidarr integration|[santiagosayshey/profilarr:latest](https://ghcr.io/santiagosayshey/profilarr:latest)|
|[Decluttarr](https://github.com/ManiMatter/decluttarr)|Autoclears download queues|[Documentation](https://github.com/ManiMatter/decluttarr#readme)||[bwnance/decluttarr:latest](https://hub.docker.com/r/bwnance/decluttarr)|

### Apps - General apps that don't fit in another category

|Service|Purpose|Docs|Notes|Image|
|---|---|---|---|---|
|[Kiwix](https://github.com/kiwix/kiwix)|Offline Wikipedia and ZIM content reader|[Documentation](https://wiki.kiwix.org/wiki/Documentation)||[jamescherti/kiwix-serve:latest](https://hub.docker.com/r/jamescherti/kiwix-serve)|
|[Jitsi Meet](https://github.com/jitsi/jitsi-meet)|Video conferencing|[Documentation](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker)||[robertoandrade/jitsi-meet:latest](https://hub.docker.com/r/robertoandrade/jitsi-meet)|
|[Rustdesk](https://github.com/rustdesk/rustdesk)|Remote desktop server|[Documentation](https://rustdesk.com/docs/)||[rustdesk/rustdesk-server:latest](https://ghcr.io/rustdesk/rustdesk-server:latest)|
|[Draw.io](https://github.com/jgraph/drawio)|Diagram editor|[Documentation](https://github.com/jgraph/drawio#readme)||[jgraph/drawio:latest](https://hub.docker.com/r/jgraph/drawio)|
|[Excalidraw](https://github.com/excalidraw/excalidraw)|Collaborative whiteboard|[Documentation](https://github.com/excalidraw/excalidraw/wiki)||[excalidraw/excalidraw:latest](https://hub.docker.com/r/excalidraw/excalidraw)|
|[IT-Tools](https://github.com/CorentinTh/it-tools)|Developer utilities collection|||[corentinth/it-tools:latest](https://ghcr.io/corentinth/it-tools:latest)|

## Setup and Getting it Running

**File structure:**

```markdown
.
|-- .gitignore
|-- README.md
|-- backups/
|-- secrets-example/
    |-- default_admin.secret
    |-- ....secret
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

## Notes

### Secrets Management

- One big hurdle was deciding between `.env` environment variables and `.secret` or `.txt` files passed through as docker secrets.
- Went for `.secret` as this makes sure docker hides them correctly and they aren't loaded or exposed in logs
- It makes life a bit more difficult having to create a new file per secret or variable but I think it's good practice even if it's slightly more work
- Also true `.secret` files are encrypted with a proper tool but right now it's being used as a nice file extension as the VSCode material extension gives it an icon.
- Can look into how to do this proper later but might not matter since the repo is private and the secrets are ignored in git

### File Strucure

- Used the TRaSH guides as a general template for the overall `data/` and `data/media/` directory but then also looped in the PARA method in the `data/personal/` directory
- Rationale is that services like nextcloud docs and paperless-ngx are going to access the personal section more whereas streaming/downloading services will use the media section so it makes sense to split them up like that
- Also have a separate torrents and usenet section again stolen from TRaSH guides which allows for hardlinking from the `data/torrents/` and `data/usenet/` directories to the `data/media/`
  - Allows saving disk read/write health so it isn't needlessly duplicated after downloading, plus the original file is still in the same location for seeding (of public domain movies and such of course wink wink nudge nudge)
- The `backups/` folder is for storing backup files and scripts for backing up/restoring services and data, not sure how to do this yet but it's good to have a place for it

### Server Access

- Most of these apps/services will be accessed through Tailscale so I don't have to open ports or create 600 tunnels. Also this would be insecure anyways exposing something like paperless-ngx which holds very sensitive docs even behind Traefik and Authentik.
- Exposed services will still have their password and accounts in place it's just another layer of security.
- I'll be using Homepage or another dashboard for the quick links to each app, especially since some will be based on the port. Also logically each one running externally will also have an internal link with the tailscale ip and port so I'll be having both these links for both cases of access either exposed or via Tailscale.

### Port changes

- Going to change the standard ports for some/most these services so that they're out of the way of commonly used ones and also for extra security in case somehow they try get pinged using the default one by knowing the service's name and config this also a decent security through obscurity practice.
- Mostly going to be doing `20xxx` for infrastructure, `21xxx` maintenance, `22xxx` for media, `23xxx` for cloud, `24xxx` for trackers, `25xxx` for \*arr, and `26xxx` for apps
- I'm reckoning it might be a bit hellish to have Forgejo running on different ports and behind Authentik so I'll try if it's possible otherwise it might just be one I'll chance exposing and relying on it to have good security and all that
- Also the immich mobile client throws a fit if the port changes and is behind Authentik, so that one would need special handling or again one of those I'll have to live with

### Secret and environment variables

- Trying to use real secrets is tricky since not all apps and services can correctly parse and read them
- Compared to .env files which are almost universal
  - Docker files are a bit of a hell thing because you can't just specify two files in the `env_file:` section and expect them to merge, it's just the latest one that gets used
  - Also apparently even trying to use just one root env file also doesn't work for it because some variables get read only at container runtime so you have to do the CLI `docker compose --env-file. env up - d

### Docker compose files, compose override files and Dockerfiles

- So apparently it's good practice to keep the exact compose.yaml file exactly the same as the original one and then change the variables with compose.override.yaml
so that pulling changes is much easier and compatability reasons so might refactor to do this
- Dockerfiles are used in the stead of images in case that one isn't available, It's much more clear and defines what base software image, data does and envs to use but again it's sensitive to big changes and I'd have to keep up to it whereas images fo this automatically (double check this it's mostly intuition so far)

### Resource Allocation Guideline

Using docker's `deploy.resources.limits` implement resouce caps to prevent overly-hungry ones

|Impact|Example App|CPU|RAM|
|---|---|---|---|
|Heavy|Immich server/ML, Jellyfin, Paperless-NGX|2.0|2 GB|
|Medium|Audiobookshelf, qBittorrent, Lidarr, Stirling PDF, Home Assistant|1.0|512 M – 1 G|
|Light|Most other services|0.25 – 0.5|128 M – 512 M|
|DB/cache|postgres, redis, mysql|0.25 – 0.5|256 M – 1 G|
