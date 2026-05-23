# Homelab Remake — Agentic Execution Plan

> **[META] AGENT INSTRUCTIONS:**
>
> - Execute stage-by-stage. Do not advance until the current stage is verified.
> - Prefer live Docker state, Caddy autosave, and compose config over stale documentation.
> - Keep the plan deterministic and explicit. Use exact commands, one change at a time.
> - Treat the `caddy` container's live `/config/caddy/autosave.json` as the source of truth for public hostnames.

---

## How to use this plan

- Work in passes: inspect current state, apply one focused change, then verify.
- Use `docker compose config`, `docker ps`, `docker inspect`, `docker exec`, `docker network inspect`, and Caddy autosave data.
- Keep stack changes isolated to one directory or one architecture concern.
- Update the `Live Recovery Status` checklist after every verification.
- Do not remove `homelab_net` until the new internal network architecture passes validation.

## Actions completed so far

- Verified `docker compose config` for all active stack definitions, including the combined overlay command for `stacks/cloud/compose.yaml` + `stacks/cloud/compose.override.yaml`.
- Confirmed live `caddy` uses `DOCKER_HOST=tcp://docker-socket-proxy:2375`.
- Confirmed `nextcloud.andreasmaita.com` is present in live Caddy autosave and is a valid active host.
- Confirmed `dockge` is running and bound to the expected data and stack directories.
- Confirmed `forgejo` service is running; live Caddy currently exposes it as `git.andreasmaita.com` and homepage metadata has been updated accordingly.
- Confirmed `actual-budget` and `wizarr` are currently exposed by live Caddy at `actual-budget.andreasmaita.com` and `join.andreasmaita.com` respectively.
- Updated homepage metadata to match live hostnames and route aliases from Caddy: `git.andreasmaita.com`, `abs.andreasmaita.com`, `music.andreasmaita.com`, and `seerr.andreasmaita.com`.
- Added missing homepage entries for public routes currently present in live Caddy: `actual-budget.andreasmaita.com`, `join.andreasmaita.com`, and `octo-fiesta.andreasmaita.com`.
- Re-added live homepage alias `home.andreasmaita.com` to `HOMEPAGE_ALLOWED_HOSTS`.
- Identified and corrected stale homepage route references: `actual-budget.andreasmaita.com`, `join.andreasmaita.com`, `abs.andreasmaita.com`, `music.andreasmaita.com`, and `home.andreasmaita.com`.

---

## Live Caddy route baseline

The live Caddy config inside the `caddy` container is authoritative. Inspect it with:

```bash
docker exec caddy cat /config/caddy/autosave.json | python3 -c 'import json,sys; data=json.load(sys.stdin); print(sorted({h for r in data["apps"]["http"]["servers"]["srv0"]["routes"] for m in r.get("match",[]) for h in m.get("host",[])}))'
```

The currently active hostnames in the live `caddy` container are:

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

- The runtime authoritative source is `/config/caddy/autosave.json` inside the `caddy` container, not the repo copy under `config/caddy/caddy/autosave.json`.
- `audiobookshelf.andreasmaita.com` and `navidrome.andreasmaita.com` are not currently active in live Caddy; the current live aliases are `abs.andreasmaita.com` and `music.andreasmaita.com`.
- `forgejo.andreasmaita.com` is not currently active in live Caddy; the live host for the Forgejo service is `git.andreasmaita.com`.
- `actual-budget.andreasmaita.com`, `join.andreasmaita.com`, and `octo-fiesta.andreasmaita.com` are active in live Caddy and should be present on the homepage.
- `seer.andreasmaita.com` is a stale/incorrect alias; the live route is `seerr.andreasmaita.com`.
- `home.andreasmaita.com` is accepted by live Caddy alongside `homepage.andreasmaita.com`.
- `wizarr` is currently exposed at `join.andreasmaita.com`, so Homepage should include it as an external service.
- `nextcloud.andreasmaita.com` is present in live Caddy and should be treated as a valid route.

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
   docker compose -f stacks/cloud/compose.db.yaml config >/dev/null
   docker compose -f stacks/cloud/compose.yaml -f stacks/cloud/compose.override.yaml config >/dev/null
   docker compose -f stacks/services/compose.db.yaml config >/dev/null
   docker compose -f stacks/services/compose.yaml config >/dev/null
   docker compose -f stacks/media/compose.yaml config >/dev/null
   docker compose -f stacks/arr/compose.yaml config >/dev/null
   docker compose -f stacks/home/compose.yaml config >/dev/null
   docker compose -f stacks/monitoring/compose.yaml config >/dev/null
   ```

3. Record the current network and socket topology:

   ```bash
   docker network ls | grep -E 'proxy_net|socket_internal|infrastructure_internal|cloud_internal|services_internal|media_internal|immich_internal|homelab_net'
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

**Objective:** Align public routing, homepage discovery, and repo labels to the live Caddy state.

Steps:

1. Compare live Caddy hostnames to compose label definitions:

   ```bash
   docker compose -f stacks/cloud/compose.yaml -f stacks/cloud/compose.override.yaml config | grep 'caddy=' || true
   docker compose -f stacks/services/compose.yaml config | grep 'caddy=' || true
   docker compose -f stacks/media/compose.yaml config | grep 'caddy=' || true
   docker compose -f stacks/home/compose.yaml config | grep 'caddy=' || true
   ```

