#!/usr/bin/env python3
"""Download a bounded OpenStreetMap extract from an Overpass API endpoint.

Usage:
  python tools/download_osm_region.py south west north east output.osm

The downloader retries transient gateway/server failures and rotates through
several public Overpass instances. Keep bounding boxes reasonably small.
"""
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

if len(sys.argv) != 6:
    raise SystemExit("usage: python tools/download_osm_region.py south west north east output.osm")

south, west, north, east = map(float, sys.argv[1:5])
out = sys.argv[5]

query = f'''[out:xml][timeout:120];
(
  way({south},{west},{north},{east})[highway];
  way({south},{west},{north},{east})[building];
  way({south},{west},{north},{east})[leisure];
  way({south},{west},{north},{east})[landuse];
  way({south},{west},{north},{east})[natural];
  way({south},{west},{north},{east})[waterway];
  way({south},{west},{north},{east})[railway];
);
(._;>;);
out body;'''

data = urllib.parse.urlencode({"data": query}).encode()
endpoints = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]

os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
last_error = None

for endpoint in endpoints:
    for attempt in range(1, 4):
        print(f"trying {endpoint} (attempt {attempt}/3)...", flush=True)
        req = urllib.request.Request(
            endpoint,
            data=data,
            headers={
                "User-Agent": "THE-MULTIVERSE-dev/1.1",
                "Content-Type": "application/x-www-form-urlencoded",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=240) as response:
                payload = response.read()
            if not payload.startswith(b"<?xml") and b"<osm" not in payload[:1000]:
                raise RuntimeError("Overpass returned an unexpected response")
            temp_out = out + ".part"
            with open(temp_out, "wb") as handle:
                handle.write(payload)
            os.replace(temp_out, out)
            print(f"saved {len(payload)} bytes to {out}")
            raise SystemExit(0)
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, RuntimeError) as exc:
            last_error = exc
            print(f"download failed: {exc}", flush=True)
            if attempt < 3:
                time.sleep(3 * attempt)

print("All Overpass endpoints failed.")
print(f"Last error: {last_error}")
print("Wait a few minutes and rerun the same command; no partial output is kept.")
raise SystemExit(1)
