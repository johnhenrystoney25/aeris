#!/usr/bin/env python3
"""THE MULTIVERSE terminal controller.

Windows-friendly commands:
  python tools\tm.py check
  python tools\tm.py world
  python tools\tm.py run
  python tools\tm.py setup
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "geography"
TILES = DATA / "tiles"
REGION = DATA / "federal_way_tacoma_region.json"
TEST_REGION = DATA / "test_region.json"
PROJECT = ROOT / "project.godot"
GODOT_NAMES = ["godot", "godot4", "Godot_v4.5-stable_win64.exe"]


def run(cmd: list[str], cwd: Path = ROOT) -> int:
    print("\n> " + " ".join(cmd))
    try:
        return subprocess.run(cmd, cwd=cwd).returncode
    except FileNotFoundError:
        print("ERROR: command not found:", cmd[0])
        return 127


def find_godot() -> str | None:
    for name in GODOT_NAMES:
        found = shutil.which(name)
        if found:
            return found
    return None


def validate_json(path: Path) -> tuple[bool, dict]:
    if not path.exists():
        return False, {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return isinstance(data, dict), data if isinstance(data, dict) else {}
    except Exception as exc:
        print(f"ERROR: invalid JSON {path}: {exc}")
        return False, {}


def check() -> int:
    print("THE MULTIVERSE PROJECT CHECK")
    print("=" * 36)
    required = [
        PROJECT,
        ROOT / "scenes" / "main" / "main.tscn",
        ROOT / "scenes" / "city" / "city.tscn",
        ROOT / "scenes" / "player" / "player.tscn",
        ROOT / "scripts" / "player" / "player.gd",
        ROOT / "scripts" / "world" / "osm_region_runtime.gd",
        ROOT / "scripts" / "bootstrap.gd",
    ]
    failed = False
    for path in required:
        ok = path.exists()
        print(("OK   " if ok else "MISS ") + str(path.relative_to(ROOT)))
        failed |= not ok

    print("\nGEOGRAPHY")
    print("-" * 36)
    active = REGION if REGION.exists() else TEST_REGION if TEST_REGION.exists() else None
    if active:
        ok, data = validate_json(active)
        print(f"active: {active.relative_to(ROOT)}")
        if ok:
            for key in ("roads", "buildings", "parks", "water", "railways"):
                print(f"{key:10}: {len(data.get(key, [])):,}")
        else:
            failed = True
    else:
        print("No converted region JSON found.")
        print("Run: python tools\\tm.py world")

    print("\nTOOLS")
    print("-" * 36)
    print("Python : OK")
    godot = find_godot()
    print("Godot  : " + (godot if godot else "not on PATH (open Godot normally)"))
    print("\nRESULT: " + ("CHECK FAILED" if failed else "READY"))
    return 1 if failed else 0


def world() -> int:
    TILES.mkdir(parents=True, exist_ok=True)
    if TEST_REGION.exists() and not REGION.exists():
        print("Found test_region.json; promoting it to federal_way_tacoma_region.json")
        shutil.copy2(TEST_REGION, REGION)
        print("Active geography is now:", REGION)
        return 0

    print("World data pipeline")
    print("=" * 36)
    print("This command expects OSM tile .osm files in:", TILES)
    osm_files = sorted(TILES.glob("*.osm"))
    if not osm_files:
        print("No OSM tiles found.")
        print("Download one with:")
        print("python tools\\download_osm_region.py 47.15 -122.55 47.22 -122.44 data\\geography\\tiles\\tile_01.osm")
        return 2

    merged = TILES / "federal_way_tacoma_merged.osm"
    rc = run([sys.executable, str(ROOT / "tools" / "merge_osm_xml.py"), str(merged), *map(str, osm_files)])
    if rc != 0:
        return rc
    return run([sys.executable, str(ROOT / "tools" / "osm_to_region.py"), str(merged), str(REGION)])


def run_game() -> int:
    godot = find_godot()
    if not godot:
        print("Godot is not on PATH.")
        print("Open Godot, import this folder, and press Run Project.")
        print("Optional: add your Godot executable folder to PATH, then rerun this command.")
        return 2
    return run([godot, "--editor", str(PROJECT)])


def setup() -> int:
    print("THE MULTIVERSE SETUP")
    print("=" * 36)
    for folder in ["data/geography/tiles", "data/geography/chunks", "logs", "builds"]:
        (ROOT / folder).mkdir(parents=True, exist_ok=True)
        print("OK:", folder)
    return check()


def usage() -> None:
    print(__doc__)


COMMANDS = {"check": check, "world": world, "run": run_game, "setup": setup}

if __name__ == "__main__":
    command = sys.argv[1].lower() if len(sys.argv) > 1 else "check"
    if command not in COMMANDS:
        usage()
        raise SystemExit(2)
    raise SystemExit(COMMANDS[command]())
