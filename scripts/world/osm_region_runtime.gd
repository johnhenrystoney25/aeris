extends Node3D
## Chunked runtime renderer for recorded geography.
## Source geometry stays data-driven; only nearby chunks become Godot nodes.

@export_file("*.json") var region_file := ""
@export var default_road_width := 8.0
@export var create_building_collisions := true
@export var fallback_enabled := true
@export var visual_dressing := true
@export var chunk_size := 500.0
@export var stream_radius := 2
@export var collision_radius := 1
@export var enable_streaming := true

var _road_chunks: Dictionary = {}
var _building_chunks: Dictionary = {}
var _park_chunks: Dictionary = {}
var _water_chunks: Dictionary = {}
var _rail_chunks: Dictionary = {}
var _loaded_chunks: Dictionary = {}
var _building_index := 0
var _data_loaded := false
var _fallback_active := false

func _ready() -> void:
    if region_file.is_empty() or not FileAccess.file_exists(region_file):
        if fallback_enabled:
            _build_fallback()
        push_warning("Geographic data missing. Run the geography pipeline to install it.")
        return
    load_region(region_file)

func load_region(path: String) -> void:
    if not FileAccess.file_exists(path):
        if fallback_enabled:
            _build_fallback()
        return
    var text := FileAccess.get_file_as_string(path)
    var data = JSON.parse_string(text)
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Invalid geography JSON")
        if fallback_enabled:
            _build_fallback()
        return

    _clear_generated()
    _clear_indexes()
    _building_index = 0
    _fallback_active = false

    for road in data.get("roads", []):
        _index_feature(_road_chunks, road.get("points", []), road)
    for building in data.get("buildings", []):
        _index_feature(_building_chunks, building.get("polygon", []), building)
    for rail in data.get("railways", []):
        _index_feature(_rail_chunks, rail.get("points", []), rail)
    for park in data.get("parks", []):
        _index_feature(_park_chunks, park.get("polygon", []), park)
    for water in data.get("water", []):
        _index_feature(_water_chunks, water.get("polygon", []), water)

    _data_loaded = true
    if enable_streaming:
        update_streaming(Vector3.ZERO)
    else:
        _load_all_indexed_chunks()

func update_streaming(player_position: Vector3) -> void:
    if not _data_loaded or _fallback_active:
        return
    var center := _chunk_key(player_position)
    var wanted: Dictionary = {}
    for x in range(center.x - stream_radius, center.x + stream_radius + 1):
        for z in range(center.y - stream_radius, center.y + stream_radius + 1):
            wanted[Vector2i(x, z)] = true

    for key in wanted.keys():
        if not _loaded_chunks.has(key):
            _load_chunk(key)

    var to_unload: Array = []
    for key in _loaded_chunks.keys():
        if not wanted.has(key):
            to_unload.append(key)
    for key in to_unload:
        _unload_chunk(key)

func get_streaming_stats() -> Dictionary:
    var road_count := 0
    var building_count := 0
    var park_count := 0
    var water_count := 0
    var rail_count := 0
    for key in _loaded_chunks.keys():
        road_count += _road_chunks.get(key, []).size()
        building_count += _building_chunks.get(key, []).size()
        park_count += _park_chunks.get(key, []).size()
        water_count += _water_chunks.get(key, []).size()
        rail_count += _rail_chunks.get(key, []).size()
    return {
        "loaded_chunks": _loaded_chunks.size(),
        "roads": road_count,
        "buildings": building_count,
        "parks": park_count,
        "water": water_count,
        "railways": rail_count
    }

func _clear_indexes() -> void:
    _road_chunks.clear()
    _building_chunks.clear()
    _park_chunks.clear()
    _water_chunks.clear()
    _rail_chunks.clear()
    _loaded_chunks.clear()
    _data_loaded = false

func _clear_generated() -> void:
    for child in get_children():
        child.queue_free()

func _chunk_key(position: Vector3) -> Vector2i:
    return Vector2i(floori(position.x / chunk_size), floori(position.z / chunk_size))

func _index_feature(index: Dictionary, raw_points: Array, feature: Dictionary) -> void:
    if raw_points.size() < 2:
        return
    var points := _points(raw_points)
    if points.size() < 2:
        return
    var min_x := INF
    var max_x := -INF
    var min_z := INF
    var max_z := -INF
    for p in points:
        min_x = minf(min_x, p.x)
        max_x = maxf(max_x, p.x)
        min_z = minf(min_z, p.z)
        max_z = maxf(max_z, p.z)
    var min_key := _chunk_key(Vector3(min_x, 0, min_z))
    var max_key := _chunk_key(Vector3(max_x, 0, max_z))
    var stored := feature.duplicate(true)
    stored["_tm_points"] = raw_points
    for x in range(min_key.x, max_key.x + 1):
        for z in range(min_key.y, max_key.y + 1):
            var key := Vector2i(x, z)
            if not index.has(key):
                index[key] = []
            index[key].append(stored)

func _points(raw: Array) -> PackedVector3Array:
    var result := PackedVector3Array()
    for p in raw:
        if p is Array and p.size() >= 2:
            result.append(Vector3(float(p[0]), 0.0, float(p[1])))
    return result

func _load_all_indexed_chunks() -> void:
    var keys: Dictionary = {}
    for index in [_road_chunks, _building_chunks, _park_chunks, _water_chunks, _rail_chunks]:
        for key in index.keys():
            keys[key] = true
    for key in keys.keys():
        _load_chunk(key)

