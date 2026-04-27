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

## 6. Monica — register first user

1. Open `http://localhost:20323`
2. Click **Register** to create your account
3. Monica's first account is the primary user

---

## 7. MeshCentral — run setup wizard

1. Open `http://localhost:20319`
2. MeshCentral presents a setup wizard on first visit — follow the steps to create your admin account
3. After setup, add your devices via the agent installer or network scan

---

## 8. RomM — admin created automatically from `.env`

RomM auto-creates the admin user on first start using:

```
ROMM_ADMIN_USER=...
ROMM_ADMIN_PASS=...
```

Set these in `.env` before running `up-all.sh`. No web UI signup required.

After first start:

1. Open `http://localhost:20331`
2. Log in with the credentials you set in `.env`
3. Add your ROM library paths and run an initial scan

---

## 9. Navidrome — create admin account on first visit

1. Open `http://localhost:20070`
2. The first login page asks you to create an admin account
3. Set username and password — this becomes your Navidrome admin

---

## 10. Lidarr — complete setup wizard

1. Open `http://localhost:20073`
2. Complete the initial configuration wizard
3. Add **Jackett** as an indexer: URL `http://jackett:9117`, API key from `.env` (`JACKETT_API_KEY`)
4. Add **qBittorrent** as a download client: URL `http://qbittorrent:20050`, credentials from `.env`
5. Set the music root folder to `/music`

---

## 11. slskd (Soulseek) — log in with `.env` credentials

1. Open `http://localhost:20075`
2. Log in with `SLSKD_USERNAME` / `SLSKD_PASSWORD` from `.env`
3. slskd will connect to the Soulseek network automatically

---

## 12. Paperless-NGX — already set up

Already completed. Documents are consumed from `homelab-data/paperless/consume/`.

---

## 13. Stirling PDF — set credentials before first start

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
| Kiwix          | Add ZIM files to `homelab-data/kiwix/` — auto-discovered                                                                                                                                                                             |
| Stirling PDF   | Login enabled. Credentials set via `STIRLING_PDF_USERNAME`/`STIRLING_PDF_PASSWORD` in `.env`                                                                                                                                         |
| Code Server    | Password set via `CODE_SERVER_PASSWORD` in `.env`                                                                                                                                                                                    |
| LubeLogger     | Credentials set via `LUBELOGGER_ADMIN_USER/PASS` in `.env`                                                                                                                                                                           |
