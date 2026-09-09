extends Node3D
class_name RealisticActorMotion

## Procedural secondary-motion layer for the superhero body.
## This is deliberately separate from the movement controller so animation
## can be replaced by a proper skeletal rig later without rewriting gameplay.

@export var breathing_speed := 1.7
@export var breathing_amount := 0.018
@export var weight_shift_speed := 0.9
@export var head_follow_strength := 0.16
@export var arm_swing_strength := 0.10
@export var hand_motion_strength := 0.045
@export var landing_recovery := 7.0
@export var blink_interval_min := 2.4
@export var blink_interval_max := 5.2

var _time := 0.0
var _blink_timer := 3.4
var _blink_phase := 0.0
var _was_grounded := true
var _last_vertical_speed := 0.0
var _base_scale := Vector3.ONE
var _base_positions: Dictionary = {}
var _base_rotations: Dictionary = {}

var _actor: CharacterBody3D
var _body: Node3D
var _head: Node3D
var _left_eye: Node3D
var _right_eye: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_hand: Node3D
var _right_hand: Node3D

func _ready() -> void:
    _actor = get_parent() as CharacterBody3D
    if _actor == null:
        return
    _body = _actor.get_node_or_null("Body") as Node3D
    _head = _actor.get_node_or_null("Head") as Node3D
    _left_eye = _actor.get_node_or_null("Eye_L") as Node3D
    _right_eye = _actor.get_node_or_null("Eye_R") as Node3D
    _left_arm = _actor.get_node_or_null("UpperArm_L") as Node3D
    _right_arm = _actor.get_node_or_null("UpperArm_R") as Node3D
    _left_hand = _actor.get_node_or_null("Hand_L") as Node3D
    _right_hand = _actor.get_node_or_null("Hand_R") as Node3D

    _cache(_body)
    _cache(_head)
    _cache(_left_arm)
    _cache(_right_arm)
    _cache(_left_hand)
    _cache(_right_hand)

    _blink_timer = randf_range(blink_interval_min, blink_interval_max)

func _cache(node: Node3D) -> void:
    if node == null:
        return
    _base_positions[node] = node.position
    _base_rotations[node] = node.rotation

func _physics_process(delta: float) -> void:
    if _actor == null:
        return

    _time += delta
    _blink_timer -= delta
    if _blink_timer <= 0.0:
        _blink_timer = randf_range(blink_interval_min, blink_interval_max)
        _blink_phase = 1.0
    _blink_phase = move_toward(_blink_phase, 0.0, delta * 7.5)

    var horizontal_velocity := Vector3(_actor.velocity.x, 0.0, _actor.velocity.z)
    var speed := horizontal_velocity.length()
    var max_speed := maxf(float(_actor.get("sprint_speed")), 1.0)
    var movement := clampf(speed / max_speed, 0.0, 1.0)
    var flying := bool(_actor.get("is_flying"))
    var size_level := int(_actor.get("size_level"))

    _animate_breathing(delta, flying, movement)
    _animate_weight_shift(movement, flying, size_level)
    _animate_limbs(movement, flying)
    _animate_head(horizontal_velocity, flying, delta)
    _animate_hands(movement, flying)
    _animate_blink()
    _animate_landing(delta)

    _was_grounded = _actor.is_on_floor()
    _last_vertical_speed = _actor.velocity.y

func _animate_breathing(_delta: float, flying: bool, movement: float) -> void:
    if _body == null or not _base_positions.has(_body):
        return
    var phase := sin(_time * breathing_speed * TAU)
    var amplitude := breathing_amount * (1.0 - movement * 0.55)
    if flying:
        amplitude *= 0.65
    var base: Vector3 = _base_positions[_body]
    _body.position = base + Vector3(0.0, phase * amplitude, phase * amplitude * 0.18)

func _animate_weight_shift(movement: float, flying: bool, size_level: int) -> void:
    if _body == null or not _base_rotations.has(_body):
        return
    var base: Vector3 = _base_rotations[_body]
    if flying:
        _body.rotation = base + Vector3(deg_to_rad(-7.0), 0.0, deg_to_rad(-3.0))
        return
    var shift := sin(_time * weight_shift_speed * TAU) * (1.0 - movement) * 0.025
    var giant := clampf(float(size_level) * 0.025, -0.04, 0.04)
    _body.rotation = base + Vector3(0.0, shift, -shift * 0.7 + giant)

func _animate_limbs(movement: float, flying: bool) -> void:
    if _left_arm == null or _right_arm == null:
        return
    var stride := sin(_time * (4.5 + movement * 3.0))
    var swing := stride * arm_swing_strength * movement
    if flying:
        swing = sin(_time * 2.0) * 0.025
    _apply_rotation_offset(_left_arm, Vector3(swing, 0.0, -swing * 0.25))
    _apply_rotation_offset(_right_arm, Vector3(-swing, 0.0, swing * 0.25))

func _animate_head(horizontal_velocity: Vector3, flying: bool, delta: float) -> void:
    if _head == null or not _base_rotations.has(_head):
        return
    var target_yaw := 0.0
    var target_pitch := 0.0
    if horizontal_velocity.length_squared() > 1.0:
        var local_dir := _actor.global_transform.basis.inverse() * horizontal_velocity.normalized()
        target_yaw = clampf(atan2(local_dir.x, -local_dir.z) * head_follow_strength, -0.18, 0.18)
    if flying:
        target_pitch = -0.08
    var base: Vector3 = _base_rotations[_head]
    var desired := base + Vector3(target_pitch, target_yaw, 0.0)
    _head.rotation = _head.rotation.lerp(desired, minf(1.0, delta * 5.0))

func _animate_hands(movement: float, flying: bool) -> void:
    var pulse := sin(_time * 5.8) * hand_motion_strength * (0.35 + movement * 0.65)
    if flying:
        pulse *= 0.55
    _apply_position_offset(_left_hand, Vector3(0.0, pulse, 0.0))
    _apply_position_offset(_right_hand, Vector3(0.0, -pulse, 0.0))

func _animate_blink() -> void:
    var scale_y := 1.0
    if _blink_phase > 0.0:
        scale_y = 0.12 + absf(_blink_phase - 0.5) * 0.25
    _apply_eye_scale(_left_eye, scale_y)
    _apply_eye_scale(_right_eye, scale_y)

func _apply_eye_scale(node: Node3D, y_scale: float) -> void:
    if node == null:
        return
    node.scale.y = y_scale

func _animate_landing(delta: float) -> void:
    if _body == null:
        return
    var landing := 0.0
    if _actor.is_on_floor() and not _was_grounded and _last_vertical_speed < -8.0:
        landing = clampf(absf(_last_vertical_speed) / 45.0, 0.0, 0.16)
    if landing > 0.0:
        _base_scale = _body.scale
        _body.scale = _body.scale * Vector3(1.0 + landing * 0.35, 1.0 - landing, 1.0 + landing * 0.35)
    else:
        _body.scale = _body.scale.lerp(_base_scale, minf(1.0, delta * landing_recovery))

func _apply_rotation_offset(node: Node3D, offset: Vector3) -> void:
    if node == null or not _base_rotations.has(node):
        return
    node.rotation = _base_rotations[node] + offset

func _apply_position_offset(node: Node3D, offset: Vector3) -> void:
    if node == null or not _base_positions.has(node):
        return
    node.position = _base_positions[node] + offset
