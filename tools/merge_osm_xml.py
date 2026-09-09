#!/usr/bin/env python3
"""Merge several Overpass OSM XML extracts into one deduplicated XML file."""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

if len(sys.argv) < 3:
    raise SystemExit("usage: python tools/merge_osm_xml.py output.osm input1.osm [input2.osm ...]")

output = Path(sys.argv[1])
inputs = [Path(p) for p in sys.argv[2:]]
root_out = ET.Element("osm", {"version": "0.6", "generator": "THE-MULTIVERSE OSM merger"})
nodes = {}
ways = {}
relations = {}

for path in inputs:
    if not path.exists():
        raise SystemExit(f"missing extract: {path}")
    root = ET.parse(path).getroot()
    for child in root:
        kind = child.tag
        ident = child.attrib.get("id")
        if kind == "node" and ident:
            nodes[ident] = child
        elif kind == "way" and ident:
            ways[ident] = child
        elif kind == "relation" and ident:
            relations[ident] = child

for item in nodes.values():
    root_out.append(item)
for item in ways.values():
    root_out.append(item)
for item in relations.values():
    root_out.append(item)

output.parent.mkdir(parents=True, exist_ok=True)
ET.ElementTree(root_out).write(output, encoding="utf-8", xml_declaration=True)
print(f"merged {len(nodes)} nodes, {len(ways)} ways, {len(relations)} relations -> {output}")
