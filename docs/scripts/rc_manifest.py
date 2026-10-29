#!/usr/bin/env python3
"""Release-candidate manifest for 911: The Last Call (P5-10).

Reads the version from project.godot, hashes every exported file and writes:

  build/rc/release_manifest.json  — machine-readable build inventory + commit + version
  build/rc/SHA256SUMS             — `sha256  path` lines for player-side verification

Usage:
  python docs/scripts/rc_manifest.py --build-dir build/rc
  python docs/scripts/rc_manifest.py --check-version v1.0.0-rc.1

`--check-version` fails when a tag does not match `application/config/version`, which is what stops a
release workflow from attaching the wrong binary to a GitHub release.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
DEFAULT_PROJECT = ROOT / "project.godot"
MANIFEST_NAME = "release_manifest.json"
SUMS_NAME = "SHA256SUMS"


def project_version(project: pathlib.Path) -> str:
    text = project.read_text(encoding="utf-8")
    match = re.search(r'^\s*config/version\s*=\s*"([^"]+)"', text, re.M)
    if not match:
        raise SystemExit(f"{project}: application/config/version is missing")
    return normalise(match.group(1))


def normalise(value: str) -> str:
    value = value.strip()
    return value[1:] if value[:1] in ("v", "V") else value


def channel_for(version: str) -> str:
    lowered = version.lower()
    if "demo" in lowered:
        return "demo"
    if "rc" in lowered:
        return "rc"
    return "release"


def git_commit() -> str:
    return os.environ.get("GITHUB_SHA") or _git("rev-parse", "HEAD")


def _git(*args: str) -> str:
    try:
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def digest(path: pathlib.Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def build_manifest(build_dir: pathlib.Path, version: str, project: pathlib.Path) -> dict:
    if not build_dir.is_dir():
        raise SystemExit(f"{build_dir}: build directory not found")
    files = []
    for path in sorted(build_dir.rglob("*")):
        if not path.is_file():
            continue
        name = path.name
        if name in (MANIFEST_NAME, SUMS_NAME):
            continue
        files.append({
            "path": path.relative_to(build_dir).as_posix(),
            "size": path.stat().st_size,
            "sha256": digest(path),
        })
    if not files:
        raise SystemExit(f"{build_dir}: no build files to hash")
    return {
        "schema": 1,
        "product": "911: The Last Call",
        "version": version,
        "channel": channel_for(version),
        "commit": git_commit(),
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "engine": project_engine(project),
        "files": files,
    }


def project_engine(project: pathlib.Path) -> str:
    text = project.read_text(encoding="utf-8")
    match = re.search(r'config/features\s*=\s*PackedStringArray\(([^)]*)\)', text)
    return match.group(1).strip() if match else ""


def write_outputs(build_dir: pathlib.Path, manifest: dict, output: pathlib.Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    sums = build_dir / SUMS_NAME
    lines = [f"{entry['sha256']}  {entry['path']}" for entry in manifest["files"]]
    sums.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Create the release-candidate manifest.")
    parser.add_argument("--build-dir", type=pathlib.Path, default=ROOT / "build/rc")
    parser.add_argument("--project", type=pathlib.Path, default=DEFAULT_PROJECT)
    parser.add_argument("--version", default="", help="override the version (a leading v is stripped)")
    parser.add_argument("--output", type=pathlib.Path, default=None)
    parser.add_argument("--check-version", default="", help="exit non-zero unless this tag matches project.godot")
    args = parser.parse_args()

    version = project_version(args.project)
    if args.check_version:
        tag = normalise(args.check_version)
        if tag != version:
            print(f"ERROR tag {args.check_version!r} does not match project version {version!r}")
            return 1
        print(f"OK version {version}")
        return 0

    if args.version:
        version = normalise(args.version)
    manifest = build_manifest(args.build_dir, version, args.project)
    output = args.output or args.build_dir / MANIFEST_NAME
    write_outputs(args.build_dir, manifest, output)
    print(f"OK {version} ({manifest['channel']}) — {len(manifest['files'])} file(s)")
    print(f"    {output}")
    print(f"    {args.build_dir / SUMS_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
