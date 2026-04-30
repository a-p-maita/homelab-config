#!/bin/sh
# Called by Gluetun via VPN_PORT_FORWARDING_UP_COMMAND when the forwarded port changes.
# qBittorrent shares gluetun's network namespace → localhost works for the API call.
#
# PREREQUISITE: qBittorrent → Tools → Options → Web UI →
#               ☑ "Bypass authentication for clients on localhost"
#               This is safe: only processes in gluetun's namespace have localhost access.

PORT=$(cat /tmp/gluetun/forwarded_port 2>/dev/null | tr -d '[:space:]')
if [ -z "$PORT" ] || [ "$PORT" = "0" ]; then
  echo "[port-sync] No valid forwarded port in status file, skipping"
  exit 0
fi

echo "[port-sync] ProtonVPN forwarded port: $PORT — updating qBittorrent listen port"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "http://localhost:${QBITTORRENT_WEBUI_PORT}/api/v2/app/setPreferences" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "json={\"listen_port\":${PORT}}")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "[port-sync] Success — qBittorrent now listens on port $PORT"
else
  echo "[port-sync] Failed (HTTP $HTTP_STATUS)"
  echo "[port-sync] Ensure 'Bypass auth for localhost' is enabled in qBittorrent Web UI settings"
  exit 1
fi
