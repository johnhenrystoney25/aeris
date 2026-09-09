#!/usr/bin/env python3
"""Convert an OpenStreetMap XML extract into THE MULTIVERSE region JSON."""
import json, math, sys, xml.etree.ElementTree as ET
from pathlib import Path
ROAD_CLASSES={"motorway","trunk","primary","secondary","tertiary","residential","unclassified","service","living_street","pedestrian"}
PARK_TYPES={"park","garden","playground","recreation_ground","nature_reserve"}
WATER_TYPES={"riverbank","reservoir","basin","lake","pond","water"}
ROAD_WIDTH={"motorway":18.0,"trunk":16.0,"primary":13.0,"secondary":11.0,"tertiary":9.0,"residential":7.0,"unclassified":7.0,"service":5.0,"living_street":6.0,"pedestrian":5.0}
def tags_of(el): return {x.attrib.get("k",""):x.attrib.get("v","") for x in el.findall("tag")}
def height_of(t):
    try:
        if t.get("height"): return max(3.0,float(t["height"].replace("m","").strip()))
    except ValueError: pass
    try: return max(3.0,float(t.get("building:levels","3"))*3.2)
    except ValueError: return 10.0
def main(src,dst):
    root=ET.parse(src).getroot(); nodes={n.attrib["id"]:(float(n.attrib["lat"]),float(n.attrib["lon"])) for n in root.findall("node") if "lat" in n.attrib and "lon" in n.attrib}
    if not nodes: raise SystemExit("No nodes found in OSM extract")
    lat0=sum(v[0] for v in nodes.values())/len(nodes); lon0=sum(v[1] for v in nodes.values())/len(nodes); r=6378137.0
    def xy(lat,lon): return [math.radians(lon-lon0)*r*math.cos(math.radians(lat0)),-math.radians(lat-lat0)*r]
    out={"schema":3,"source":"OpenStreetMap","origin":{"lat":lat0,"lon":lon0},"roads":[],"buildings":[],"parks":[],"water":[],"railways":[]}
    for way in root.findall("way"):
        t=tags_of(way); refs=[x.attrib.get("ref") for x in way.findall("nd")]; pts=[xy(*nodes[k]) for k in refs if k in nodes]
        if len(pts)<2: continue
        h=t.get("highway")
        if h in ROAD_CLASSES: out["roads"].append({"points":pts,"class":h,"name":t.get("name",""),"width":ROAD_WIDTH.get(h,8.0)})
        if t.get("building") and len(pts)>=3: out["buildings"].append({"polygon":pts,"height":height_of(t),"type":t.get("building","yes"),"name":t.get("name","")})
        leisure=t.get("leisure"); land=t.get("landuse"); natural=t.get("natural"); water=t.get("water")
        if water in WATER_TYPES or natural=="water" or t.get("waterway")=="riverbank": out["water"].append({"polygon":pts,"type":water or natural or "water"})
        if leisure in PARK_TYPES or land in {"recreation_ground","grass","forest","meadow"} or natural in {"wood","scrub","grassland"}: out["parks"].append({"polygon":pts,"type":leisure or land or natural or "park"})
        if t.get("railway"): out["railways"].append({"points":pts,"class":t["railway"],"name":t.get("name","")})
    Path(dst).parent.mkdir(parents=True,exist_ok=True); Path(dst).write_text(json.dumps(out,separators=(",",":")),encoding="utf-8")
    print(json.dumps({k:len(v) for k,v in out.items() if isinstance(v,list)},indent=2))
if __name__=="__main__":
    if len(sys.argv)!=3: raise SystemExit("usage: python tools/osm_to_region.py input.osm output.json")
    main(sys.argv[1],sys.argv[2])
