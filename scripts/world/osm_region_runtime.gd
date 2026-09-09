extends Node3D
## Turns normalized region JSON into lightweight runtime map geometry.
## Designed for imported geographic layout; visual dressing remains procedural/original.

@export_file("*.json") var region_file := ""
@export var road_width := 8.0
@export var building_material_color := Color(0.25, 0.29, 0.31)

func _ready() -> void:
    if not region_file.is_empty():
        load_region(region_file)

func load_region(path: String) -> void:
    if not FileAccess.file_exists(path):
        push_warning("Region file missing: %s" % path)
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Invalid region JSON")
        return
    _clear_generated()
    for road in parsed.get("roads", []):
        _road(road.get("points", []))
    for building in parsed.get("buildings", []):
        _building(building.get("polygon", []), float(building.get("height", 10.0)))
    for park in parsed.get("parks", []):
        _surface(park.get("polygon", []), Color(0.10, 0.28, 0.14), 0.03)
    for lake in parsed.get("water", []):
        _surface(lake.get("polygon", []), Color(0.04, 0.20, 0.34), 0.02)

func _clear_generated() -> void:
    for c in get_children():
        c.queue_free()

func _points(raw: Array) -> PackedVector3Array:
    var pts := PackedVector3Array()
    for p in raw:
        if p is Array and p.size() >= 2:
            pts.append(Vector3(float(p[0]), 0.0, float(p[1])))
    return pts

func _road(raw: Array) -> void:
    var pts := _points(raw)
    for i in range(pts.size() - 1):
        var a := pts[i]
        var b := pts[i + 1]
        var length := a.distance_to(b)
        if length < 0.5:
            continue
        var n := MeshInstance3D.new()
        n.name = "OSM_Road"
        var mesh := BoxMesh.new()
        mesh.size = Vector3(road_width, 0.08, length)
        n.mesh = mesh
        n.position = (a + b) * 0.5 + Vector3.UP * 0.01
        n.look_at(b, Vector3.UP)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.025, 0.03, 0.035)
        mat.roughness = 0.96
        n.material_override = mat
        add_child(n)

func _building(raw: Array, height: float) -> void:
    var pts := _points(raw)
    if pts.size() < 3:
        return
    var min_x := INF
    var max_x := -INF
    var min_z := INF
    var max_z := -INF
    for p in pts:
        min_x = min(min_x, p.x); max_x = max(max_x, p.x)
        min_z = min(min_z, p.z); max_z = max(max_z, p.z)
    var n := MeshInstance3D.new()
    n.name = "OSM_Building"
    var mesh := BoxMesh.new()
    mesh.size = Vector3(max_x - min_x, height, max_z - min_z)
    n.mesh = mesh
    n.position = Vector3((min_x + max_x) * 0.5, height * 0.5, (min_z + max_z) * 0.5)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = building_material_color
    mat.roughness = 0.62
    mat.metallic = 0.08
    n.material_override = mat
    add_child(n)

func _surface(raw: Array, color: Color, y: float) -> void:
    var pts := _points(raw)
    if pts.size() < 3:
        return
    var poly := PackedVector2Array()
    for p in pts:
        poly.append(Vector2(p.x, p.z))
    var mesh := ArrayMesh.new()
    var vertices := PackedVector3Array()
    for p in pts:
        vertices.append(Vector3(p.x, y, p.z))
    var indices := Geometry2D.triangulate_polygon(poly)
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var n := MeshInstance3D.new()
    n.name = "OSM_Surface"
    n.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    n.material_override = mat
    add_child(n)
