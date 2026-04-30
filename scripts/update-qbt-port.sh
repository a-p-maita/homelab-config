#!/bin/sh
# Called by Gluetun via VPN_PORT_FORWARDING_UP_COMMAND when the forwarded port changes.
# qBittorrent shares gluetun's network namespace → localhost works for the API call.
#
# PREREQUISITE: qBittorrent → Tools → Options → Web UI →
#               ☑ "Bypass authentication for clients on localhost"
#               This is safe: only processes in gluetun's namespace have localhost access.

# gluetun sets $FORWARDED_PORT env var when calling this command.
# Fall back to the status file in case the env var isn't set (e.g. manual invocation).
PORT="${FORWARDED_PORT:-$(cat /tmp/gluetun/forwarded_port 2>/dev/null | tr -d '[:space:]')}"
if [ -z "$PORT" ] || [ "$PORT" = "0" ]; then
  echo "[port-sync] No valid forwarded port available yet (VPN still connecting), skipping"
  exit 0
fi

echo "[port-sync] ProtonVPN forwarded port: $PORT"

# gluetun runs this command as soon as the VPN port is established, which happens
# during gluetun's own startup — before qBittorrent has launched (qBittorrent
# depends_on: gluetun healthy). Retry until qBittorrent's WebUI is reachable.
MAX_WAIT=180
WAITED=0
until wget -q -O /dev/null "http://localhost:${QBITTORRENT_WEBUI_PORT}/api/v2/app/version" 2>/dev/null; do
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "[port-sync] qBittorrent WebUI not reachable after ${MAX_WAIT}s — giving up"
    exit 1
  fi
  echo "[port-sync] Waiting for qBittorrent WebUI... (${WAITED}s elapsed)"
  sleep 5
  WAITED=$((WAITED + 5))
done

echo "[port-sync] qBittorrent is up — applying listen port $PORT"

# gluetun's Alpine image has wget (busybox), not curl.
# wget exits 0 on HTTP 200, non-zero on 4xx/5xx.
if wget -q -O /dev/null \
  --post-data "json={\"listen_port\":${PORT}}" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  "http://localhost:${QBITTORRENT_WEBUI_PORT}/api/v2/app/setPreferences"; then
  echo "[port-sync] Success — qBittorrent now listens on port $PORT"
else
  echo "[port-sync] setPreferences call failed"
  echo "[port-sync] Ensure 'Bypass auth for localhost' is enabled in qBittorrent Web UI settings"
  exit 1
fi

# Force all torrents to re-announce with the new port so trackers update their peer lists.
# Without this, peers won't discover this seeder until the next regular announce interval
# (which can be 30+ minutes), causing the torrent to sit in stalledUP with no peers.
wget -q -O /dev/null \
  --post-data "hashes=all" \
  "http://localhost:${QBITTORRENT_WEBUI_PORT}/api/v2/torrents/reannounce" \
  && echo "[port-sync] Re-announced all torrents with new port $PORT" \
  || echo "[port-sync] Re-announce failed (non-fatal — will retry at next tracker interval)"
