#!/usr/bin/env zsh
set -uo pipefail
repo_root="/home/$(whoami)/homelab-config"
stacks_root="$repo_root/stacks"

if [[ ! -d "$stacks_root" ]]; then
  echo "Stacks directory not found: $stacks_root" >&2
  exit 1
fi

while IFS= read -r compose_dir; do
  [[ -n "$compose_dir" ]] || continue

  if [[ "$compose_dir" =~ (^|/)(stack-example|service-example|example|[^/]+-example|example-[^/]+)$ ]]; then
    echo "Skipping example stack: $compose_dir"
    continue
  fi

  echo "---> Updating compose stack in $compose_dir"
  (
    cd "$compose_dir"

    if ! docker compose pull; then
      echo "pull failed for $compose_dir" >&2
      exit 0
    fi

    if ! (docker compose down && docker compose up -d); then
      echo "restart failed for $compose_dir" >&2
    fi
  )
done < <(find "$stacks_root" -type f \( -name 'compose.yaml' -o -name 'compose.yml' \) -print | xargs -r dirname | sort -u)
