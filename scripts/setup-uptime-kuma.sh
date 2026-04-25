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

UK_USER="a-p-maita"
UK_PASS="UK_PASS"

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
        "name":     "Ryot",
        "type":     MonitorType.HTTP,
        "url":      "http://ryot:8000/health",
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
    # ── External monitors (Cloudflare tunnel domains) ─────────────────────────
    {
        "name":     "Audiobookshelf (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://audiobookshelf.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Immich (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://immich.andreasmaita.com",
        "interval": 120,
    },
    {
        "name":     "Ryot (external)",
        "type":     MonitorType.HTTP,
        "url":      "https://ryot.andreasmaita.com",
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
]

def monitor_key(m):
    """Return a comparable dict of the fields we care about for drift detection."""
    if m.get("type") in (MonitorType.PORT,):
        return {"type": m["type"], "hostname": m.get("hostname"), "port": m.get("port")}
    return {"type": m["type"], "url": m.get("url")}

api = UptimeKumaApi("http://uptime-kuma:3001")
try:
    api.login(os.environ["UK_USER"], os.environ["UK_PASS"])
    existing = {m["name"]: m for m in api.get_monitors()}
    added = updated = skipped = 0
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
    print(f"\nDone — {added} added, {updated} updated, {skipped} skipped.")
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
finally:
    api.disconnect()
PYEOF

echo "Running Uptime Kuma setup against http://uptime-kuma:3001 ..."
docker run --rm \
    --network homelab_net \
    -e UK_USER="${UK_USER}" \
    -e UK_PASS="${UK_PASS}" \
    -v /tmp/kuma_setup.py:/kuma_setup.py:ro \
    python:3-alpine \
    sh -c "pip install uptime-kuma-api -q && python3 /kuma_setup.py"
