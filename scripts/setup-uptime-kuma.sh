#!/bin/bash
# Sets up all Uptime Kuma monitors by running a Python script inside a temporary
# container on homelab_net so it can reach services by container name.
#
# Usage:
#   ./scripts/setup-uptime-kuma.sh
#
# Run this AFTER up-all.sh. Monitors are idempotent — re-running skips existing monitors by name.
set -e

cd "$(dirname "$0")/.."

# Load credentials from .env — never hardcode them here (this file is tracked by git)
if [ -f .env ]; then
  UPTIMEKUMA_USER=$(grep -E '^UPTIMEKUMA_USER=' .env | head -1 | cut -d= -f2- | sed "s/^['\"]//; s/['\"]$//")
  UPTIMEKUMA_PASS=$(grep -E '^UPTIMEKUMA_PASS=' .env | head -1 | cut -d= -f2- | sed "s/^['\"]//; s/['\"]$//")
fi
: "${UPTIMEKUMA_USER:?UPTIMEKUMA_USER not set — add it to .env}"
: "${UPTIMEKUMA_PASS:?UPTIMEKUMA_PASS not set — add it to .env}"

# Wait for Uptime Kuma to be reachable (up to 90 seconds)
echo "Waiting for Uptime Kuma to be ready..."
for i in $(seq 1 45); do
    if curl -sf http://localhost:20201 > /dev/null 2>&1; then
        echo "Uptime Kuma is ready."
        break
    fi
    if [ "$i" -eq 45 ]; then
        echo "Error: Uptime Kuma did not become ready after 90s. Run up-all.sh first." >&2
        exit 1
    fi
    sleep 2
done

cat > /tmp/kuma_setup.py << 'PYEOF'
import sys, os
from uptime_kuma_api import UptimeKumaApi, MonitorType

