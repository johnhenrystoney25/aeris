extends Node3D
class_name BuildingIdentityDressing

@export var region_file := "res://data/geography/federal_way_tacoma_region.json"
@export var scan_interval := 0.75
@export var max_windows_per_building := 36
@export var show_named_building_labels := true

var _timer := 0.0
var _named_buildings: Array = []
var _decorated: Dictionary = {}

func _ready() -> void:
    _load_named_buildings()
    call_deferred("_scan_buildings")

func _process(delta: float) -> void:
    _timer -= delta
    if _timer <= 0.0:
        _timer = scan_interval
        _scan_buildings()

func _load_named_buildings() -> void:
    if not FileAccess.file_exists(region_file): return
    var data = JSON.parse_string(FileAccess.get_file_as_string(region_file))
    if typeof(data) != TYPE_DICTIONARY: return
    for building in data.get("buildings", []):
        var name := str(building.get("name", "")).strip_edges()
        var polygon: Array = building.get("polygon", [])
        if name.is_empty() or polygon.size() < 3: continue
        var center := Vector3.ZERO
        for p in polygon:
            if p is Array and p.size() >= 2:
                center += Vector3(float(p[0]), 0.0, float(p[1]))
        center /= float(polygon.size())
        _named_buildings.append({"name": name, "center": center})

func _scan_buildings() -> void:
    var root := get_parent()
    if root == null: return
    for chunk in root.get_children():
        for child in chunk.get_children():
            if not child is MeshInstance3D: continue
            if not str(child.name).begins_with("BuildingVisual_"): continue
            var id := child.get_instance_id()
            if _decorated.has(id): continue
            _decorate_building(child)
            _decorated[id] = true

func _decorate_building(building: MeshInstance3D) -> void:
    var size := building.get_aabb().size
    var height := maxf(size.y, 4.0)
    var footprint := Vector2(maxf(size.x, 3.0), maxf(size.z, 3.0))
    var facade := Node3D.new()
    facade.name = "FacadeIdentity"
    building.add_child(facade)

    var floors := clampi(int(round(height / 3.1)), 1, 12)
    var columns := clampi(int(round(maxf(footprint.x, footprint.y) / 5.5)), 1, 9)
    var count := 0
    for floor in range(floors):
        var y := 1.25 + float(floor) * 3.0
        for col in range(columns):
            if count >= max_windows_per_building: break
            var x := lerpf(-footprint.x * 0.42, footprint.x * 0.42, float(col) / float(maxi(columns - 1, 1)))
            _window(facade, Vector3(x, y, -footprint.y * 0.505), Vector3(0.95, 1.25, 0.08))
            count += 1
            if footprint.y > 9.0 and count < max_windows_per_building:
                _window(facade, Vector3(footprint.x * 0.505, y, x), Vector3(0.08, 1.25, 0.95), PI * 0.5)
                count += 1

    _entrance(facade, Vector3(0.0, 1.05, -footprint.y * 0.515), minf(2.4, footprint.x * 0.28))
    if height > 12.0:
        _roof_unit(facade, Vector3(footprint.x * 0.20, height + 0.35, footprint.y * 0.10), Vector3(2.0, 0.7, 1.4))
        _roof_unit(facade, Vector3(-footprint.x * 0.22, height + 0.30, -footprint.y * 0.16), Vector3(1.2, 0.55, 1.2))

    if show_named_building_labels:
        var nearest = _nearest_named_building(building.global_position)
        if nearest != null and building.global_position.distance_to(nearest["center"]) < 35.0:
            _label(facade, nearest["name"], Vector3(0.0, minf(height + 1.4, 28.0), -footprint.y * 0.52))

func _window(parent: Node3D, position: Vector3, size: Vector3, yaw := 0.0) -> void:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = position
    node.rotation.y = yaw
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.10, 0.18, 0.23)
    mat.metallic = 0.25
    mat.roughness = 0.22
    mat.emission_enabled = true
    mat.emission = Color(0.025, 0.045, 0.055)
    mat.emission_energy_multiplier = 0.65
    node.material_override = mat
    parent.add_child(node)

func _entrance(parent: Node3D, position: Vector3, width: float) -> void:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(width, 2.2, 0.14)
    node.mesh = mesh
    node.position = position
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.08, 0.09, 0.10)
    mat.metallic = 0.35
    mat.roughness = 0.3
    node.material_override = mat
    parent.add_child(node)

func _roof_unit(parent: Node3D, position: Vector3, size: Vector3) -> void:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = position
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.13, 0.14, 0.15)
    mat.metallic = 0.18
    mat.roughness = 0.72
    node.material_override = mat
    parent.add_child(node)

func _label(parent: Node3D, text_value: String, position: Vector3) -> void:
    var label := Label3D.new()
    label.name = "BuildingIdentity"
    label.text = text_value
    label.position = position
    label.font_size = 28
    label.outline_size = 6
    label.modulate = Color(0.92, 0.95, 1.0, 0.92)
    label.no_depth_test = true
    parent.add_child(label)

func _nearest_named_building(position: Vector3):
    var best = null
    var best_distance := INF
    for item in _named_buildings:
        var distance := position.distance_to(item["center"])
        if distance < best_distance:
            best_distance = distance
            best = item
    return best
