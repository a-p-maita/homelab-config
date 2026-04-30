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
    # ── Internal monitors (container DNS on homelab_net) ─────────────────────
    {
        "name":     "Audiobookshelf",
        "type":     MonitorType.HTTP,
        "url":      "http://audiobookshelf:80",
        "interval": 60,
    },
    {
        "name":     "Immich",
        "type":     MonitorType.HTTP,
        # /api/server/ping is the stable health endpoint in current Immich
        "url":      "http://immich-server:2283/api/server/ping",
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
        "name":     "qBittorrent",
        "type":     MonitorType.HTTP,
        "url":      "http://qbittorrent:20050",
        "interval": 60,
    },
    {
        "name":     "Audiobookbay Downloader",
        "type":     MonitorType.HTTP,
        "url":      "http://audiobookbay-downloader:9000",
        "interval": 60,
    },
    {
        # Jackett /health returns 200; root path redirects 301→302 and fails HTTP monitors.
        "name":     "Jackett",
        "type":     MonitorType.HTTP,
        "url":      "http://jackett:9117/health",
        "interval": 60,
    },
    {
        "name":     "Forgejo",
        "type":     MonitorType.HTTP,
        "url":      "http://forgejo:3000",
        "interval": 60,
    },
    {
        "name":     "Homepage",
        "type":     MonitorType.HTTP,
        "url":      "http://homepage:3000",
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
        "name":     "Lidarr",
        "type":     MonitorType.HTTP,
        "url":      "http://lidarr:8686/ping",
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
        "name":     "LazyLibrarian",
        "type":     MonitorType.HTTP,
        "url":      "http://lazylibrarian:5299",
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
        "name":     "Octo-Fiesta",
        "type":     MonitorType.HTTP,
        # Root path returns {"ok":true} with 200 — confirmed health endpoint
        "url":      "http://octo-fiesta:8080/",
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
    # ── Entertainment stack ──────────────────────────────────────────────────
    {
        "name":     "Jellyfin",
        "type":     MonitorType.HTTP,
        "url":      "http://jellyfin:8096/health",
        "interval": 60,
    },    {
        "name":     "Seerr",
        "type":     MonitorType.HTTP,
        "url":      "http://seerr:5055/api/v1/settings/public",
        "interval": 60,
    },    # ── Home stack ───────────────────────────────────────────────────────────
    {
        "name":     "Home Assistant",
        "type":     MonitorType.HTTP,
        "url":      "http://home-assistant:8123",
        "interval": 60,
    },
    # ── External monitors (Cloudflare tunnel domains) ─────────────────────────
    {
        "name":     "Audiobookshelf (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://audiobookshelf.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Navidrome (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://navidrome.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Feishin (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://feishin.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Immich (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://immich.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Yamtrack (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://yamtrack.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "CrossWatch (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://crosswatch.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Forgejo (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://forgejo.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Homepage (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://homepage.andreasmaita.com",
        "interval": 120,
    },
    # ── New service external monitors (add Cloudflare tunnels for these) ──────
    {
        "name":     "Paperless-NGX (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://paperless.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Vaultwarden (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://vault.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Jellyfin (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://jellyfin.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Joplin (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://joplin.andreasmaita.com",
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

# Monitors to delete if they still exist (services that have been removed)
DELETE_MONITORS = [
    "spotDL", "SpotDL", "Ryot", "Ryot (external)",
    "Soulseek (slskd)", "Paperless-GPT", "Code Server", "LibreOffice",
    "MeshCentral", "LubeLogger", "Monica", "World Monitor", "RomM",
    "Readarr",
]

api = UptimeKumaApi("http://uptime-kuma:3001")
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
    sh -c "pip install uptime-kuma-api -q && python3 /kuma_setup.py"
