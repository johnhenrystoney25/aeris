extends Node3D
class_name MultiversePlayerVisuals

## Procedural character presentation layer.
## Adds breathing, weight shift, locomotion, sprint lean, landing compression,
## flight posture, and subtle secondary motion without replacing the gameplay controller.

@export var idle_breath_speed := 1.8
@export var walk_cycle_speed := 8.0
@export var run_cycle_speed := 11.5
@export var arm_swing := 0.38
@export var leg_swing := 0.48
@export var torso_lean := 0.12
@export var landing_squash := 0.10

var _time := 0.0
var _impact := 0.0
var _last_vertical_speed := 0.0
var _last_grounded := true
var _base_positions: Dictionary = {}
var _base_rotations: Dictionary = {}
var _base_scales: Dictionary = {}

@onready var actor: CharacterBody3D = get_parent()

func _ready() -> void:
    for child in actor.get_children():
        if child is Node3D:
            _base_positions[child.name] = child.position
            _base_rotations[child.name] = child.rotation
            _base_scales[child.name] = child.scale

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

    var breath := sin(_time * idle_breath_speed) * 0.018
    if chest:
        chest.position = _base_positions.get("Chest", chest.position) + Vector3(0, breath * 0.35, 0)
        chest.rotation = _base_rotations.get("Chest", chest.rotation)
        chest.rotation.x += breath * 0.35
    if abdomen:
        abdomen.position = _base_positions.get("Abdomen", abdomen.position) + Vector3(0, breath * 0.18, 0)

    if flying:
        _set_rot(upper_l, -0.28, 0.0, -0.22)
        _set_rot(upper_r, -0.28, 0.0, 0.22)
        _set_rot(fore_l, -0.12, 0.0, -0.10)
        _set_rot(fore_r, -0.12, 0.0, 0.10)
        _set_rot(thigh_l, 0.28, 0.0, -0.05)
        _set_rot(thigh_r, 0.28, 0.0, 0.05)
        _set_rot(calf_l, -0.22, 0.0, 0.0)
        _set_rot(calf_r, -0.22, 0.0, 0.0)
        if chest:
            chest.rotation.x = lerpf(chest.rotation.x, -0.16, delta * 5.0)
        if head:
            head.rotation.x = lerpf(head.rotation.x, 0.08, delta * 5.0)
    elif moving:
        var wave := sin(cycle) * stride
        var opposite := sin(cycle + PI) * stride
        _set_rot(upper_l, opposite * arm_swing, 0.0, -0.16)
        _set_rot(upper_r, wave * arm_swing, 0.0, 0.16)
        _set_rot(fore_l, absf(wave) * 0.16, 0.0, 0.0)
        _set_rot(fore_r, absf(opposite) * 0.16, 0.0, 0.0)
        _set_rot(thigh_l, wave * leg_swing, 0.0, 0.0)
        _set_rot(thigh_r, opposite * leg_swing, 0.0, 0.0)
        _set_rot(calf_l, maxf(0.0, -wave) * 0.22, 0.0, 0.0)
        _set_rot(calf_r, maxf(0.0, -opposite) * 0.22, 0.0, 0.0)
        if chest:
            chest.rotation.z = lerpf(chest.rotation.z, -actor.velocity.x * torso_lean / 16.0, delta * 7.0)
        if abdomen:
            abdomen.rotation.z = lerpf(abdomen.rotation.z, -actor.velocity.x * torso_lean * 0.55 / 16.0, delta * 7.0)
        if neck:
            neck.rotation.z = lerpf(neck.rotation.z, actor.velocity.x * 0.025, delta * 6.0)
        if head:
            head.rotation.z = lerpf(head.rotation.z, actor.velocity.x * 0.04, delta * 5.0)
    else:
        var sway := sin(_time * 1.25) * 0.018
        _set_rot(upper_l, sway, 0.0, -0.16)
        _set_rot(upper_r, -sway, 0.0, 0.16)
        _set_rot(fore_l, -0.04 + sway * 0.4, 0.0, 0.0)
        _set_rot(fore_r, -0.04 - sway * 0.4, 0.0, 0.0)
        _set_rot(thigh_l, -0.025 + sway, 0.0, 0.0)
        _set_rot(thigh_r, -0.025 - sway, 0.0, 0.0)
        _set_rot(calf_l, 0.02, 0.0, 0.0)
        _set_rot(calf_r, 0.02, 0.0, 0.0)

    if hand_l:
        hand_l.rotation.y = lerpf(hand_l.rotation.y, sin(_time * 1.1) * 0.025, delta * 4.0)
    if hand_r:
        hand_r.rotation.y = lerpf(hand_r.rotation.y, -sin(_time * 1.1) * 0.025, delta * 4.0)

    var squash := 1.0 - _impact * landing_squash
    if chest:
        var chest_base: Vector3 = _base_scales.get("Chest", chest.scale)
        chest.scale = chest_base * Vector3(1.0, squash, 1.0)
    if abdomen:
        var abdomen_base: Vector3 = _base_scales.get("Abdomen", abdomen.scale)
        abdomen.scale = abdomen_base * Vector3(1.0, squash, 1.0)
    if size_level >= 2 and grounded and not moving and head:
        var head_base: Vector3 = _base_positions.get("Head", head.position)
        head.position.y = lerpf(head.position.y, head_base.y + sin(_time * 0.9) * 0.012, delta * 3.0)

func _set_rot(node: Node3D, x: float, y: float, z: float) -> void:
    if node == null:
        return
    var base: Vector3 = _base_rotations.get(node.name, node.rotation)
    node.rotation = base + Vector3(x, y, z)
