extends Node3D
## Presentation layer: readable sky, sun cycle, color grading and lightweight city dressing.

@export var day_length_seconds := 900.0
@export var start_time := 16.5
@export var animate_time := true
@export var build_dressing := true
@export var max_street_lights := 120
@export var max_trees := 90

var _time := 16.5
var _dressing_built := false

func _ready() -> void:
    _time = start_time
    _apply_lighting()
    if build_dressing:
        call_deferred("_build_dressing")

func _process(delta: float) -> void:
    if animate_time:
        _time = fmod(_time + delta * 24.0 / day_length_seconds, 24.0)
        _apply_lighting()

func _apply_lighting() -> void:
    var daylight := clampf(sin((_time - 6.0) / 24.0 * TAU), 0.0, 1.0)
    var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
    var environment_node := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
    if sun:
        var angle := (_time - 6.0) / 24.0 * TAU
        sun.rotation_degrees = Vector3(-18.0 - daylight * 54.0, -35.0 + sin(angle) * 20.0, 0.0)
        sun.light_energy = lerpf(0.28, 1.55, daylight)
        sun.light_color = Color(1.0, 0.72 + daylight * 0.25, 0.58 + daylight * 0.4)
    if environment_node and environment_node.environment:
        environment_node.environment.ambient_light_energy = lerpf(0.38, 1.05, daylight)
        environment_node.environment.background_energy_multiplier = lerpf(0.42, 0.95, daylight)
        environment_node.environment.fog_density = lerpf(0.0022, 0.0007, daylight)
        environment_node.environment.fog_light_color = Color(0.25 + daylight * 0.15, 0.34 + daylight * 0.16, 0.50 + daylight * 0.16)

func _build_dressing() -> void:
    if _dressing_built:
        return
    _dressing_built = true
    var geography := get_parent().get_node_or_null("RecordedGeography")
    if geography:
        _dress_roads(geography)
    _dress_trees()
    _build_landmark()

func _dress_roads(geography: Node) -> void:
    var count := 0
    for road in geography.get_children():
        if count >= max_street_lights:
            break
        if not road is MeshInstance3D or not road.name.begins_with("Road_"):
            continue
        if road.name.contains("rail"):
            continue
        if int(abs(road.position.x + road.position.z)) % 2 != 0:
            continue
        _make_street_light(road.position)
        count += 1

func _make_street_light(pos: Vector3) -> void:
    var pole := MeshInstance3D.new()
    pole.name = "StreetLight"
    var pole_mesh := CylinderMesh.new()
    pole_mesh.top_radius = 0.055
    pole_mesh.bottom_radius = 0.09
    pole_mesh.height = 4.2
    pole.mesh = pole_mesh
    pole.position = pos + Vector3(0, 2.1, 2.8)
    var pole_mat := StandardMaterial3D.new()
    pole_mat.albedo_color = Color(0.035, 0.045, 0.06)
    pole_mat.roughness = 0.5
    pole.material_override = pole_mat
    add_child(pole)

    var lamp := MeshInstance3D.new()
    var lamp_mesh := SphereMesh.new()
    lamp_mesh.radius = 0.16
    lamp_mesh.height = 0.32
    lamp.mesh = lamp_mesh
    lamp.position = pos + Vector3(0, 4.25, 2.8)
    var lamp_mat := StandardMaterial3D.new()
    lamp_mat.albedo_color = Color(1.0, 0.58, 0.18)
    lamp_mat.emission_enabled = true
    lamp_mat.emission = Color(1.0, 0.32, 0.06)
    lamp_mat.emission_energy_multiplier = 3.0
    lamp.material_override = lamp_mat
    add_child(lamp)

func _dress_trees() -> void:
    var space := get_world_3d().direct_space_state
    var placed := 0
    for x in range(-720, 721, 80):
        for z in range(-720, 721, 80):
            if placed >= max_trees:
                return
            if (x * 17 + z * 31) % 5 != 0:
                continue
            var query := PhysicsRayQueryParameters3D.create(Vector3(x, 120, z), Vector3(x, -5, z))
            var hit := space.intersect_ray(query)
            if hit.is_empty() or hit.collider.name != "Ground":
                continue
            _make_tree(Vector3(x, hit.position.y, z), 0.8 + fposmod(absf(sin(float(x + z))), 0.7))
            placed += 1

func _make_tree(pos: Vector3, s: float) -> void:
    var root := Node3D.new()
    root.name = "Tree"
    root.position = pos
    root.scale = Vector3.ONE * s
    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.18
    trunk_mesh.bottom_radius = 0.26
    trunk_mesh.height = 2.2
    trunk.mesh = trunk_mesh
    trunk.position.y = 1.1
    var trunk_mat := StandardMaterial3D.new()
    trunk_mat.albedo_color = Color(0.20, 0.10, 0.055)
    trunk_mat.roughness = 0.9
    trunk.material_override = trunk_mat
    root.add_child(trunk)
    var crown := MeshInstance3D.new()
    var crown_mesh := SphereMesh.new()
    crown_mesh.radius = 1.15
    crown_mesh.height = 2.3
    crown.mesh = crown_mesh
    crown.position.y = 2.65
    var crown_mat := StandardMaterial3D.new()
    crown_mat.albedo_color = Color(0.055, 0.28, 0.10)
    crown_mat.roughness = 0.92
    crown.material_override = crown_mat
    root.add_child(crown)
    add_child(root)

func _build_landmark() -> void:
    var marker := Label3D.new()
    marker.name = "WorldIdentity"
    marker.position = Vector3(0, 4.5, 10)
    marker.text = "FEDERAL WAY / TACOMA\nOPEN-WORLD PROTOTYPE"
    marker.font_size = 42
    marker.outline_size = 9
    marker.modulate = Color(0.25, 0.9, 1.0)
    add_child(marker)
