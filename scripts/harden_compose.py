#!/usr/bin/env python3
"""
Generate non-destructive hardening suggestions for Docker Compose files.

This script does NOT modify files. It scans the repository for Compose
YAML files that declare services and produces a human-readable suggestions
report plus per-file YAML snippets that can be applied manually.

Usage:
  python3 scripts/harden_compose.py --output backups/compose-hardening-suggestions.txt

Requirements:
  - Python 3.8+
  - PyYAML (optional). If not installed the script will still scan files
    heuristically and emit text suggestions.

The script is intentionally conservative: it only writes suggestions under
`backups/hardening-snippets/` and a top-level suggestions file. Review
the output before applying changes.
"""

from __future__ import annotations

import argparse
import os
import textwrap
from pathlib import Path

try:
    import yaml
except Exception:
    yaml = None


ROOT = Path(__file__).resolve().parents[1]


def find_compose_files(root: Path):
    candidates = []
    for p in root.rglob("*.yml"):
        try:
            text = p.read_text(encoding="utf-8")
        except Exception:
            continue
        if "services:" in text and "image:" in text:
            candidates.append(p)
    for p in root.rglob("*.yaml"):
        if p in candidates:
            continue
        try:
            text = p.read_text(encoding="utf-8")
        except Exception:
            continue
        if "services:" in text and "image:" in text:
            candidates.append(p)
    return sorted(candidates)


def analyze_file(path: Path):
    suggestions = []
    snippets = {}
    raw = path.read_text(encoding="utf-8")
    data = None
    if yaml:
        try:
            data = yaml.safe_load(raw)
        except Exception:
            data = None

    # Fallback heuristic: look for service blocks by simple parsing
    services = {}
    if isinstance(data, dict) and "services" in data:
        services = data.get("services") or {}
    else:
        # naive parse: find lines starting without indentation followed by ':' and block containing 'image:'
        # This fallback keeps the script useful even without PyYAML.
        cur = None
        for line in raw.splitlines():
            if not line.strip():
                continue
            if not line.startswith(" ") and line.endswith(":"):
                cur = line.strip()[:-1]
                services[cur] = {}
            elif cur and "image:" in line:
                # store the image token for the snippet
                img = line.split("image:", 1)[1].strip()
                services[cur]["image"] = img

    for svc_name, svc in services.items():
        image = None
        if isinstance(svc, dict):
            image = svc.get("image")
        if isinstance(image, (list, dict)):
            image = None

        # simple string cleanup
        if isinstance(image, str):
            image = image.strip().strip('"').strip("'")

        need_pin = False
        need_health = False
        need_limits = False

        if image:
            if ":latest" in image or ":" not in image:
                need_pin = True
        else:
            # no image found in parsed structure — rely on heuristic
            need_pin = False

        # detect presence of healthcheck and limits by simple substring search
        txt = raw
        svc_block = None
        # attempt to isolate service block for the given service name
        marker = f"{svc_name}:"
        if marker in txt:
            idx = txt.index(marker)
            svc_block = txt[idx : idx + 2000]
        if svc_block:
            if "healthcheck:" not in svc_block:
                need_health = True
            if (
                ("mem_limit" not in svc_block)
                and ("cpus" not in svc_block)
                and ("deploy:" not in svc_block)
            ):
                need_limits = True
        else:
            need_health = True
            need_limits = True

        notes = []
        snippet = textwrap.dedent(f"""
        {svc_name}:
          # image: {image or "<image>"}
          restart: unless-stopped
        """)

        if need_health:
            notes.append("missing healthcheck")
            snippet += textwrap.dedent("""
              healthcheck:
                test: ["CMD-SHELL", "curl -f http://localhost:8080/ || exit 1"]
                interval: 30s
                timeout: 10s
                retries: 3
            """)
        if need_limits:
            notes.append("missing resource limits")
            snippet += textwrap.dedent("""
              mem_limit: 512m
              cpus: 0.5
            """)
        if need_pin:
            notes.append("image uses :latest or no tag — pin to a release or digest")

        if notes:
            suggestions.append((svc_name, notes))
            snippets[svc_name] = snippet

    return suggestions, snippets


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        "-o",
        default=str(ROOT / "backups" / "compose-hardening-suggestions.txt"),
    )
    args = parser.parse_args()

    out_path = Path(args.output)
    # If user provided a relative path, anchor it under the repo root so
    # subsequent relative_to(ROOT) calls succeed. Resolve to an absolute
    # path for consistent behavior.
    if not out_path.is_absolute():
        out_path = (ROOT / out_path).resolve()
    else:
        out_path = out_path.resolve()

    out_path.parent.mkdir(parents=True, exist_ok=True)
    snippets_dir = out_path.parent / "hardening-snippets"
    snippets_dir.mkdir(parents=True, exist_ok=True)

    files = find_compose_files(ROOT)
    if not files:
        out_path.write_text(
            "No Compose files detected in repository.\n", encoding="utf-8"
        )
        print("No Compose files detected. See README-HARDENING.md for next steps.")
        return

    with out_path.open("w", encoding="utf-8") as out:
        out.write("Compose Hardening Suggestions\n")
        out.write("Generated by scripts/harden_compose.py\n\n")
        for p in files:
            out.write(f"File: {p.relative_to(ROOT)}\n")
            suggestions, snippets = analyze_file(p)
            if not suggestions:
                out.write("  - No obvious hardening suggestions found.\n\n")
                continue
            for svc, notes in suggestions:
                out.write(f"  - Service: {svc}\n")
                for n in notes:
                    out.write(f"      * {n}\n")
                out.write("\n")
            # write snippets
            snippet_path = snippets_dir / (p.name + ".suggest.yaml")
            with snippet_path.open("w", encoding="utf-8") as s:
                for svc, sn in snippets.items():
                    s.write(sn)
                    s.write("\n\n")
            out.write(f"  - Snippets: {snippet_path.relative_to(ROOT)}\n\n")

    print("Wrote suggestions to:", out_path)


if __name__ == "__main__":
    main()
