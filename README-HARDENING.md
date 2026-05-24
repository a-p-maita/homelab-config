# Hardening Suggestions & Usage

This document explains the non-destructive tooling added to help harden Docker Compose stacks.

Files added:

- `scripts/harden_compose.py` — scans the repository for Compose YAML files and produces a human-readable
  suggestions report and per-file `hardening-snippets` under `backups/`.

How to use:

1. Install dependencies (optional but recommended):

```bash
python3 -m pip install pyyaml
```

1. Run the script (it will not modify any files):

```bash
python3 scripts/harden_compose.py --output backups/compose-hardening-suggestions.txt
```

1. Review `backups/compose-hardening-suggestions.txt` and the `backups/hardening-snippets/` files.

2. Apply changes manually or with your preferred YAML editor. The snippets are intentionally conservative.

Notes & recommendations:

- The script is conservative and intended for review-first workflows. It will not change your compose files.
- For automatic edits, use `yq` or a scripted apply step, but only after you have taken backups and tested the changes.
- Typical hardening actions to perform manually:
  - Pin images to tags or digests (avoid `:latest`).
  - Add `healthcheck` blocks to important services (Traefik, DBs, Authelia, Homepage).
  - Add resource limits (`mem_limit`, `cpus`) and `restart: unless-stopped`.
  - Mark stateful services as `com.centurylinklabs.watchtower.enable=false` if using Watchtower.

If you'd like, I can run the script now (read-only) and add the generated suggestions to the repo. Reply "Run hardening scan" to proceed.
