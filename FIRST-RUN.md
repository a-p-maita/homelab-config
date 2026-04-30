# First-Run Setup Guide

After running `./scripts/up-all.sh` for the first time, several services require manual steps before they are fully usable — either to set credentials, complete a setup wizard, or configure initial state.

> **Services already completed**: Jellyfin, Home Assistant, Yamtrack — these are already set up and documented as done.

---

## 1. Uptime Kuma — set password, then run monitor script

1. Open `http://localhost:20201`
2. Create your admin account (username + password) via the signup screen
3. Add `UPTIMEKUMA_USER` and `UPTIMEKUMA_PASS` to `.env` matching those credentials
4. Run the monitor setup script:

```bash
./scripts/setup-uptime-kuma.sh
```

This script creates all monitors automatically. Re-running is safe (idempotent).

---

## 2. Forgejo — create admin via the setup wizard

Public registration is **disabled by default** (`FORGEJO__service__DISABLE_REGISTRATION=true`).

1. Open `http://localhost:20110`
2. Forgejo shows a **one-time installation wizard** on the first visit (before any user exists)
3. Scroll to **Administrator Account Settings** at the bottom and create your admin account
4. Click **Install Forgejo** — the wizard runs only once and is gone after the first admin is created
5. No other users can self-register; create additional accounts from **Site Administration → Users**

---

## 3. Joplin Server — change default admin credentials immediately

**Default credentials:** `admin@localhost` / `admin`

1. Open `http://localhost:20317`
2. Log in with the defaults above
3. Go to **Admin → Users** and change the email and password to something secure
4. Then configure your Joplin desktop/mobile clients:
   - Sync target: **Joplin Server**
   - Host: your external URL (e.g. `https://joplin.andreasmaita.com`) or `http://localhost:20317` locally
   - Email + password: the new credentials you just set

---

## 4. Vaultwarden — create first account via admin panel

Signups are **disabled by default** (`SIGNUPS_ALLOWED=false`). The admin panel is the way in.

1. Open `http://localhost:20315/admin`
2. Authenticate with the `VAULTWARDEN_ADMIN_TOKEN` from `.env`
3. Go to **Users** → **Invite user** (enter your email) or temporarily toggle "Allow signups" to register via the main UI, then toggle it back off
4. Alternatively: add `VAULTWARDEN_SIGNUPS_ALLOWED=true` to `.env` and update the compose line to `SIGNUPS_ALLOWED=${VAULTWARDEN_SIGNUPS_ALLOWED:-false}`, restart, register, then remove the override and restart again
5. Your vault is at `http://localhost:20315` — use the Bitwarden-compatible browser extension or mobile app to connect

---

## 5. Mealie — change default credentials

**Default credentials:** `changeme@example.com` / `MyPassword`

1. Open `http://localhost:20321`
2. Log in with the defaults above
3. Go to **Profile → Settings** and update your email, username, and password

---

## 6. Navidrome — create admin account on first visit

1. Open `http://localhost:20070`
2. The first login page asks you to create an admin account
3. Set username and password — this becomes your Navidrome admin

---

## 7. Lidarr — complete setup wizard

See **Section 10** (\*arr Stack) for the full setup, including indexer and download client configuration.
Quick reference:

- Root folder: `/data/media/music`
- Download client: qBittorrent at `http://qbittorrent:20050`, category `music`
- Indexers: add via Prowlarr sync (see Section 10)

---

## 8. Paperless-NGX — already set up

Already completed. Documents are consumed from `data/paperless/consume/`.

---

## 9. Stirling PDF — set credentials before first start

Login is **enabled by default**. Set your credentials in `.env` before running `up-all.sh`:

```
STIRLING_PDF_USERNAME=admin
STIRLING_PDF_PASSWORD=yourpassword
```

On first start, Stirling PDF creates the initial admin account from these values.

If you already started without setting a password, the `settings.yml` is seeded from the template with blank credentials — Stirling PDF will prompt you to set a password on the login page.

---

## Services with no first-run step required

