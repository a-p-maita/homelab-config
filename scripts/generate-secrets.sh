#!/usr/bin/env bash
set -euo pipefail

# Simple generator to create a working `.env` from `.env.example` by filling
# in secret-like keys. This is intentionally conservative: it only generates
# values for blank entries whose key name contains secret-like words.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLE="$ROOT/.env.example"
OUT="$ROOT/.env"

if [ -f "$OUT" ]; then
  echo ".env already exists at $OUT; not overwriting. Remove it first to regenerate."
  exit 0
fi

if [ ! -f "$EXAMPLE" ]; then
  echo ".env.example not found at $EXAMPLE" >&2
  exit 1
fi

cp "$EXAMPLE" "$OUT"
export OUTFILE="$OUT"

python3 - <<'PY'
import os, re, secrets
fn = os.environ['OUTFILE']
text = open(fn, 'r', encoding='utf-8').read()
lines = text.splitlines()
out_lines = []
key_re = re.compile(r'^([A-Za-z0-9_]+)=(.*)$')
secret_word = re.compile(r'PASS|PASSWORD|SECRET|TOKEN|KEY|JWT|API|S3|ENCRYPT|PRIVATE', re.I)
for line in lines:
    m = key_re.match(line)
    if m:
        k, v = m.group(1), m.group(2)
        if v.strip() == '':
            if secret_word.search(k):
                new = secrets.token_urlsafe(32)
                out_lines.append(f'{k}={new}')
                continue
    out_lines.append(line)
open(fn, 'w', encoding='utf-8').write('\n'.join(out_lines))
print(f'Wrote {fn}')
PY

echo ".env generated from .env.example — review before use."
