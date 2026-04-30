File and Folder Structure
Introduction

It is important that your media server has a well-organized file and folder structure. Along with generally easier file and folder management, you will benefit from:

    Improved security is achieved by only granting the appropriate applications and tools access to your files.
    Hardlinks, so the same file can appear in multiple places while only taking up one copy's disk space.
    Instant moves (also known as 'Atomic Moves') so that files can be moved to other parts of the file system instantaneously.

The first requirement is that all your media files and folders be in the same file system. Everything must be contained on a single physical or virtual drive. Second, all your applications should have a consistent view of where your files and folders are - i.e., your files should appear in the same place as all your applications.

We recommend setting up a file and folder structure on your host server that looks like this:

data
├── torrents
│ ├── books
│ ├── movies
│ ├── music
│ └── tv
├── usenet
│ ├── incomplete
│ └── complete
│ ├── books
│ ├── movies
│ ├── music
│ └── tv
└── media
├── books
├── movies
├── music
└── tv

The data folder can be placed wherever you like. For example, in Unraid, you would set up a share called data. This would then be accessible within Unraid's file system at /mnt/user/data.

If you install applications directly on the host system (natively), they will already have visibility of that file and folder structure, assuming permissions are set correctly. Suppose you are installing applications non-natively, for example, via Docker. In that case, each application should be granted access to the required lowest-level folder while maintaining consistent pathing to the top-level folder, which here is data. For example, a torrent client installed via Docker would have /mnt/user/data/torrents mapped to /data/torrents. This means the download client would see the contents of the host's /mnt/user/data/torrents folder in the /data/torrents folder within the container.

The How To Set Up section provides more detailed examples.

Docker

Tip

If you're new to Docker containers and want an easy setup, we suggest taking a look at DockSTARTer. We've also created a short guide HERE where we explain the settings for the most used applications.

The main goal of DockSTARTer is to make it quick and easy to get up and running with Docker. You may choose to rely on DockSTARTer for various changes to your Docker system or use DockSTARTer as a stepping stone and learn to do more advanced configurations.

DockSTARTer was actually my first step into the world of Docker containers.

Note

I'm not going to explain how to get Docker installed and running, we will only explain which folder structure we recommend.

The paths mentioned below refer to internal paths (or Container Path) for the containers!

External paths (or Host Path) depend on where you mounted your share or your drives.

For example /<path_to_data>/data, or even /data.
Folder Structure

Warning

It doesn't really matter which path you use for your media and appdata,

the only thing you should avoid is /home.

Because user folders in /home are expected to have some restrictive permissions.

It just could end up creating a permissions mess, so it's better to just avoid entirely.

For this example we're going to make use of a share called data.

The data folder has sub-folders for torrents and usenet and each of these have sub-folders for tv, movie, books and music downloads to keep things neat. The media folder has nicely named TV, Movies, Books and Music sub-folders, this is your library and what you’d pass to Plex, Emby or JellyFin.

In this examples I'm using lower case on all folder on purpose, being Linux is case sensitive.

data
├── torrents
│ ├── books
│ ├── movies
│ ├── music
│ └── tv
├── usenet
│ ├── incomplete
│ └── complete
│ ├── books
│ ├── movies
│ ├── music
│ └── tv
└── media
├── books
├── movies
├── music
└── tv

Fastest way to create the needed subfolders

The fastest way to create all the necessary subfolders would be to use the terminal, use a program like PuTTY. These options will automatically create the required subfolders for your media library as well as your preferred download client(s). If you use both torrents and Usenet, use both commands.
If you use Usenet

mkdir -p /data/{usenet/{incomplete,complete}/{tv,movies,music},media/{tv,movies,music}}

If you use torrents

mkdir -p /data/{torrents/{tv,movies,music},media/{tv,movies,music}}

Bad path suggestion

The default path setup suggested by some Docker developers that encourages people to use mounts like /movies, /tv, /books or /downloads is very suboptimal and it makes them look like two or three file systems, even if they aren’t (Because of how Docker’s volumes work). It is the easiest way to get started. While easy to use, it has a major drawback. Mainly losing the ability to hardlink or instant move, resulting in a slower and more I/O intensive copy + delete is used.
Breakdown of the Folder Structure
Torrent clients

qBittorrent, Deluge, ruTorrent

The reason why we use /data/torrents for the torrent client is because it only needs access to the torrent files. In the torrent software settings, you’ll need to reconfigure paths and you can sort into sub-folders like /data/torrents/{tv|movies|music}.

data
└── torrents
├── books
├── movies
├── music
└── tv

Container Path: => /data/torrents/

Host Path: => /<path_to_data>/data/torrents/
Usenet clients

NZBGet or SABnzbd

The reason why we use /data/usenet for the Usenet client is because it only needs access to the Usenet files. In the Usenet software settings, you’ll need to reconfigure paths and you can sort into sub-folders like /data/usenet/complete/{tv|movies|music}.

data
└── usenet
├── incomplete
└── complete
├── books
├── movies
├── music
└── tv

Container Path: => /data/usenet/

Host Path: => /<path_to_data>/data/usenet/
The Starr Apps

Sonarr, Radarr, Readarr and Lidarr

Sonarr, Radarr, Readarr and Lidarr gets access to everything using /data because the download folder(s) and media folder will look like and be one file system. Hardlinks will work and moves will be atomic, instead of copy + delete.

data
├── torrents
│ ├── books
│ ├── movies
│ ├── music
│ └── tv
├── usenet
│ ├── incomplete
│ └── complete
│ ├── books
│ ├── movies
│ ├── music
│ └── tv
└── media
├── books
├── movies
├── music
└── tv

