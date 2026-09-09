@tool
extends Node
## Offline/open-data region importer foundation.
## Accepts normalized JSON exported from OpenStreetMap/GeoJSON tooling.
## Expected shape: {"roads":[{"points":[[x,z],...]}],"buildings":[{"polygon":[[x,z],...],"height":20}],"water":[],"parks":[]}

@export_file("*.json") var source_file := ""
@export var meters_per_unit := 1.0

func load_region(path := source_file) -> Dictionary:
    if path.is_empty() or not FileAccess.file_exists(path):
        push_warning("Region source not found: %s" % path)
        return {}
    var text := FileAccess.get_file_as_string(path)
    var data = JSON.parse_string(text)
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Region JSON must contain an object")
        return {}
    return data

func normalize_points(points: Array) -> PackedVector3Array:
    var result := PackedVector3Array()
    for p in points:
        if p is Array and p.size() >= 2:
            result.append(Vector3(float(p[0]) * meters_per_unit, 0.0, float(p[1]) * meters_per_unit))
    return result

func build_summary(data: Dictionary) -> Dictionary:
    return {
        "roads": data.get("roads", []).size(),
        "buildings": data.get("buildings", []).size(),
        "water": data.get("water", []).size(),
        "parks": data.get("parks", []).size()
    }
