extends Node3D
## Runtime renderer for recorded geography. Keeps source geometry separate from original visual dressing.

@export_file("*.json") var region_file := ""
@export var default_road_width := 8.0
@export var create_building_collisions := true
@export var fallback_enabled := true
@export var visual_dressing := true

var _building_index := 0

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
    _building_index = 0
    for road in data.get("roads", []):
        _road(road.get("points", []), float(road.get("width", default_road_width)), str(road.get("class", "road")))
    for building in data.get("buildings", []):
        _building(building.get("polygon", []), float(building.get("height", 10.0)), str(building.get("type", "building")))
    for rail in data.get("railways", []):
        _road(rail.get("points", []), 3.0, "rail")
    for park in data.get("parks", []):
        _surface(park.get("polygon", []), Color(0.08, 0.30, 0.14))
    for water in data.get("water", []):
        _surface(water.get("polygon", []), Color(0.03, 0.25, 0.48))

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
    var road_color := _road_color(road_class)
    for i in range(points.size() - 1):
        var a := points[i]
        var b := points[i + 1]
        var length := a.distance_to(b)
        if length < 0.5:
            continue
        var midpoint := (a + b) * 0.5
        var angle := atan2(-(b.x - a.x), -(b.z - a.z))
        _box("Road_%s" % road_class, Vector3(max(width, 2.0), 0.10, length), midpoint + Vector3.UP * 0.03, angle, road_color)
        if visual_dressing and road_class != "rail" and length > 18.0:
            var dash_color := Color(0.92, 0.82, 0.35) if road_class in ["primary", "secondary", "tertiary"] else Color(0.82, 0.82, 0.78)
            var dash_count := clampi(int(length / 14.0), 1, 14)
            for dash in range(dash_count):
                var t := (float(dash) + 0.5) / float(dash_count)
                var p := a.lerp(b, t) + Vector3.UP * 0.095
                _box("LaneMark", Vector3(0.14, 0.018, minf(4.5, length / float(dash_count) * 0.55)), p, angle, dash_color)

func _road_color(road_class: String) -> Color:
    match road_class:
        "motorway": return Color(0.055, 0.065, 0.085)
        "trunk": return Color(0.065, 0.075, 0.095)
        "primary": return Color(0.075, 0.085, 0.105)
        "secondary": return Color(0.095, 0.10, 0.115)
        "tertiary": return Color(0.12, 0.12, 0.13)
        "rail": return Color(0.08, 0.065, 0.055)
        _: return Color(0.12, 0.12, 0.13)

func _box(node_name: String, size: Vector3, position: Vector3, yaw: float, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = position
    node.rotation.y = yaw
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.82
    node.material_override = mat
    add_child(node)
    return node

func _building(raw: Array, height: float, building_type: String) -> void:
    var points := _points(raw)
    if points.size() < 3:
        return
    var min_x := INF
    var max_x := -INF
    var min_z := INF
    var max_z := -INF
    for p in points:
        min_x = min(min_x, p.x)
        max_x = max(max_x, p.x)
        min_z = min(min_z, p.z)
        max_z = max(max_z, p.z)
    var size := Vector3(max_x - min_x, max(height, 2.5), max_z - min_z)
    if size.x < 1.0 or size.z < 1.0:
        return
    var center := Vector3((min_x + max_x) * 0.5, size.y * 0.5, (min_z + max_z) * 0.5)
    var body := StaticBody3D.new()
    body.name = "Building_%04d" % _building_index
    body.position = center
    body.collision_layer = 1
    body.collision_mask = 2
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    var hue := fposmod(absf(sin(min_x * 0.011 + max_z * 0.017)), 1.0)
    var building_color := Color(0.18 + hue * 0.13, 0.22 + hue * 0.12, 0.28 + hue * 0.16)
    if building_type in ["industrial", "warehouse"]:
        building_color = Color(0.25, 0.27, 0.29)
    elif building_type in ["commercial", "retail"]:
        building_color = Color(0.24, 0.18 + hue * 0.12, 0.12 + hue * 0.08)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = building_color
    mat.metallic = 0.08
    mat.roughness = 0.68
    mesh_node.material_override = mat
    body.add_child(mesh_node)
    if create_building_collisions:
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
    if visual_dressing and size.y > 5.0:
        var roof := MeshInstance3D.new()
        var roof_mesh := BoxMesh.new()
        roof_mesh.size = Vector3(maxf(1.0, size.x - 0.35), 0.18, maxf(1.0, size.z - 0.35))
        roof.mesh = roof_mesh
        roof.position = Vector3(0, size.y * 0.5 + 0.10, 0)
        var roof_mat := StandardMaterial3D.new()
        roof_mat.albedo_color = Color(0.035, 0.045, 0.06)
        roof_mat.roughness = 0.72
        roof.material_override = roof_mat
        body.add_child(roof)
        var accent := MeshInstance3D.new()
        var accent_mesh := BoxMesh.new()
        accent_mesh.size = Vector3(maxf(0.3, minf(size.x * 0.55, 8.0)), 0.22, 0.06)
        accent.mesh = accent_mesh
        accent.position = Vector3(0, minf(size.y * 0.62, 18.0), -size.z * 0.5 - 0.04)
        var accent_mat := StandardMaterial3D.new()
        accent_mat.albedo_color = Color(0.04, 0.12, 0.18)
        accent_mat.emission_enabled = true
        accent_mat.emission = Color(0.02, 0.45 + hue * 0.35, 0.85, 1)
        accent_mat.emission_energy_multiplier = 2.0
        accent.material_override = accent_mat
        body.add_child(accent)
    add_child(body)
    _building_index += 1

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
        vertices.append(Vector3(p.x, 0.06, p.z))
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
    body.collision_layer = 1
    body.collision_mask = 2
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(48.0, height, 48.0)
    mesh_node.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.12 + fposmod(absf(sin(x * 0.07)), 0.18), 0.18, 0.28 + fposmod(absf(cos(z * 0.05)), 0.16))
    mat.roughness = 0.7
    mesh_node.material_override = mat
    body.add_child(mesh_node)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = mesh.size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
