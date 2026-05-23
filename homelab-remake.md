# Homelab Remake — Agentic Execution Plan

> **[META] AGENT INSTRUCTIONS:**
>
> - Execute stage-by-stage. Do not advance until the current stage is verified.
> - Prefer live Docker state, Caddy autosave, and compose config over stale documentation.
> - Keep the plan deterministic and explicit. Use exact commands, one change at a time.
> - Treat `config/caddy/caddy/autosave.json` as the source of truth for public hostnames.

---

## How to use this plan

- Work in passes: inspect current state, apply one focused change, then verify.
- Use `docker compose config`, `docker ps`, `docker inspect`, `docker exec`, `docker network inspect`, and Caddy autosave data.
- Keep stack changes isolated to one directory or one architecture concern.
- Update the `Live Recovery Status` checklist after every verification.
- Do not remove `homelab_net` until the new internal network architecture passes validation.

---

## Live Caddy route baseline

The live Caddy config in `config/caddy/caddy/autosave.json` currently advertises these hostnames:

- `abs.andreasmaita.com`
- `actual-budget.andreasmaita.com`
- `auth.andreasmaita.com`
- `feishin.andreasmaita.com`
- `git.andreasmaita.com`
- `home.andreasmaita.com`
- `homepage.andreasmaita.com`
- `immich.andreasmaita.com`
- `jellyfin.andreasmaita.com`
- `join.andreasmaita.com`
- `joplin.andreasmaita.com`
- `mealie.andreasmaita.com`
- `music.andreasmaita.com`
- `octo-fiesta.andreasmaita.com`
- `paperless.andreasmaita.com`
- `seerr.andreasmaita.com`
- `vault.andreasmaita.com`
- `yamtrack.andreasmaita.com`

### Important reconciliation notes

- `nextcloud.andreasmaita.com` is defined in `stacks/cloud/compose.override.yaml` but is not present in the live Caddy route list.
- `octo-fiesta.andreasmaita.com` is present in live Caddy, but no active `octo-fiesta` container appears in current Docker state. Treat this as a stale legacy route.
- `join.andreasmaita.com` is live and maps to the running `wizarr` container.

---

## Stage 0: Emergency recovery

**Objective:** Stabilize running containers and confirm the edge stack is healthy.

Steps:

1. Identify unhealthy or stopped containers:

   ```bash
   docker ps --filter 'health=unhealthy' --format 'table {{.Names}} {{.Status}} {{.Image}}'
   docker ps --filter 'status=exited' --format 'table {{.Names}} {{.Status}} {{.Image}}'
   ```

2. Repair immediate failures and restart affected containers.
   - Example: fix Nextcloud config, missing volume mounts, broken secrets, or invalid YAML.

3. Validate edge services:

   ```bash
   docker exec caddy cat /config/caddy/autosave.json | python3 -c 'import json,sys; data=json.load(sys.stdin); print(sorted({h for r in data["apps"]["http"]["servers"]["srv0"]["routes"] for m in r.get("match",[]) for h in m.get("host",[])}))'
   docker exec caddy sh -lc 'wget -qO- http://docker-socket-proxy:2375/_ping'
   docker exec homepage sh -c 'wget -qO- http://localhost:3000/api/services | head -n 3'
   ```

Verification:

- `caddy`, `authelia`, `cloudflared`, `homepage`, and `docker-socket-proxy` are healthy.
- live Caddy hostlist is readable from `autosave.json`.
- protected routes return `401 Unauthorized` when Authelia is engaged.

---

## Stage 1: Inventory and baseline validation

**Objective:** Confirm that the current repo state matches the running homelab.

Steps:

1. Validate `.env` loads without parse errors:

   ```bash
   set -o allexport; source .env; set +o allexport
   ```

2. Confirm stack compose definitions are syntactically valid:

   ```bash
   docker compose -f stacks/infrastructure/compose.yaml config >/dev/null
   docker compose -f stacks/cloud/compose.yaml -f stacks/cloud/compose.override.yaml config >/dev/null
   docker compose -f stacks/services/compose.yaml config >/dev/null
   docker compose -f stacks/media/compose.yaml config >/dev/null
   docker compose -f stacks/arr/compose.yaml config >/dev/null
   docker compose -f stacks/home/compose.yaml config >/dev/null
   ```

3. Record the current network and socket topology:

   ```bash
   docker network ls | grep -E 'proxy_net|socket_internal|infrastructure_internal|cloud_internal|services_internal|homelab_net'
   docker network inspect socket_internal | jq '.Containers | keys'
   ```

4. Confirm stack directories exist:
   - `stacks/infrastructure`
   - `stacks/monitoring`
   - `stacks/arr`
   - `stacks/media`
   - `stacks/cloud`
   - `stacks/services`
   - `stacks/home`

Verification:

- `.env` loads cleanly.
- `docker compose config` passes for all active stacks.
- networks exist and only expected services are attached to `socket_internal`.
- stale env variables for deprecated services are identified.

---

## Stage 2: Secure edge and auth networking

**Objective:** Verify Caddy label discovery, Docker socket isolation, and Authelia forward-auth.

Steps:

1. Verify `caddy` is the docker-proxy image and uses socket proxy:

   ```bash
   docker inspect caddy --format '{{.Config.Image}} {{range .Config.Env}}{{println .}}{{end}}' | grep -E 'caddy-docker-proxy|DOCKER_HOST'
   ```

2. Verify `docker-socket-proxy` is attached only to `socket_internal` and exposes the expected subset:

   ```bash
   docker inspect docker-socket-proxy --format '{{json .HostConfig.Binds}}'
   docker exec docker-socket-proxy env | grep NETWORKS
   ```

