#!/usr/bin/env bash
set -euo pipefail

# Prepare an env migration plan (non-destructive).
# - Backs up .env
# - Runs the analyzer to refresh the report
# - Generates backups/env-migration-commands.sh with suggested manual commands
# REVIEW the generated commands before running anything that modifies your host.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
BACKUPS_DIR="$ROOT/backups"
TIMESTAMP="$(date +%F_%H%M%S)"
REPORT="$BACKUPS_DIR/env-analysis-report.txt"
OUT_CMDS="$BACKUPS_DIR/env-migration-commands.sh"

mkdir -p "$BACKUPS_DIR"
if [ ! -f "$ENV_FILE" ]; then
  echo "No .env file found at $ENV_FILE"
  exit 1
fi

echo "Backing up .env to $BACKUPS_DIR/.env.bak.$TIMESTAMP"
cp "$ENV_FILE" "$BACKUPS_DIR/.env.bak.$TIMESTAMP"

echo "Running analyzer to refresh $REPORT"
python3 "$ROOT/scripts/analyze_env.py"

if [ ! -f "$REPORT" ]; then
  echo "Analyzer did not produce report at $REPORT" >&2
  exit 1
fi

echo "Creating migration commands file: $OUT_CMDS"
cat > "$OUT_CMDS" <<'EOF'
#!/usr/bin/env bash
# Generated migration commands (non-destructive templates).
# Review & edit this file. It contains suggested commands to generate new
# secrets and create Docker secrets or update .env in-place.

set -euo pipefail

echo "This file contains templates only. Do NOT run blindly. Edit and run selectively."

EOF

# Parse reused entries from the analyzer report (lines like: ' - sha256:... used by: A, B, C')
# Use a robust grep (no -n) and tolerate no-matches without failing the script.
mapfile -t REUSED_LINES < <(grep -E "sha256:[0-9a-f]+ used by:" "$REPORT" || true)
for line in "${REUSED_LINES[@]}"; do
  # remove leading bullet and whitespace (e.g. ' - sha256:...')
  entry=$(printf "%s" "$line" | sed -E 's/^[[:space:]]*-+[[:space:]]*//')
  # split on ' used by:'
  hash=$(printf "%s" "$entry" | awk '{print $1}')
  vars=$(printf "%s" "$entry" | sed -E 's/^sha256:[0-9a-f]+ used by: //')
  # normalize vars (comma-separated)
  IFS=',' read -ra VARR <<< "$vars"
  # Trim whitespace
  for i in "${!VARR[@]}"; do
    VARR[$i]=$(echo "${VARR[$i]}" | sed -E 's/^ +| +$//g')
  done

  # Heuristic: only suggest rotation for keys that look secret-y
  secrety=false
  for v in "${VARR[@]}"; do
    up=$(echo "$v" | tr '[:lower:]' '[:upper:]')
    if echo "$up" | grep -E "PASS|PASSWORD|SECRET|TOKEN|KEY|JWT|S3|DB" >/dev/null; then
      secrety=true
      break
    fi
  done

  if [ "$secrety" = true ]; then
    cat >> "$OUT_CMDS" <<EOF

# ===== Group: $hash =====
# Variables: ${VARR[*]}
# Suggested manual steps:
# 1) Generate a new secret:
#    openssl rand -base64 32
#    or: python3 -c "import secrets; print(secrets.token_urlsafe(32))"
# 2) (Preferred) Create a Docker secret and update Compose to use _FILE semantics:
#    echo -n "<NEWSECRET>" | docker secret create <service>_secret -
#    Then update compose to use the _FILE path: /run/secrets/<service>_secret
# 3) (Quick) Update .env in-place (manual, not recommended for long-term):
#    sed -i "s|^MYVAR=.*|MYVAR='NEWSECRET'|" .env

EOF
  fi
done

chmod +x "$OUT_CMDS"
echo "Wrote $OUT_CMDS — review it before executing any commands."
echo "Backup of original .env: $BACKUPS_DIR/.env.bak.$TIMESTAMP"
echo "Analyzer report: $REPORT"

echo "Done. Next: review $OUT_CMDS and run commands selectively after manual verification."
