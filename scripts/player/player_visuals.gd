extends Node3D
class_name MultiversePlayerVisuals

## High-detail presentation layer for the original hero.
## Keeps gameplay/controller ownership in player.gd while adding a more grounded,
## physically believable silhouette, material response, facial presence and motion.

@export var idle_breath_speed := 1.55
@export var walk_cycle_speed := 7.2
@export var run_cycle_speed := 10.8
@export var arm_swing := 0.34
@export var leg_swing := 0.44
@export var torso_lean := 0.10
@export var landing_squash := 0.08
@export var secondary_motion := 0.035

var _time := 0.0
var _impact := 0.0
var _last_vertical_speed := 0.0
var _last_grounded := true
var _base_positions: Dictionary = {}
var _base_rotations: Dictionary = {}
var _base_scales: Dictionary = {}
var _detail_nodes: Array[Node3D] = []

@onready var actor: CharacterBody3D = get_parent()

func _ready() -> void:
    _cache_bases()
    _upgrade_materials()
    _add_realism_accents()

func _cache_bases() -> void:
    for child in actor.get_children():
        if child is Node3D:
            _base_positions[child.name] = child.position
            _base_rotations[child.name] = child.rotation
            _base_scales[child.name] = child.scale

func _upgrade_materials() -> void:
    for child in actor.get_children():
        if not child is MeshInstance3D:
            continue
        var mesh_instance := child as MeshInstance3D
        var source := mesh_instance.material_override
        if source is StandardMaterial3D:
            var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
            material.roughness = clampf(material.roughness, 0.42, 0.88)
            material.metallic = 0.0
            material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
            material.specular = 0.42
            mesh_instance.material_override = material

    _tune_skin("Body", 0.16, 0.36, 0.07, 0.52)
    _tune_skin("Chest", 0.17, 0.39, 0.075, 0.50)
    _tune_skin("Abdomen", 0.14, 0.33, 0.055, 0.55)
    _tune_skin("Neck", 0.13, 0.31, 0.05, 0.58)
    _tune_skin("Head", 0.16, 0.35, 0.065, 0.48)
    _tune_skin("Jaw", 0.13, 0.30, 0.05, 0.52)
    for name in ["Shoulder_L", "Shoulder_R", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R", "Calf_L", "Calf_R"]:
        _tune_skin(name, 0.15, 0.34, 0.06, 0.54)

func _tune_skin(node_name: String, r: float, g: float, b: float, roughness: float) -> void:
    var node := actor.get_node_or_null(node_name) as MeshInstance3D
    if node == null:
        return
    var material := node.material_override as StandardMaterial3D
    if material == null:
        return
    material.albedo_color = Color(r, g, b, 1.0)
    material.roughness = roughness
    material.specular = 0.44

func _add_realism_accents() -> void:
    var root := actor.get_node_or_null("RealismDetails") as Node3D
    if root == null:
        root = Node3D.new()
        root.name = "RealismDetails"
        actor.add_child(root)

    # Subtle anatomical definition layers. They sit close to the existing body
    # rather than replacing gameplay collision or the current primitive rig.
    _add_detail(root, "Deltoid_L", Vector3(-1.18, 3.91, -0.07), Vector3(0.48, 0.42, 0.40), Color(0.17, 0.38, 0.075))
    _add_detail(root, "Deltoid_R", Vector3(1.18, 3.91, -0.07), Vector3(0.48, 0.42, 0.40), Color(0.17, 0.38, 0.075))
    _add_detail(root, "Bicep_L", Vector3(-1.48, 3.18, -0.19), Vector3(0.30, 0.52, 0.30), Color(0.15, 0.34, 0.065))
    _add_detail(root, "Bicep_R", Vector3(1.48, 3.18, -0.19), Vector3(0.30, 0.52, 0.30), Color(0.15, 0.34, 0.065))
    _add_detail(root, "ForearmFlexor_L", Vector3(-1.72, 2.48, -0.22), Vector3(0.28, 0.52, 0.28), Color(0.16, 0.36, 0.07))
    _add_detail(root, "ForearmFlexor_R", Vector3(1.72, 2.48, -0.22), Vector3(0.28, 0.52, 0.28), Color(0.16, 0.36, 0.07))
    _add_detail(root, "AbsUpper_L", Vector3(-0.29, 2.94, -0.69), Vector3(0.30, 0.28, 0.10), Color(0.105, 0.27, 0.045))
    _add_detail(root, "AbsUpper_R", Vector3(0.29, 2.94, -0.69), Vector3(0.30, 0.28, 0.10), Color(0.105, 0.27, 0.045))
    _add_detail(root, "AbsLower_L", Vector3(-0.27, 2.54, -0.68), Vector3(0.27, 0.25, 0.09), Color(0.10, 0.26, 0.043))
    _add_detail(root, "AbsLower_R", Vector3(0.27, 2.54, -0.68), Vector3(0.27, 0.25, 0.09), Color(0.10, 0.26, 0.043))
    _add_detail(root, "Knee_L", Vector3(-0.63, 0.16, -0.43), Vector3(0.34, 0.24, 0.22), Color(0.13, 0.31, 0.055))
    _add_detail(root, "Knee_R", Vector3(0.63, 0.16, -0.43), Vector3(0.34, 0.24, 0.22), Color(0.13, 0.31, 0.055))

    # Brow/cheek planes give the face a stronger silhouette under directional light.
    _add_detail(root, "Cheek_L", Vector3(-0.38, 5.00, -0.61), Vector3(0.25, 0.20, 0.10), Color(0.145, 0.33, 0.06))
    _add_detail(root, "Cheek_R", Vector3(0.38, 5.00, -0.61), Vector3(0.25, 0.20, 0.10), Color(0.145, 0.33, 0.06))

    # Tiny catchlights make the existing eyes read as wet/reflective rather than flat emissive spheres.
    _add_detail(root, "EyeCatch_L", Vector3(-0.276, 5.245, -0.685), Vector3(0.025, 0.025, 0.012), Color(1.0, 0.92, 0.72), true)
    _add_detail(root, "EyeCatch_R", Vector3(0.276, 5.245, -0.685), Vector3(0.025, 0.025, 0.012), Color(1.0, 0.92, 0.72), true)

func _add_detail(root: Node3D, node_name: String, position: Vector3, scale_value: Vector3, color: Color, bright := false) -> void:
    if root.get_node_or_null(node_name) != null:
        return
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = node_name
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh.radial_segments = 24
    mesh.rings = 12
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.38 if bright else 0.56
    material.specular = 0.52
    if bright:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 0.8
    mesh_instance.material_override = material
    mesh_instance.position = position
    mesh_instance.scale = scale_value
    root.add_child(mesh_instance)
    _detail_nodes.append(mesh_instance)

func _process(delta: float) -> void:
    if not is_instance_valid(actor):
        return
    _time += delta
    _impact = move_toward(_impact, 0.0, delta * 4.5)

    var planar := Vector2(actor.velocity.x, actor.velocity.z)
    var speed := planar.length()
    var moving := speed > 0.35
    var grounded := actor.is_on_floor()
    var flying := actor.get("is_flying") == true
    var size_level := int(actor.get("size_level"))

    if grounded and not _last_grounded and _last_vertical_speed < -8.0:
        _impact = clampf(absf(_last_vertical_speed) / 32.0, 0.0, 1.0)
    _last_grounded = grounded
    _last_vertical_speed = actor.velocity.y

    var cycle_speed := run_cycle_speed if speed > 13.0 else walk_cycle_speed
    var cycle := _time * cycle_speed
    var stride := clampf(speed / 16.0, 0.0, 1.0)
    var motion_blend := clampf(speed / 5.0, 0.0, 1.0)

    var chest := actor.get_node_or_null("Chest") as Node3D
    var abdomen := actor.get_node_or_null("Abdomen") as Node3D
    var head := actor.get_node_or_null("Head") as Node3D
    var neck := actor.get_node_or_null("Neck") as Node3D
    var upper_l := actor.get_node_or_null("UpperArm_L") as Node3D
    var upper_r := actor.get_node_or_null("UpperArm_R") as Node3D
    var fore_l := actor.get_node_or_null("Forearm_L") as Node3D
    var fore_r := actor.get_node_or_null("Forearm_R") as Node3D
    var thigh_l := actor.get_node_or_null("Thigh_L") as Node3D
    var thigh_r := actor.get_node_or_null("Thigh_R") as Node3D
    var calf_l := actor.get_node_or_null("Calf_L") as Node3D
    var calf_r := actor.get_node_or_null("Calf_R") as Node3D
    var hand_l := actor.get_node_or_null("Hand_L") as Node3D
    var hand_r := actor.get_node_or_null("Hand_R") as Node3D

    var breath := sin(_time * idle_breath_speed) * 0.022
    if chest:
        chest.position = _base_positions.get("Chest", chest.position) + Vector3(0, breath * 0.45, breath * 0.18)
        chest.rotation = _base_rotations.get("Chest", chest.rotation)
        chest.rotation.x += breath * 0.55
        chest.scale = _base_scales.get("Chest", chest.scale) * Vector3(1.0 + absf(breath) * 0.45, 1.0 + breath * 0.22, 1.0 + absf(breath) * 0.20)
    if abdomen:
        abdomen.position = _base_positions.get("Abdomen", abdomen.position) + Vector3(0, breath * 0.24, 0)
        abdomen.rotation.x = lerpf(abdomen.rotation.x, breath * 0.32, delta * 5.0)

    if flying:
        _set_rot(upper_l, -0.30, 0.0, -0.20)
        _set_rot(upper_r, -0.30, 0.0, 0.20)
        _set_rot(fore_l, -0.14, 0.0, -0.08)
        _set_rot(fore_r, -0.14, 0.0, 0.08)
        _set_rot(thigh_l, 0.30, 0.0, -0.05)
        _set_rot(thigh_r, 0.30, 0.0, 0.05)
        _set_rot(calf_l, -0.24, 0.0, 0.0)
        _set_rot(calf_r, -0.24, 0.0, 0.0)
        if chest:
            chest.rotation.x = lerpf(chest.rotation.x, -0.18, delta * 5.0)
        if head:
            head.rotation.x = lerpf(head.rotation.x, 0.08, delta * 5.0)
    elif moving:
        var wave := sin(cycle) * stride
        var opposite := sin(cycle + PI) * stride
        _set_rot(upper_l, opposite * arm_swing, 0.0, -0.15)
        _set_rot(upper_r, wave * arm_swing, 0.0, 0.15)
        _set_rot(fore_l, absf(wave) * 0.14, 0.0, 0.0)
        _set_rot(fore_r, absf(opposite) * 0.14, 0.0, 0.0)
        _set_rot(thigh_l, wave * leg_swing, 0.0, 0.0)
        _set_rot(thigh_r, opposite * leg_swing, 0.0, 0.0)
        _set_rot(calf_l, maxf(0.0, -wave) * 0.24, 0.0, 0.0)
        _set_rot(calf_r, maxf(0.0, -opposite) * 0.24, 0.0, 0.0)
        if chest:
            chest.rotation.z = lerpf(chest.rotation.z, -actor.velocity.x * torso_lean / 16.0, delta * 7.0)
        if abdomen:
            abdomen.rotation.z = lerpf(abdomen.rotation.z, -actor.velocity.x * torso_lean * 0.55 / 16.0, delta * 7.0)
        if neck:
            neck.rotation.z = lerpf(neck.rotation.z, actor.velocity.x * 0.020, delta * 6.0)
        if head:
            head.rotation.z = lerpf(head.rotation.z, actor.velocity.x * 0.032, delta * 5.0)
    else:
        var sway := sin(_time * 1.15) * 0.020
        _set_rot(upper_l, sway, 0.0, -0.15)
        _set_rot(upper_r, -sway, 0.0, 0.15)
        _set_rot(fore_l, -0.035 + sway * 0.35, 0.0, 0.0)
        _set_rot(fore_r, -0.035 - sway * 0.35, 0.0, 0.0)
        _set_rot(thigh_l, -0.022 + sway, 0.0, 0.0)
        _set_rot(thigh_r, -0.022 - sway, 0.0, 0.0)
        _set_rot(calf_l, 0.018, 0.0, 0.0)
        _set_rot(calf_r, 0.018, 0.0, 0.0)

    # Secondary motion sells mass: larger, faster characters settle more slowly.
    var secondary := sin(_time * 2.2) * secondary_motion * (1.0 - motion_blend * 0.65)
    if neck:
        neck.rotation.x += secondary * 0.20
    if head:
        head.rotation.x += secondary * 0.28
        head.rotation.y += sin(_time * 1.7) * secondary_motion * 0.12
    if hand_l:
        hand_l.rotation.y = lerpf(hand_l.rotation.y, sin(_time * 1.05) * 0.022, delta * 4.0)
    if hand_r:
        hand_r.rotation.y = lerpf(hand_r.rotation.y, -sin(_time * 1.05) * 0.022, delta * 4.0)

    var squash := 1.0 - _impact * landing_squash
    if chest:
        var chest_base: Vector3 = _base_scales.get("Chest", chest.scale)
        chest.scale = chest_base * Vector3(1.0 + _impact * 0.025, squash, 1.0 + _impact * 0.025)
    if abdomen:
        var abdomen_base: Vector3 = _base_scales.get("Abdomen", abdomen.scale)
        abdomen.scale = abdomen_base * Vector3(1.0 + _impact * 0.018, squash, 1.0)

    # At giant scale, preserve a heavy stance rather than a proportionally tiny idle.
    if size_level >= 2 and grounded and not moving:
        if thigh_l:
            thigh_l.rotation.z = lerpf(thigh_l.rotation.z, -0.025, delta * 2.5)
        if thigh_r:
            thigh_r.rotation.z = lerpf(thigh_r.rotation.z, 0.025, delta * 2.5)

func _set_rot(node: Node3D, x: float, y: float, z: float) -> void:
    if node == null:
        return
    var base: Vector3 = _base_rotations.get(node.name, node.rotation)
    node.rotation = base + Vector3(x, y, z)
