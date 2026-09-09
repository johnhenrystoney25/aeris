#!/usr/bin/env python3
"""Download a bounded OpenStreetMap extract from Overpass.

Usage:
  python tools/download_osm_region.py south west north east output.osm

Keep bboxes reasonably small. For large areas use a proper regional extract.
"""
import sys, urllib.parse, urllib.request

if len(sys.argv) != 6:
    raise SystemExit("usage: python tools/download_osm_region.py south west north east output.osm")
south, west, north, east = map(float, sys.argv[1:5])
out = sys.argv[5]
query = f'''[out:xml][timeout:120];(way({south},{west},{north},{east})[highway];way({south},{west},{north},{east})[building];way({south},{west},{north},{east})[leisure];way({south},{west},{north},{east})[landuse];way({south},{west},{north},{east})[natural];way({south},{west},{north},{east})[waterway];way({south},{west},{north},{east})[railway];);(._;>;);out body;'''
data = urllib.parse.urlencode({"data": query}).encode()
req = urllib.request.Request("https://overpass-api.de/api/interpreter", data=data, headers={"User-Agent":"THE-MULTIVERSE-dev/1.0"})
with urllib.request.urlopen(req, timeout=180) as response:
    payload = response.read()
open(out, "wb").write(payload)
print(f"saved {len(payload)} bytes to {out}")