| Service        | Notes                                                                                                                                                                                                                                |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Audiobookshelf | Create account on first visit — self-service                                                                                                                                                                                         |
| Immich         | Credentials pre-configured via `.env`                                                                                                                                                                                                |
| qBittorrent    | WebUI password set in `config-templates/qbittorrent/qBittorrent.conf`                                                                                                                                                                |
| Jackett        | API key set in `ServerConfig.json` template                                                                                                                                                                                          |
| Actual Budget  | Creates a local vault on first open — no account needed. If you see a SharedArrayBuffer error, clear browser cache (server already sends correct COOP/COEP headers). Accessed at `http://localhost:20316` (not in Cloudflare tunnel) |
| Feishin        | Pre-locked to Navidrome — just use Navidrome credentials                                                                                                                                                                             |
| Octo-Fiesta    | No login — configured entirely via `.env`                                                                                                                                                                                            |
| Kiwix          | Add ZIM files to `data/kiwix/` — auto-discovered                                                                                                                                                                                     |
| Stirling PDF   | Login enabled. Credentials set via `STIRLING_PDF_USERNAME`/`STIRLING_PDF_PASSWORD` in `.env`                                                                                                                                         |

---

## 10. Seerr — complete the setup wizard

Seerr is a media request manager: users browse movies/TV, click Request, and Seerr automatically routes the request to Radarr or Sonarr.

1. Open `http://100.106.40.5:20331`
2. **Setup wizard — Step 1: Media Server**
   - Select **Jellyfin**
   - Hostname: `jellyfin`, Port: `8096`, Use SSL: off
   - Enter your Jellyfin admin username + password → click **Save Changes**
   - Click **Sync Libraries** to import your existing Jellyfin libraries
3. **Setup wizard — Step 2: Configure services**
   - **Add Radarr:**
     - Hostname: `radarr`, Port: `7878`, API Key: (from Radarr → Settings → General)
     - Quality Profile: choose your preferred profile
     - Root Folder: `/data/media/movies`
     - Enable: ☑ Default Server, ☑ Enable Scan
   - **Add Sonarr:**
     - Hostname: `sonarr`, Port: `8989`, API Key: (from Sonarr → Settings → General)
     - Quality Profile: choose your preferred profile
     - Root Folder: `/data/media/tv`
     - Enable: ☑ Default Server, ☑ Enable Scan
4. Click **Finish Setup**

After setup, Seerr imports your Jellyfin users — they can log in with their Jellyfin credentials and request media immediately.

---

## 11. \*arr Stack — initial configuration

Services: **Prowlarr**, **Radarr**, **Sonarr**, **LazyLibrarian**, **Lidarr**, **Byparr**, **Jackett** (legacy), **qBittorrent**, **Audiobookbay Downloader**

All arr services are Tailscale-only — access via `http://100.106.40.5:PORT`.

**Recommended order:** qBittorrent → each \*arr app (get API keys) → Prowlarr (add apps + indexers) → Prowlarr syncs indexers automatically.

---

### Step 1: qBittorrent

1. Open `http://100.106.40.5:20050`
2. Log in with `QBITTORRENT_WEBUI_USER` / `QBITTORRENT_WEBUI_PASS` from `.env`
3. **Tools → Options → Web UI → ☑ "Bypass authentication for clients on localhost"**
   Required for VPN port-sync script. Safe — only containers in the same network namespace have localhost access.

**Verify categories are loaded:**
Categories are NOT in `Tools → Options → Downloads`. They appear in the **left panel** of the main qBittorrent window (you may need to enable it: `View → Side Panel`). You should see: `All`, `Uncategorized`, then `abb-downloader`, `books`, `movies`, `music`, `tv`.

If the categories are missing, the container started before the file was in place. Fix:

```bash
docker restart qbittorrent
```

Wait ~30 seconds for the health check to pass, then refresh the WebUI.

If categories still don't appear, add them manually: right-click any entry in the left panel → **Add Category**, or go to **Tools → Options → Downloads** scroll to the bottom — there is a Categories section (in some qBittorrent versions it's a separate sidebar item). Add each with these save paths:

| Category         | Save path                |
| ---------------- | ------------------------ |
| `movies`         | `/data/torrents/movies`  |
| `tv`             | `/data/torrents/tv`      |
| `music`          | `/data/torrents/music`   |
| `books`          | `/data/torrents/books`   |
| `abb-downloader` | `/data/media/audiobooks` |

4. **Tools → Options → Downloads → Saving Management:**
   - Default Torrent Management Mode: **Automatic**
   - (You confirmed this is already done)

---

### Step 2: Get API keys from each \*arr app

Before setting up Prowlarr, collect the API key from each app:

| App           | URL                         | Where to find API key                   |
| ------------- | --------------------------- | --------------------------------------- |
| Radarr        | `http://100.106.40.5:20056` | Settings → General → Security → API Key |
| Sonarr        | `http://100.106.40.5:20057` | Settings → General → Security → API Key |
| LazyLibrarian | `http://100.106.40.5:20058` | Settings → Interface → API key          |
| Lidarr        | `http://100.106.40.5:20059` | Settings → General → Security → API Key |

