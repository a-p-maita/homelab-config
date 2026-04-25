A homelab setup to repurpose my old laptop.

Uses a variety of microservices that I deem essential but will eventually add onto.


Depends on/creates another directory one step up called `homelab-data/` which holds all the permanent data being written like images, audiobooks and databases.
Thinking about it I should just make it in this root and .gitignore it, but oh well.

## Port Configuration & Security

All service ports (except Immich) are configurable via `.env` files and set to uncommon, high-numbered values by default. This reduces the risk of port collisions and makes the setup less susceptible to automated scans and attacks. To change a port, edit the relevant variable in the `.env` file for each stack. See the `.env.example` files for guidance.

**Immich** uses its standard port for compatibility with clients and integrations.

**Never commit real secrets or tokens to version control.** Only use `.env.example` for templates.

In use:
 - Audiobookshelf (Audiobooks)
 - Immich (Photo/video)
 - Ryot (Media tracker like tv/movie/audiobook)

Down/work in progress:
 - Forgejo (github alternative)