Container Path: => /data

Host Path: => /<path_to_data>/data/
Media Server

Plex, Emby, JellyFin and Bazarr

Plex, Emby, JellyFin and Bazarr only needs access to your media library using /data/media, which can have any number of sub folders like Movies, Kids Movies, TV, Documentary TV and/or Music as sub folders.

data
└── media
├── movies
├── music
├── books
└── tv

Container Path: => /data/media

Host Path: => /<path_to_data>/data/media/

Don't forget to look at the Examples how to set up the paths inside the applications.
Permissions

Recursively chown user and group and Recursively chmod to 775/664

sudo chown -R $USER:$USER /data
sudo chmod -R a=,a+rX,u+w,g+w /data

Docker-compose Example

This is a docker-compose example based on a default Ubuntu install.

The storage location used for the host is the same as in the container to make it easier to understand in this case /data.

The appdata (/config) will be stored on the host in the /docker/appdata/{appname}
docker-compose - [Click to show/hide]

version: "3.2"
services:
radarr:
container_name: radarr
hostname: radarr.internal
image: ghcr.io/hotio/radarr:latest
restart: unless-stopped
logging:
driver: json-file
ports: - 7878:7878
environment: - PUID=1000 - PGID=1000 - TZ=Europe/Amsterdam
volumes: - /etc/localtime:/etc/localtime:ro - /docker/appdata/radarr:/config - /data:/data
sonarr:
container_name: sonarr
hostname: sonarr.internal
image: ghcr.io/hotio/sonarr:latest
restart: unless-stopped
logging:
driver: json-file
ports: - 8989:8989
environment: - PUID=1000 - PGID=1000 - TZ=Europe/Amsterdam
volumes: - /etc/localtime:/etc/localtime:ro - /docker/appdata/sonarr:/config - /data:/data
bazarr:
container_name: bazarr
hostname: bazarr.internal
image: ghcr.io/hotio/bazarr:latest
restart: unless-stopped
logging:
driver: json-file
ports: - 6767:6767
environment: - PUID=1000 - PGID=1000 - TZ=Europe/Amsterdam
volumes: - /etc/localtime:/etc/localtime:ro - /docker/appdata/bazarr:/config - /data/media:/data/media
sabnzbd:
container_name: sabnzbd
hostname: sabnzbd.internal
image: ghcr.io/hotio/sabnzbd:latest
restart: unless-stopped
logging:
driver: json-file
ports: - 8080:8080 - 9090:9090
environment: - PUID=1000 - PGID=1000 - TZ=Europe/Amsterdam
volumes: - /etc/localtime:/etc/localtime:ro - /docker/appdata/sabnzbd:/config - /data/usenet:/data/usenet:rw

Docker-Compose Commands
docker-compose commands - [Click to show/hide]

    sudo docker-compose up -d (This Docker-compose command helps builds the image, then creates and starts Docker containers. The containers are from the services specified in the compose file. If the containers are already running and you run docker-compose up, it recreates the container.)
    sudo docker-compose pull (Pulls an image associated with a service defined in a docker-compose.yml)
    sudo docker-compose down (The Docker-compose down command also stops Docker containers like the stop command does. But it goes the extra mile. Docker-compose down, doesn’t just stop the containers, it also removes them.)
    sudo docker system prune -a --volumes --force (Remove all unused containers, networks, images (both dangling and unreferenced), and optionally, volumes.)

Examples

Info

Pick one path layout and use it for all of them.

It doesn't matter if you prefer to use /data, /shared, /storage or whatever.

The screenshots in the examples use the following root path /data
Sonarr
Sonarr Examples - [Click to show/hide]

Settings => Media Management => Importing

sonarr-enable-hardlinks

Settings => Media Management => Root Folders

sonarr-root-folder

Series => Add New

sonarr-add-new

sonarr-tv
Radarr
Radarr Examples - [Click to show/hide]

Settings => Media Management => Importing

radarr-enable-hardlinks

Settings => Media Management => Root Folders

radarr-root-folder

Movies => Add New

radarr-add-new

radarr-movies
SABnzbd
SABnzbd Examples - [Click to show/hide]

SABnzbd config => Folders

sabnzbd-folders

SABnzbd config => Categories

sabnzbd-categories

Don't forget to look at the full SABnzbd Guides

    SABnzbd - Basic Setup
    SABnzbd - Paths and Categories

NZBGet
NZBGet Examples - [Click to show/hide]

Settings => PATHS

nzbget-settings-paths

Settings => CATEGORIES

nzbget-settings-categories

Don't forget to look at the full NZBGet Guides

    NZBGet - Basic Setup
    NZBGet - Paths and Categories

qBittorrent
qBittorrent Examples - [Click to show/hide]

Options => Downloads

qbt-options-downloads

Don't forget to look at the full qBittorrent Guides

    qBittorrent - Basic Setup
    qBittorrent - Paths
    qBittorrent - How to add categories

Deluge
Deluge Example - [Click to show/hide]

Preferences => Downloads

deluge-preferences-downloads

Don't forget to look at the full Deluge Guides

    Deluge - Basic Setup
    Deluge - Using Labels

ruTorrent
ruTorrent Examples - [Click to show/hide]

../config/rtorrent/config/rtorrent.rc (path to your appdata)

rtorrent.rc

Settings => Downloads

rtorrent-settings-downloads

Settings => Autotools

rtorrent-settings-autotools

Big Thanks to fryfrog for his Docker Guide that we used as a basis for this guide.