Each app shows a setup wizard on first visit — complete it (set UI language, etc.) to reach the Settings page.

---

### Step 3: Configure each \*arr app

Do this for each app before connecting Prowlarr, so indexers sync correctly.

#### Radarr (movies) — `http://100.106.40.5:20056`

1. **Settings → Media Management**
   - Enable: ☑ Rename Movies
   - Root Folders → Add → type `/data/media/movies` → click OK
2. **Settings → Download Clients → + Add**
   - Type: **qBittorrent**
   - Host: `qbittorrent`, Port: `20050`
   - Username / Password: from `.env`
   - Category: `movies` ← **critical** — this is how the save path is applied
   - Test → Save
3. **Settings → General → copy your API key** (needed for Prowlarr)

#### Sonarr (TV) — `http://100.106.40.5:20057`

1. **Settings → Media Management → Root Folders** → Add `/data/media/tv`
2. **Settings → Download Clients → + Add → qBittorrent**
   - Host: `qbittorrent`, Port: `20050`, credentials from `.env`, Category: `tv`
3. Copy API key from Settings → General

#### LazyLibrarian (books/ebooks/magazines) — `http://100.106.40.5:20058`

1. **Config → Processing → Book/Author folder** — set to `/data/media/books`
2. **Config → Downloaders → qBittorrent:**
   - Host: `qbittorrent`, Port: `20050`, Username/Password from `.env`, Category: `books`
   - Test connection → Save
3. **Config → Providers → Torznab — add Prowlarr as indexer source:**
   - URL: `http://prowlarr:9696/{PROWLARR_API_KEY}/api`
   - Prowlarr API key: from Prowlarr → Settings → General
   - Test → Save
4. Copy API key from **Settings → Interface → API key** (needed for Step 3 above)

#### Lidarr (music) — `http://100.106.40.5:20059`

1. **Settings → Media Management → Root Folders** → Add `/data/media/music`
2. **Settings → Download Clients → + Add → qBittorrent**
   - Host: `qbittorrent`, Port: `20050`, credentials from `.env`, Category: `music`
3. Copy API key from Settings → General

---

### Step 4: Prowlarr — add indexers and connect apps

1. Open `http://100.106.40.5:20055`
2. Create your admin account on first visit

#### Add your \*arr apps to Prowlarr

This makes Prowlarr push indexers to each app automatically — you only manage indexers in one place.

**Settings → Apps → + Add Application:**

For each app below, the pattern is the same:

- Click the app icon (Radarr / Sonarr / Lidarr)
- **Prowlarr Server:** `http://prowlarr:9696`
- **App URL:** the internal Docker URL (e.g. `http://radarr:7878`)
- **API Key:** paste from the app's Settings → General
- Sync Level: **Full Sync** (Prowlarr adds/removes indexers in the app automatically)
- Click **Test** — you should see a green tick — then **Save**

| App    | App URL              | Port  |
| ------ | -------------------- | ----- |
| Radarr | `http://radarr:7878` | 20056 |
| Sonarr | `http://sonarr:8989` | 20057 |
| Lidarr | `http://lidarr:8686` | 20059 |

> **LazyLibrarian** connects to Prowlarr differently — via Torznab, not the native app integration. See Step 3 → LazyLibrarian setup above.

#### Add indexers

Indexers are torrent trackers. After adding an indexer in Prowlarr, it automatically syncs to all connected apps.

**Indexers → Add Indexer** — search by name and select your trackers. Common ones:

| Indexer type        | Examples                                        | Notes                                   |
| ------------------- | ----------------------------------------------- | --------------------------------------- |
| Public (no account) | 1337x, YTS, RARBG mirrors, EZTV, The Pirate Bay | Work immediately, no setup              |
| Semi-private        | Nyaa (anime), MagnetDL                          | May need account for better results     |
| Private             | PTP, BTN, HDB, etc.                             | Require invite, login via cookie or API |

**For each indexer:**

1. Search → click the indexer
2. If it requires a cookie/API key: paste it in the fields shown
3. Set **Categories** — important: select only what the indexer covers (e.g. Movies for YTS, TV for EZTV) so each app only gets relevant indexers
4. **Test → Save**

After saving, Prowlarr automatically pushes the indexer to all connected apps within a few seconds.

#### Verify sync worked