MONITORS = [
    # ── Infrastructure ───────────────────────────────────────────────────────
    {
        "name":     "Caddy",
        "type":     MonitorType.HTTP,
        "url":      "http://caddy:80",
        "interval": 60,
    },
    {
        "name":     "Authelia",
        "type":     MonitorType.HTTP,
        "url":      "http://authelia:9091/api/health",
        "interval": 60,
    },
    {
        "name":     "Homepage",
        "type":     MonitorType.HTTP,
        "url":      "http://homepage:3000",
        "interval": 60,
    },
    # ── Arr stack ────────────────────────────────────────────────────────────
    {
        "name":     "qBittorrent",
        "type":     MonitorType.HTTP,
        "url":      "http://qbittorrent:20050",
        "interval": 60,
    },
    {
        # Jackett /health returns 200; root path redirects and fails HTTP monitors.
        "name":     "Jackett",
        "type":     MonitorType.HTTP,
        "url":      "http://jackett:9117/health",
        "interval": 60,
    },
    {
        "name":     "Prowlarr",
        "type":     MonitorType.HTTP,
        "url":      "http://prowlarr:9696/ping",
        "interval": 60,
    },
    {
        "name":     "Radarr",
        "type":     MonitorType.HTTP,
        "url":      "http://radarr:7878/ping",
        "interval": 60,
    },
    {
        "name":     "Sonarr",
        "type":     MonitorType.HTTP,
        "url":      "http://sonarr:8989/ping",
        "interval": 60,
    },
    {
        "name":     "Lidarr",
        "type":     MonitorType.HTTP,
        "url":      "http://lidarr:8686/ping",
        "interval": 60,
    },
    {
        "name":     "Bazarr",
        "type":     MonitorType.HTTP,
        "url":      "http://bazarr:6767",
        "interval": 60,
    },
    {
        "name":     "Autobrr",
        "type":     MonitorType.HTTP,
        "url":      "http://autobrr:7474",
        "interval": 60,
    },
    {
        "name":     "Seerr",
        "type":     MonitorType.HTTP,
        "url":      "http://seerr:5055/api/v1/settings/public",
        "interval": 60,
    },
    {
        # Byparr (FlareSolverr successor) — root redirects to /docs but returns 200
        "name":     "Byparr",
        "type":     MonitorType.HTTP,
        "url":      "http://byparr:8191/",
        "interval": 120,
    },
    {
        "name":     "Cleanuparr",
        "type":     MonitorType.HTTP,
        "url":      "http://cleanuparr:11011",
        "interval": 120,
    },
    {
        "name":     "Profilarr",
        "type":     MonitorType.HTTP,
        "url":      "http://profilarr:6868",
        "interval": 120,
    },
    {
        "name":     "Maintainerr",
        "type":     MonitorType.HTTP,
        "url":      "http://maintainerr:6246",
        "interval": 120,
    },
    {
        "name":     "Audiobookbay Downloader",
        "type":     MonitorType.HTTP,
        "url":      "http://audiobookbay-downloader:9000",
        "interval": 60,
    },
    {
        "name":     "BookBounty",
        "type":     MonitorType.HTTP,
        "url":      "http://bookbounty:5000",
        "interval": 60,
    },
    # ── Media stack ──────────────────────────────────────────────────────────
    {
        "name":     "Jellyfin",
        "type":     MonitorType.HTTP,
        "url":      "http://jellyfin:8096/health",
        "interval": 60,
    },
    {
        "name":     "Immich",
        "type":     MonitorType.HTTP,
        # /api/server/ping is the stable health endpoint in current Immich
        "url":      "http://immich-server:2283/api/server/ping",
        "interval": 60,
    },
    # ── Music stack ──────────────────────────────────────────────────────────
    {
        "name":     "Navidrome",
        "type":     MonitorType.HTTP,
        "url":      "http://navidrome:4533/ping",
        "interval": 60,
    },
    {
        "name":     "Feishin",
        "type":     MonitorType.HTTP,
        "url":      "http://feishin:9180",
        "interval": 60,
    },
    {
        "name":     "Listenarr",
        "type":     MonitorType.HTTP,
        "url":      "http://listenarr:4545",
        "interval": 120,
    },
    # ── Cloud/personal stack ─────────────────────────────────────────────────
    {
        "name":     "Audiobookshelf",
        "type":     MonitorType.HTTP,
        "url":      "http://audiobookshelf:80",
        "interval": 60,
    },
    {
        "name":     "Yamtrack",
        "type":     MonitorType.HTTP,
        "url":      "http://yamtrack:8000",
        "interval": 60,
    },
    {
        "name":     "CrossWatch",
        "type":     MonitorType.HTTP,
        "url":      "http://crosswatch:8787",
        "interval": 60,
    },
    {
        "name":     "Forgejo",
        "type":     MonitorType.HTTP,
        "url":      "http://forgejo:3000",
        "interval": 60,
    },
    {
        "name":     "Komga",
        "type":     MonitorType.HTTP,
        "url":      "http://komga:25600",
        "interval": 60,
    },
    {
        "name":     "Calibre-Web",
        "type":     MonitorType.HTTP,
        "url":      "http://calibre-web:8083",
        "interval": 60,
    },
    # ── Documents stack ──────────────────────────────────────────────────────
    {
        "name":     "Paperless-NGX",
        "type":     MonitorType.HTTP,
        "url":      "http://paperless-ngx:8000",
        "interval": 60,
    },
    {
        "name":     "Stirling PDF",
        "type":     MonitorType.HTTP,
        "url":      "http://stirling-pdf:8080/api/v1/info/status",
        "interval": 60,
    },
    {
        "name":     "Kiwix",
        "type":     MonitorType.HTTP,
        "url":      "http://kiwix:8080",
        "interval": 120,
    },
    # ── Tools stack ──────────────────────────────────────────────────────────
    {
        "name":     "Draw.io",
        "type":     MonitorType.HTTP,
        "url":      "http://drawio:8080",
        "interval": 120,
    },
    {
        "name":     "Excalidraw",
        "type":     MonitorType.HTTP,
        "url":      "http://excalidraw:80",
        "interval": 120,
    },
    {
        "name":     "IT-Tools",
        "type":     MonitorType.HTTP,
        "url":      "http://it-tools:80",
        "interval": 120,
    },
    {
        "name":     "Vaultwarden",
        "type":     MonitorType.HTTP,
        "url":      "http://vaultwarden:80/alive",
        "interval": 60,
    },
    {
        "name":     "Actual Budget",
        "type":     MonitorType.HTTP,
        "url":      "http://actual-budget:5006",
        "interval": 120,
    },
    {
        "name":     "Joplin Server",
        "type":     MonitorType.HTTP,
        "url":      "http://joplin:22300",
        "interval": 60,
    },
    # ── Personal stack ───────────────────────────────────────────────────────
    {
        "name":     "Mealie",
        "type":     MonitorType.HTTP,
        "url":      "http://mealie:9000/api/app/about",
        "interval": 60,
    },
    {
        "name":     "Wizarr",
        "type":     MonitorType.HTTP,
        "url":      "http://wizarr:5690",
        "interval": 60,
    },
    {
        "name":     "Youtarr",
        "type":     MonitorType.HTTP,
        "url":      "http://youtarr:3011",
        "interval": 60,
    },
    # ── Home stack ───────────────────────────────────────────────────────────
    {
        "name":     "Home Assistant",
        "type":     MonitorType.HTTP,
        "url":      "http://home-assistant:8123",
        "interval": 60,
    },
    # ── Monitoring stack ─────────────────────────────────────────────────────
    {
        "name":     "Grafana",
        "type":     MonitorType.HTTP,
        "url":      "http://grafana:3000",
        "interval": 60,
    },
    {
        "name":     "Prometheus",
        "type":     MonitorType.HTTP,
        "url":      "http://prometheus:9090/-/healthy",
        "interval": 60,
    },
    {
        "name":     "Scrutiny",
        "type":     MonitorType.HTTP,
        "url":      "http://scrutiny:8080/api/health",
        "interval": 300,
    },
    # ── External monitors (Cloudflare tunnel — actual Caddyfile domains) ──────
    # These verify the full chain: internet → Cloudflare → cloudflared → Caddy → service
    {
        "name":     "Authelia (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://auth.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Jellyfin (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://jellyfin.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Seerr (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://seerr.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Audiobookshelf (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://abs.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Navidrome (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://music.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Immich (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://immich.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Vaultwarden (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://vault.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Forgejo (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://git.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Wizarr (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://join.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Homepage (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://homepage.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Yamtrack (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://yamtrack.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Feishin (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://feishin.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Actual Budget (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://actual-budget.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Joplin (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://joplin.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Paperless (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://paperless.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Mealie (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://mealie.andreasmaita.com",
        "interval": 120,
    },
]

