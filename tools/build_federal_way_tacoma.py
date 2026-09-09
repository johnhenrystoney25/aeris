#!/usr/bin/env python3
"""Build the Federal Way -> Tacoma geographic source package.

Run from the Godot project root:
  python tools/build_federal_way_tacoma.py

This intentionally downloads only a bounded OSM extract, then converts it to
compact local game coordinates. Official municipal GIS is documented as a
validation/enrichment source; proprietary map imagery is never copied.
"""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CFG = json.loads((ROOT / "tools/federal_way_tacoma_region.json").read_text(encoding="utf-8"))
B = CFG["bounds"]
RAW = ROOT / "data" / "geography" / "federal_way_tacoma.osm"
OUT = ROOT / "data" / "geography" / "federal_way_tacoma_region.json"
RAW.parent.mkdir(parents=True, exist_ok=True)

download = ROOT / "tools" / "download_osm_region.py"
convert = ROOT / "tools" / "osm_to_region.py"
subprocess.check_call([sys.executable, str(download), str(B["south"]), str(B["west"]), str(B["north"]), str(B["east"]), str(RAW)])
subprocess.check_call([sys.executable, str(convert), str(RAW), str(OUT)])
print(f"Federal Way/Tacoma region built: {OUT}")
