extends CharacterBody3D
class_name MultiversePlayer

@export var walk_speed := 7.0
@export var sprint_speed := 14.0
@export var jump_velocity := 9.0
@export var gravity := 24.0
@export var mouse_sensitivity := 0.0025

var is_flying := false
var size_level := 0
var health := 100.0
var camera_mode := 0
var _pitch := -0.12
var _yaw := 0.0
var _attack_cooldown := 0.0
var _teleport_cooldown := 0.0
var _dodge_timer := 0.0
var _original_scale := Vector3.ONE

@onready var pivot: Node3D = $CameraPivot
@onready var third_camera: Camera3D = $CameraPivot/ThirdPersonCamera
@onready var first_camera: Camera3D = $CameraPivot/FirstPersonCamera
@onready var body_mesh: MeshInstance3D = $Body
@onready var health_label: Label = $HUD/Health

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _original_scale = scale
    _update_camera()
    _update_health_ui()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _yaw -= event.relative.x * mouse_sensitivity
        _pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, -1.35, 0.85)
        rotation.y = _yaw
        pivot.rotation.x = _pitch
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    _attack_cooldown = maxf(0.0, _attack_cooldown - delta)
    _teleport_cooldown = maxf(0.0, _teleport_cooldown - delta)
    _dodge_timer = maxf(0.0, _dodge_timer - delta)

    if Input.is_action_just_pressed("toggle_camera"):
        camera_mode = 1 - camera_mode
        _update_camera()
    if Input.is_action_just_pressed("ability_flight"):
        is_flying = not is_flying
    if Input.is_action_just_pressed("ability_size_down"):
        _change_size(-1)
    if Input.is_action_just_pressed("ability_size_up"):
        _change_size(1)
    if Input.is_action_just_pressed("ability_teleport"):
        _teleport()
    if Input.is_action_just_pressed("attack"):
        _attack()
    if Input.is_action_just_pressed("dodge"):
        _dodge_timer = 0.22

    # InputMap uses move_forward/move_back for the physical W/S direction.
    # Input.get_vector returns +Y for its second positive action, so forward
    # must be the negative Y side of the vector before applying -Z forward.
    var input_vec := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
    var direction := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
    var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
    speed *= lerpf(0.55, 1.35, inverse_lerp(-2.0, 2.0, size_level))

    if is_flying:
        var fly_dir := direction
        if Input.is_action_pressed("jump"):
            fly_dir.y += 1.0
        velocity = fly_dir.normalized() * speed
    else:
        if not is_on_floor():
            velocity.y -= gravity * delta
        else:
            if Input.is_action_just_pressed("jump"):
                velocity.y = jump_velocity
            else:
                velocity.y = -0.5
        velocity.x = move_toward(velocity.x, direction.x * speed, 35.0 * delta)
        velocity.z = move_toward(velocity.z, direction.z * speed, 35.0 * delta)

    if _dodge_timer > 0.0 and direction.length_squared() > 0.01:
        velocity.x = direction.x * speed * 2.5
        velocity.z = direction.z * speed * 2.5

    move_and_slide()

func _change_size(step: int) -> void:
    size_level = clampi(size_level + step, -2, 2)
    var target := pow(1.8, float(size_level))
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", _original_scale * target, 0.3)
    $SizeIndicator.text = "SIZE: " + ("TINY" if size_level < -1 else "SMALL" if size_level < 0 else "NORMAL" if size_level == 0 else "LARGE" if size_level == 1 else "GIANT")

func _teleport() -> void:
    if _teleport_cooldown > 0.0:
        return
    _teleport_cooldown = 1.25
    var distance := 12.0 if size_level <= 0 else 18.0
    var target := global_position + -global_transform.basis.z * distance
    var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, target + Vector3.UP)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        global_position = target
    else:
        global_position = hit.position - -global_transform.basis.z * 1.5
    $TeleportFlash.emitting = true

func _attack() -> void:
    if _attack_cooldown > 0.0:
        return
    _attack_cooldown = 0.45
    var origin := global_position + Vector3.UP * (1.2 * scale.y)
    var forward := -global_transform.basis.z
    var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * (4.0 * maxf(scale.x, 0.25)))
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.collider.has_method("take_damage"):
        hit.collider.take_damage(20.0)

func take_damage(amount: float) -> void:
    if Input.is_action_pressed("block"):
        amount *= 0.25
    health = maxf(0.0, health - amount)
    _update_health_ui()
    if health <= 0.0:
        global_position = Vector3(0, 2, 8)
        health = 100.0
        _update_health_ui()

func _update_camera() -> void:
    third_camera.current = camera_mode == 0
    first_camera.current = camera_mode == 1

func _update_health_ui() -> void:
    if health_label:
        health_label.text = "HEALTH  %03d" % int(health)
