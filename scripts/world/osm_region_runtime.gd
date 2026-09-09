extends Node3D
## Renders imported geographic JSON. Generates a temporary blockout if data is missing.

@export_file("*.json") var region_file := ""
@export var default_road_width := 8.0
@export var create_building_collisions := true
@export var fallback_enabled := true

func _ready() -> void:
    if region_file.is_empty() or not FileAccess.file_exists(region_file):
        if fallback_enabled:
            _build_fallback()
        push_warning("Geographic data missing. Run tools/get_federal_way_tacoma.bat to install it.")
        return
    load_region(region_file)

func load_region(path: String) -> void:
    if not FileAccess.file_exists(path):
        _build_fallback()
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Invalid geography JSON")
        _build_fallback()
        return
    _clear_generated()
    for road in data.get("roads", []):
        _road(road.get("points", []), float(road.get("width", default_road_width)), str(road.get("class", "road")))
    for building in data.get("buildings", []):
        _building(building.get("polygon", []), float(building.get("height", 10.0)))
    for rail in data.get("railways", []):
        _road(rail.get("points", []), 3.0, "rail")
    for park in data.get("parks", []):
        _surface(park.get("polygon", []), Color(0.10, 0.28, 0.14))
    for water in data.get("water", []):
        _surface(water.get("polygon", []), Color(0.04, 0.20, 0.34))

func _clear_generated() -> void:
    for child in get_children():
        child.queue_free()

func _points(raw: Array) -> PackedVector3Array:
    var result := PackedVector3Array()
    for p in raw:
        if p is Array and p.size() >= 2:
            result.append(Vector3(float(p[0]), 0.0, float(p[1])))
    return result

func _road(raw: Array, width: float, road_class: String) -> void:
    var points := _points(raw)
    for i in range(points.size() - 1):
        var a := points[i]
        var b := points[i + 1]
        var length := a.distance_to(b)
        if length < 0.5:
            continue
        var node := MeshInstance3D.new()
        node.name = "Road_%s" % road_class
        var mesh := BoxMesh.new()
        mesh.size = Vector3(max(width, 2.0), 0.08, length)
        node.mesh = mesh
        node.position = (a + b) * 0.5 + Vector3.UP * 0.02
        node.look_at(b, Vector3.UP)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.025, 0.03, 0.035)
        mat.roughness = 0.96
        node.material_override = mat
        add_child(node)

func _building(raw: Array, height: float) -> void:
    var points := _points(raw)
    if points.size() < 3:
        return
    var min_x := INF
    var max_x := -INF
    var min_z := INF
    var max_z := -INF
    for p in points:
        min_x = min(min_x, p.x); max_x = max(max_x, p.x)
        min_z = min(min_z, p.z); max_z = max(max_z, p.z)
    var size := Vector3(max_x - min_x, max(height, 2.5), max_z - min_z)
    if size.x < 1.0 or size.z < 1.0:
        return
    var body := StaticBody3D.new()
    body.name = "Building"
    body.position = Vector3((min_x + max_x) * 0.5, size.y * 0.5, (min_z + max_z) * 0.5)
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.22, 0.25, 0.27)
    mat.roughness = 0.65
    mesh_node.material_override = mat
    body.add_child(mesh_node)
    if create_building_collisions:
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
    add_child(body)

func _surface(raw: Array, color: Color) -> void:
    var points := _points(raw)
    if points.size() < 3:
        return
    var poly := PackedVector2Array()
    for p in points:
        poly.append(Vector2(p.x, p.z))
    var indices := Geometry2D.triangulate_polygon(poly)
    if indices.is_empty():
        return
    var vertices := PackedVector3Array()
    for p in points:
        vertices.append(Vector3(p.x, 0.03, p.z))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var node := MeshInstance3D.new()
    node.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    node.material_override = mat
    add_child(node)

func _build_fallback() -> void:
    _clear_generated()
    for x in range(-8, 9):
        _road([[float(x) * 90.0, -720.0], [float(x) * 90.0, 720.0]], 7.0, "fallback")
    for z in range(-8, 9):
        _road([[-720.0, float(z) * 90.0], [720.0, float(z) * 90.0]], 7.0, "fallback")
    for x in range(-7, 8):
        for z in range(-7, 8):
            if (x + z) % 5 == 0:
                continue
            _fallback_building(float(x) * 90.0 + 24.0, float(z) * 90.0 + 24.0, 25.0 + float(abs(x * 13 + z * 7) % 55))

func _fallback_building(x: float, z: float, height: float) -> void:
    var body := StaticBody3D.new()
    body.position = Vector3(x, height * 0.5, z)
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(48.0, height, 48.0)
    mesh_node.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.20, 0.23, 0.25)
    mat.roughness = 0.7
    mesh_node.material_override = mat
    body.add_child(mesh_node)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = mesh.size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
