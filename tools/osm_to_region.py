#!/usr/bin/env python3
"""Convert a small OpenStreetMap .osm XML extract into THE MULTIVERSE region JSON.

Offline tool: run it against an already downloaded .osm extract.
No map-service API or imagery is accessed by this script.
"""
import json
import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROAD_CLASSES = {"motorway", "trunk", "primary", "secondary", "tertiary", "residential", "unclassified", "service", "living_street"}
PARK_TYPES = {"park", "garden", "recreation_ground", "nature_reserve"}
WATER_TYPES = {"riverbank", "reservoir", "basin", "lake", "pond"}


def tags_of(element):
    return {x.attrib.get("k", ""): x.attrib.get("v", "") for x in element.findall("tag")}


def main(src: str, dst: str):
    root = ET.parse(src).getroot()
    nodes = {}
    for n in root.findall("node"):
        nodes[n.attrib["id"]] = (float(n.attrib["lat"]), float(n.attrib["lon"]))

    if not nodes:
        raise SystemExit("No nodes found in OSM extract")

    origin_lat, origin_lon = next(iter(nodes.values()))
    meters_lat = 111320.0
    meters_lon = 111320.0 * max(math.cos(math.radians(origin_lat)), 0.1)

    def xy(lat, lon):
        return [(lon - origin_lon) * meters_lon, (lat - origin_lat) * meters_lat]

    roads, buildings, parks, water = [], [], [], []
    for way in root.findall("way"):
        tags = tags_of(way)
        refs = [x.attrib.get("ref") for x in way.findall("nd")]
        points = [xy(*nodes[r]) for r in refs if r in nodes]
        if len(points) < 2:
            continue

        highway = tags.get("highway")
        if highway in ROAD_CLASSES:
            roads.append({"points": points, "class": highway})
            continue

        if "building" in tags:
            try:
                height = float(tags.get("height", ""))
            except ValueError:
                try:
                    height = float(tags.get("building:levels", "3")) * 3.2
                except ValueError:
                    height = 10.0
            buildings.append({"polygon": points, "height": max(3.0, height), "type": tags.get("building", "yes")})
            continue

        leisure = tags.get("leisure")
        landuse = tags.get("landuse")
        natural = tags.get("natural")
        if leisure in PARK_TYPES or landuse in {"recreation_ground", "grass", "forest"}:
            parks.append({"polygon": points, "type": leisure or landuse})
            continue
        if natural in WATER_TYPES or landuse in {"reservoir", "basin"}:
            water.append({"polygon": points, "type": natural or landuse})

    out = {"source": "OpenStreetMap", "origin": {"lat": origin_lat, "lon": origin_lon}, "roads": roads, "buildings": buildings, "parks": parks, "water": water}
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    Path(dst).write_text(json.dumps(out, separators=(",", ":")), encoding="utf-8")
    print(json.dumps({"roads": len(roads), "buildings": len(buildings), "parks": len(parks), "water": len(water)}))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: python tools/osm_to_region.py input.osm output.json")
    main(sys.argv[1], sys.argv[2])