In Radarr: **Settings → Indexers** — you should see the indexers Prowlarr pushed.
If the list is empty, go back to Prowlarr → Settings → Apps → click the app → **Sync App Indexers**.

#### Jackett (legacy — for Audiobookbay Downloader only)

Jackett is kept specifically because Audiobookbay Downloader only supports Jackett, not Prowlarr.
The API key is pre-configured (`JACKETT_API_KEY` in `.env` and `ServerConfig.json` template).
Open `http://100.106.40.5:20054` to add the `audiobookbay` tracker if not already present.

#### Byparr (Cloudflare anti-bot bypass)

Byparr is a FlareSolverr-compatible service that lets Prowlarr access Cloudflare-protected indexers.
Once running, register it in Prowlarr:

1. **Settings → Indexers → FlareSolverr**
2. Set URL to `http://byparr:8191`
3. Test → Save

Then when adding a Cloudflare-protected indexer in Prowlarr, set **FlareSolverr Tag** to select the Byparr instance.

---

### Step 5: Audiobookbay Downloader — `http://100.106.40.5:20053`

1. Go to **Settings** tab
2. Verify the Jackett connection shows green
3. Verify qBittorrent connection shows green
4. The `abb-downloader` category saves to `/data/media/audiobooks` — Audiobookshelf picks it up automatically on next scan

---

### Step 6: Test a download end-to-end

1. In Radarr, search for a movie → Add Movie → set root folder to `/data/media/movies`
2. Use the **Interactive Search** (magnifying glass icon on a wanted movie) to manually trigger a search and pick a release
3. Watch qBittorrent — the torrent should appear in the `movies` category
4. Once complete, Radarr imports it to `/data/media/movies/` (rename + hardlink — instant)
5. Jellyfin: Libraries → scan for it

---

## 12. Homepage arr widgets — add API keys after first arr start

The Homepage dashboard has live stat widgets for each \*arr service and qBittorrent, but they need API keys that are only generated after each service first starts.

**Do this after the arr stack has been running at least once.**

For each service, open the UI and copy the API key from **Settings → General**:

| Service  | URL                         | `.env` variable    |
| -------- | --------------------------- | ------------------ |
| Radarr   | `http://100.106.40.5:20056` | `RADARR_API_KEY`   |
| Sonarr   | `http://100.106.40.5:20057` | `SONARR_API_KEY`   |
| Lidarr   | `http://100.106.40.5:20059` | `LIDARR_API_KEY`   |
| Prowlarr | `http://100.106.40.5:20055` | `PROWLARR_API_KEY` |

> **LazyLibrarian** has no Homepage widget — no API key needed here.
> **Byparr** has no API key authentication.

Then fill them in `.env`:

```env
RADARR_API_KEY=your_32char_key_here
SONARR_API_KEY=your_32char_key_here
LIDARR_API_KEY=your_32char_key_here
PROWLARR_API_KEY=your_32char_key_here
```

Then restart the monitoring stack to pick up the new env vars:

```bash
docker compose --env-file .env -f dockerfiles/monitoring/compose.yaml up -d
```

qBittorrent widget uses `QBITTORRENT_WEBUI_USER` / `QBITTORRENT_WEBUI_PASS` from `.env` — no extra step needed.

---

## 11. ProtonVPN / Gluetun — enabling the VPN (optional, do after initial setup)

**Prerequisites:**

- ProtonVPN Plus subscription (required for port forwarding)
- WireGuard private key — generate at: account.proton.me/u/0/vpn/WireGuard → Linux → WireGuard → Create

**Steps:**

1. Add the private key to `.env`:

   ```
   PROTONVPN_WIREGUARD_PRIVATE_KEY=<your-key>
   ```

2. Enable VPN in `.env`:

   ```
   USE_VPN=true
   ```

3. Restart the arr stack:

   ```bash
   cd ~/homelab-config
   source .env
   docker compose --env-file .env -f dockerfiles/arr/compose.yaml -f dockerfiles/arr/compose.vpn.yaml down
   docker compose --env-file .env -f dockerfiles/arr/compose.yaml -f dockerfiles/arr/compose.vpn.yaml up -d
   ```

4. Verify the VPN tunnel is working (wait ~2 minutes for gluetun to connect, then):

   ```bash
   docker run --rm --network=container:gluetun alpine:3.18 sh -c "apk add -q wget && wget -qO- https://ipinfo.io"
   ```

   The IP shown should be a ProtonVPN server IP (not your home IP).

5. Verify port forwarding — check gluetun logs:
   ```bash
   docker logs gluetun | grep -i port
   ```
