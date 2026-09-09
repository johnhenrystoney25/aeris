from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TILES = ROOT / "data" / "geography" / "tiles"
MERGED = ROOT / "data" / "geography" / "federal_way_tacoma_merged.osm"
REGION = ROOT / "data" / "geography" / "federal_way_tacoma_region.json"

BOUNDS = [
    (47.15, -122.55, 47.22, -122.44),
    (47.15, -122.44, 47.22, -122.33),
    (47.15, -122.33, 47.22, -122.20),
    (47.22, -122.55, 47.29, -122.44),
    (47.22, -122.44, 47.29, -122.33),
    (47.22, -122.33, 47.29, -122.20),
    (47.29, -122.55, 47.36, -122.44),
    (47.29, -122.44, 47.36, -122.33),
    (47.29, -122.33, 47.36, -122.20),
]


def run(args):
    print("+", " ".join(map(str, args)))
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    TILES.mkdir(parents=True, exist_ok=True)
    downloader = [sys.executable, str(ROOT / "tools" / "download_osm_region.py")]

    for i, (s, w, n, e) in enumerate(BOUNDS, 1):
        target = TILES / f"tile_{i:02d}.osm"
        if target.exists() and target.stat().st_size > 1024:
            print(f"tile {i:02d}: existing {target.stat().st_size:,} bytes; keeping it")
            continue
        run(downloader + [str(s), str(w), str(n), str(e), str(target)])

    osm_files = [TILES / f"tile_{i:02d}.osm" for i in range(1, 10)]
    missing = [p for p in osm_files if not p.exists() or p.stat().st_size <= 1024]
    if missing:
        print("\nSTOP: these OSM tiles are still missing or incomplete:")
        for path in missing:
            print(f"  - {path}")
        raise SystemExit(2)

    # merge_osm_xml.py expects: output.osm input1.osm input2.osm ...
    run([sys.executable, str(ROOT / "tools" / "merge_osm_xml.py"), str(MERGED), *map(str, osm_files)])
    run([sys.executable, str(ROOT / "tools" / "osm_to_region.py"), str(MERGED), str(REGION)])
    print(f"\nDONE: {REGION}")
    print("The game region is now generated from all nine real-world OSM tiles.")


if __name__ == "__main__":
    main()