3. Validate Authelia label import and policy:

   ```bash
   docker exec authelia sh -lc 'grep -E "AUTHELIA_SESSION_SECRET|AUTHELIA_STORAGE_ENCRYPTION_KEY" /proc/self/environ || true'
   docker exec caddy cat /config/caddy/autosave.json | python3 -c 'import json,sys; data=json.load(sys.stdin); print([r for r in data["apps"]["http"]["servers"]["srv0"]["routes"] if any("auth.andreasmaita.com" in str(m.get("host",[])) for m in r.get("match",[]))])'
   ```

4. Check sample protected and public host behavior:

   ```bash
   curl -I -H 'Host: auth.andreasmaita.com' http://127.0.0.1:80
   curl -I -H 'Host: jellyfin.andreasmaita.com' http://127.0.0.1:80
   curl -I -H 'Host: nextcloud.andreasmaita.com' http://127.0.0.1:80 || true
   ```

Verification:

- Caddy uses `DOCKER_HOST=tcp://docker-socket-proxy:2375`.
- `docker-socket-proxy` only has socket access for audited services.
- Authelia route snippet is imported and protecting hosts as expected.
- Missing or stale Caddy hosts are documented.

---

## Stage 3: Route reconciliation and homepage alignment

**Objective:** Align public routing, homepage discovery, and repo labels.

Steps:

1. Compare live Caddy hostnames to compose label definitions:

   ```bash
   docker compose -f stacks/cloud/compose.yaml -f stacks/cloud/compose.override.yaml config | grep 'caddy=' || true
   docker compose -f stacks/services/compose.yaml config | grep 'caddy=' || true
   docker compose -f stacks/media/compose.yaml config | grep 'caddy=' || true
   docker compose -f stacks/home/compose.yaml config | grep 'caddy=' || true
   ```

2. Identify mismatch cases:
   - `nextcloud.andreasmaita.com` should exist in live Caddy but does not.
   - `octo-fiesta.andreasmaita.com` exists in live Caddy but no running container is present.

3. Repair routing sources:
   - If a stale route exists in a legacy Caddy file, remove it.
   - If a current container has correct labels, restart that service and let Caddy re-read labels.
   - If `nextcloud` labels are present but route is absent, restart `caddy` and confirm the route appears.

4. Confirm homepage discovery is consistent:
   - `Homepage` should use Docker labels wherever possible.
   - If `config/homepage/services.yaml` is still required, keep only active, reachable entries.

Verification:

- `nextcloud.andreasmaita.com` is either intentionally absent or restored consistently to labels.
- `octo-fiesta.andreasmaita.com` is removed if stale; `OCTOFIESTA_*` env vars are cleaned.
- `config/homepage/services.yaml` and live Caddy hostnames agree on active public services.
- `join.andreasmaita.com` mapping is confirmed with `wizarr` if still needed.

---

## Stage 4: Application stack validation

**Objective:** Start and verify application stacks behind the edge.

Steps:

1. Bring up the ordered stacks:
   - `stacks/infrastructure`
   - `stacks/monitoring`
   - `stacks/cloud`
   - `stacks/services`
   - `stacks/media`
   - `stacks/arr`
   - `stacks/home`

2. Validate each stack by service health checks and label discovery.

3. Verify databases and caches use only internal networks:
   - `cloud_internal`
   - `services_internal`
   - `media_internal`
   - `arr_internal`

4. Confirm rich services are reachable via the expected hostnames or local tunnels.

Verification:

- All expected containers are `Up` and `healthy`.
- No database service exposes host-facing ports unnecessarily.
- Public hostnames route to the right upstream services.

---

## Stage 5: Cleanup, audit, and stabilization

**Objective:** Retire stale config, align docs, and lock down the final state.

Steps:

1. Remove stale route state and obsolete env settings:
   - `OCTOFIESTA_*` lines if the service is no longer active.
   - Legacy Caddy static config that duplicates label-driven routing.

2. Re-run full composition checks:

   ```bash
   docker compose -f stacks/infrastructure/compose.yaml config >/dev/null
   docker compose -f stacks/cloud/compose.yaml -f stacks/cloud/compose.override.yaml config >/dev/null
   docker compose -f stacks/services/compose.yaml config >/dev/null
   docker compose -f stacks/media/compose.yaml config >/dev/null
   docker compose -f stacks/arr/compose.yaml config >/dev/null
   docker compose -f stacks/home/compose.yaml config >/dev/null
   ```

3. Confirm the live Caddy route list matches the desired public service set after cleanup.
4. Mark the plan checklist complete only when route labels, env state, and homepage entries are consistent.

Verification:

- `docker compose config` passes for all stacks.
- `config/caddy/caddy/autosave.json` reflects only intended services.
- `.env` contains no stale `OCTOFIESTA_*` settings.
- `config/homepage/services.yaml` is not fighting the live route state.

---

## Live Recovery Status

- [ ] `docker compose config` passes for all active stacks.
- [ ] `caddy` is using `docker-socket-proxy` and labels are discovered correctly.
- [ ] Authelia forward-auth is applied on protected hostnames.
- [ ] `nextcloud.andreasmaita.com` route is either intentionally absent or restored.
- [ ] `octo-fiesta.andreasmaita.com` stale route is removed from Caddy and `.env`.
- [ ] Caddy recoverable hostnames are aligned with repo labels.
- [ ] Homepage service discovery and live routes agree.
- [ ] `homelab_net` remains in place until internal isolation is validated.

---

## Known corrections

1. Use live Caddy autosave as the authoritative public route source.
2. Do not assume `nextcloud` is exposed through Caddy unless the live route is present.
3. Treat `octo-fiesta` as a legacy route until its container and stack are verified.
4. Keep `homelab_net` in place until the internal network migration is fully validated.
5. Prefer label-driven routing over legacy static `Caddyfile` entries.