2. Identify current live mismatches:
   - `abs.andreasmaita.com` is the live alias for Audiobookshelf; `audiobookshelf.andreasmaita.com` is not currently active.
   - `music.andreasmaita.com` is the live alias for Navidrome; `navidrome.andreasmaita.com` is not currently active.
   - `git.andreasmaita.com` is the live host for Forgejo; `forgejo.andreasmaita.com` is not currently active.
   - `actual-budget.andreasmaita.com`, `join.andreasmaita.com`, and `octo-fiesta.andreasmaita.com` are active in live Caddy and should be represented on the homepage.
   - `home.andreasmaita.com` is accepted by live Caddy along with `homepage.andreasmaita.com` and should be treated as a valid public alias.

3. Repair routing sources:
   - If a service's repo labels are stale, update the compose labels or homepage metadata to match the live alias.
   - Restart `caddy` after label reconciliation and confirm the present routes in `/config/caddy/autosave.json`.
   - If live Caddy has a public host that is not represented in `config/homepage/services.yaml`, add it as a dashboard entry.
   - If a route is intentionally removed, remove it from `config/homepage/services.yaml` and from any stale compose label references.

4. Confirm homepage discovery is consistent:
   - External entries must use live public hostnames from Caddy.
   - `siteMonitor` should be present for external services to keep the dashboard easy to verify.
   - Internal Tailscale/LAN entries may remain in `config/homepage/services.yaml` for local access.

Verification:

- Live Caddy hostnames and `config/homepage/services.yaml` agree on the active public services.
- `git.andreasmaita.com`, `abs.andreasmaita.com`, `music.andreasmaita.com`, `actual-budget.andreasmaita.com`, `join.andreasmaita.com`, and `octo-fiesta.andreasmaita.com` are present in the dashboard if they are live.
- `nextcloud.andreasmaita.com` is validated as a live route and represented correctly.
- External homepage entries include `siteMonitor` for public routes.

---

## Stage 4: Application stack validation

**Objective:** Start and verify application stacks behind the edge.

Steps:

1. Bring up the ordered stacks with database-first boot ordering where applicable:
   - `stacks/infrastructure`
   - `stacks/monitoring`
   - `stacks/cloud/compose.db.yaml` before `stacks/cloud/compose.yaml`
   - `stacks/services/compose.db.yaml` before `stacks/services/compose.yaml`
   - `stacks/media`
   - `stacks/arr`
   - `stacks/home`

2. Validate each stack by service health checks and label discovery.

3. Verify databases and caches use only internal networks:
   - `cloud_internal`
   - `services_internal`
   - `media_internal`
   - `immich_internal`

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
   - Archive or remove any stale repo copy of `config/caddy/caddy/autosave.json` if it is not the live container route source.

2. Re-run full composition checks:

   ```bash
   docker compose -f stacks/infrastructure/compose.yaml config >/dev/null
   docker compose -f stacks/cloud/compose.db.yaml config >/dev/null
   docker compose -f stacks/cloud/compose.yaml -f stacks/cloud/compose.override.yaml config >/dev/null
   docker compose -f stacks/services/compose.db.yaml config >/dev/null
   docker compose -f stacks/services/compose.yaml config >/dev/null
   docker compose -f stacks/media/compose.yaml config >/dev/null
   docker compose -f stacks/arr/compose.yaml config >/dev/null
   docker compose -f stacks/home/compose.yaml config >/dev/null
   ```

3. Confirm the live Caddy route list matches the desired public service set after cleanup.
4. Mark the plan checklist complete only when route labels, env state, and homepage entries are consistent.

Verification:

- `docker compose config` passes for all stacks.
- The live `caddy` container config reflects only intended services.
- `.env` contains no stale `OCTOFIESTA_*` settings.
- `config/homepage/services.yaml` is aligned with live routes, especially for `abs.andreasmaita.com` / `audiobookshelf.andreasmaita.com` and `music.andreasmaita.com` / `navidrome.andreasmaita.com`.

---

## Stage 6: Monitoring validation and stack manager check

**Objective:** Validate the Tailscale-only stack manager and infrastructure monitoring services currently present in the repo.

Steps:

1. Start `stacks/monitoring/compose.yaml` and confirm `dockge` is up.
2. Start `stacks/infrastructure/compose.yaml` and confirm `uptime-kuma` is up and healthy.
3. Verify `dockge` is bound only to the Tailscale IP and has raw `/var/run/docker.sock` access:

   ```bash
   docker inspect dockge --format '{{json .HostConfig.Binds}}'
   docker exec dockge sh -c 'ip addr show | grep 100.106.40.5'
   ```

4. Verify monitoring reachability:
   - Uptime Kuma is reachable on the expected port and reports configured monitors.
   - The service should be accessible via the Tailscale IP if the public route is not intended.

5. Note service expectations for this repo:
   - `dockge` is the only monitoring stack service defined in `stacks/monitoring`.
   - `uptime-kuma` is defined in `stacks/infrastructure`.
   - `backrest` and `scrutiny` are not present in the current repository and should not be assumed installed.

Verification:

- `docker compose -f stacks/monitoring/compose.yaml config >/dev/null` passes.
- `docker compose -f stacks/infrastructure/compose.yaml config >/dev/null` passes.
- `dockge` is running and bound to `100.106.40.5:20202` only.
- Uptime Kuma returns HTTP 200 and its own monitor API is responsive.
- The repo no longer treats missing `backrest` or `scrutiny` services as present.

---

## Live Recovery Status

- [ ] `docker compose config` passes for all active stacks.
- [ ] `caddy` is using `docker-socket-proxy` and labels are discovered correctly.
- [ ] Authelia forward-auth is applied on protected hostnames.
- [ ] `nextcloud.andreasmaita.com` route is present and consistent with the live container labels.
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
