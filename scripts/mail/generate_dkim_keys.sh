#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DKIM_DIR="$ROOT/backups/secrets/mail/dkim"
mkdir -p "$DKIM_DIR"

SELECTOR="${1:-mail}"
DOMAIN="${2:-andreasmaita.com}"
PRIVATE="$DKIM_DIR/${SELECTOR}.private"
PUB="$DKIM_DIR/${SELECTOR}.pub"

if [ -f "$PRIVATE" ] || [ -f "$PUB" ]; then
  echo "DKIM keys already exist at $DKIM_DIR/$SELECTOR.*"
  exit 1
fi

openssl genrsa -out "$PRIVATE" 2048
openssl rsa -in "$PRIVATE" -pubout -out "$PUB"

echo "DKIM keys generated."
echo
echo "DNS TXT record for selector ${SELECTOR} (name):"
echo "${SELECTOR}._domainkey.${DOMAIN}"
echo
echo "Value:"
echo -n "v=DKIM1; k=rsa; p="
sed -n '2,$p' "$PUB" | sed -e '$d' | tr -d '\n' | sed 's/ //g'
echo

echo
echo "Private key: $PRIVATE"
echo "Public key: $PUB"

echo
echo "NOTE: Add the above TXT record to your DNS provider. Keep the private key"
echo "secure and mount it into your mailserver per its documentation."