def monitor_key(m):
    """Return a comparable dict of the fields we care about for drift detection."""
    if m.get("type") in (MonitorType.PORT,):
        return {"type": m["type"], "hostname": m.get("hostname"), "port": m.get("port")}
    return {"type": m["type"], "url": m.get("url")}

# Monitors to delete if they still exist (services that have been removed or renamed)
DELETE_MONITORS = [
    "spotDL", "SpotDL", "Ryot", "Ryot (external)",
    "Soulseek (slskd)", "Paperless-GPT", "Code Server", "LibreOffice",
    "MeshCentral", "LubeLogger", "Monica", "World Monitor", "RomM",
    "Readarr", "LazyLibrarian",
    # External monitors with old/wrong URLs — deleted first, then re-created with correct URLs above
    "Feishin (external)", "Yamtrack (external)", "CrossWatch (external)",
    "Paperless-NGX (external)", "Joplin (external)", "Mealie (external)",
]

api = UptimeKumaApi("http://uptime-kuma:3001")
api.timeout = 60
api.wait_events = 1.0
try:
    api.login(os.environ["UPTIMEKUMA_USER"], os.environ["UPTIMEKUMA_PASS"])
    existing = {m["name"]: m for m in api.get_monitors()}
    added = updated = skipped = 0
    # Remove stale monitors first
    for name in DELETE_MONITORS:
        if name in existing:
            api.delete_monitor(existing[name]["id"])
            print(f"  DELETED:       {name}")
            del existing[name]
    for m in MONITORS:
        if m["name"] in existing:
            ex = existing[m["name"]]
            # Detect type/url drift so re-runs fix misconfigured monitors
            desired_type_val = m["type"].value if hasattr(m["type"], "value") else m["type"]
            if ex.get("type") != desired_type_val or ex.get("url") != m.get("url") or ex.get("hostname") != m.get("hostname"):
                api.edit_monitor(ex["id"], **m)
                print(f"  UPDATED:       {m['name']}")
                updated += 1
            else:
                print(f"  SKIP (ok):     {m['name']}")
                skipped += 1
        else:
            api.add_monitor(**m)
            print(f"  ADDED:         {m['name']}")
            added += 1
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
finally:
    api.disconnect()
PYEOF

echo "Running Uptime Kuma setup against http://uptime-kuma:3001 ..."
docker run --rm \
    --network homelab_net \
    -e UPTIMEKUMA_USER="${UPTIMEKUMA_USER}" \
    -e UPTIMEKUMA_PASS="${UPTIMEKUMA_PASS}" \
    -v /tmp/kuma_setup.py:/kuma_setup.py:ro \
    python:3-alpine \
    sh -c "pip install --disable-pip-version-check --root-user-action=ignore --no-cache-dir uptime-kuma-api==1.2.1 >/dev/null 2>&1 && python3 /kuma_setup.py"