func _load_chunk(key: Vector2i) -> void:
    if _loaded_chunks.has(key):
        return
    var chunk := Node3D.new()
    chunk.name = "Chunk_%d_%d" % [key.x, key.y]
    chunk.set_meta("chunk_key", key)
    add_child(chunk)
    _loaded_chunks[key] = chunk

    for road in _road_chunks.get(key, []):
        _road_into(chunk, road.get("_tm_points", []), float(road.get("width", default_road_width)), str(road.get("class", "road")))
    for rail in _rail_chunks.get(key, []):
        _road_into(chunk, rail.get("_tm_points", []), 3.0, "rail")
    for park in _park_chunks.get(key, []):
        _surface_into(chunk, park.get("_tm_points", []), Color(0.08, 0.30, 0.14))
    for water in _water_chunks.get(key, []):
        _surface_into(chunk, water.get("_tm_points", []), Color(0.03, 0.25, 0.48))

    var allow_collision := create_building_collisions and _is_within_collision_radius(key)
    for building in _building_chunks.get(key, []):
        _building_into(chunk, building.get("_tm_points", []), float(building.get("height", 10.0)), str(building.get("type", "building")), allow_collision)

func _unload_chunk(key: Vector2i) -> void:
    var node = _loaded_chunks.get(key)
    if is_instance_valid(node):
        node.queue_free()
    _loaded_chunks.erase(key)

func _is_within_collision_radius(key: Vector2i) -> bool:
    var center := _chunk_key(Vector3.ZERO)
    return abs(key.x - center.x) <= collision_radius and abs(key.y - center.y) <= collision_radius

func _road_into(parent: Node3D, raw: Array, width: float, road_class: String) -> void:
    var points := _points(raw)
    for i in range(points.size() - 1):
        var a := points[i]
        var b := points[i + 1]
        var length := a.distance_to(b)
        if length < 0.5:
            continue
        var midpoint := (a + b) * 0.5
        var angle := atan2(-(b.x - a.x), -(b.z - a.z))
        _box(parent, "Road_%s" % road_class, Vector3(maxf(width, 2.0), 0.10, length), midpoint + Vector3.UP * 0.03, angle, _road_color(road_class))
        if visual_dressing and road_class != "rail" and length > 18.0:
            var dash_color := Color(0.92, 0.82, 0.35) if road_class in ["primary", "secondary", "tertiary"] else Color(0.82, 0.82, 0.78)
            var dash_count := clampi(int(length / 14.0), 1, 14)
            for dash in range(dash_count):
                var t := (float(dash) + 0.5) / float(dash_count)
                var p := a.lerp(b, t) + Vector3.UP * 0.095
                _box(parent, "LaneMark", Vector3(0.14, 0.018, minf(4.5, length / float(dash_count) * 0.55)), p, angle, dash_color)

func _road_color(road_class: String) -> Color:
    match road_class:
        "motorway": return Color(0.055, 0.065, 0.085)
        "trunk": return Color(0.065, 0.075, 0.095)
        "primary": return Color(0.075, 0.085, 0.105)
        "secondary": return Color(0.095, 0.10, 0.115)
        "tertiary": return Color(0.12, 0.12, 0.13)
        "rail": return Color(0.08, 0.065, 0.055)
        _: return Color(0.12, 0.12, 0.13)

func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, yaw: float, color: Color) -> MeshInstance3D:
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
    parent.add_child(node)
    return node

func _building_into(parent: Node3D, raw: Array, height: float, building_type: String, with_collision: bool) -> void:
    var points := _points(raw)
    if points.size() < 3:
        return
    var min_x := INF
    var max_x := -INF
    var min_z := INF
    var max_z := -INF
    for p in points:
        min_x = minf(min_x, p.x)
        max_x = maxf(max_x, p.x)
        min_z = minf(min_z, p.z)
        max_z = maxf(max_z, p.z)
    var size := Vector3(maxf(max_x - min_x, 1.0), maxf(height, 2.5), maxf(max_z - min_z, 1.0))
    var center := Vector3((min_x + max_x) * 0.5, size.y * 0.5, (min_z + max_z) * 0.5)
    var body: Node3D = parent
    if with_collision:
        var static_body := StaticBody3D.new()
        static_body.name = "Building_%04d" % _building_index
        static_body.position = center
        static_body.collision_layer = 1
        static_body.collision_mask = 2
        parent.add_child(static_body)
        body = static_body
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        static_body.add_child(collision)
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = "BuildingVisual_%04d" % _building_index
    mesh_node.position = center if not with_collision else Vector3.ZERO
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
    if visual_dressing and size.y > 5.0:
        var roof := MeshInstance3D.new()
        var roof_mesh := BoxMesh.new()
        roof_mesh.size = Vector3(maxf(1.0, size.x - 0.35), 0.18, maxf(1.0, size.z - 0.35))
        roof.mesh = roof_mesh
        roof.position = Vector3(0, size.y * 0.5 + 0.10, 0) if with_collision else center + Vector3(0, size.y * 0.5 + 0.10, 0)
        var roof_mat := StandardMaterial3D.new()
        roof_mat.albedo_color = Color(0.035, 0.045, 0.06)
        roof_mat.roughness = 0.72
        roof.material_override = roof_mat
        body.add_child(roof)
    _building_index += 1

func _surface_into(parent: Node3D, raw: Array, color: Color) -> void:
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
    parent.add_child(node)

func _build_fallback() -> void:
    _clear_generated()
    _clear_indexes()
    _fallback_active = true
    for x in range(-8, 9):
        _road_into(self, [[float(x) * 90.0, -720.0], [float(x) * 90.0, 720.0]], 7.0, "fallback")
    for z in range(-8, 9):
        _road_into(self, [[-720.0, float(z) * 90.0], [720.0, float(z) * 90.0]], 7.0, "fallback")
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
