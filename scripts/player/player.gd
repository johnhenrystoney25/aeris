extends CharacterBody3D
class_name MultiversePlayer

## High-mobility superhero controller for THE MULTIVERSE.
## Camera-relative movement, reliable floor recovery, readable flight, size-aware physics,
## first/third-person presentation, stamina, boost, super-jump, and combat feedback.

@export var walk_speed := 8.0
@export var sprint_speed := 16.0
@export var flight_speed := 22.0
@export var flight_boost_speed := 48.0
@export var jump_velocity := 12.0
@export var super_jump_velocity := 24.0
@export var gravity := 28.0
@export var mouse_sensitivity := 0.0025
@export var max_stamina := 100.0

var is_flying := false
var size_level := 0
var health := 100.0
var stamina := 100.0
var camera_mode := 0
var _pitch := -0.12
var _yaw := 0.0
var _attack_cooldown := 0.0
var _teleport_cooldown := 0.0
var _dodge_timer := 0.0
var _boost_timer := 0.0
var _original_scale := Vector3.ONE
var _last_safe_position := Vector3.ZERO

@onready var pivot: Node3D = $CameraPivot
@onready var third_camera: Camera3D = $CameraPivot/ThirdPersonCamera
@onready var first_camera: Camera3D = $CameraPivot/FirstPersonCamera
@onready var body_mesh: MeshInstance3D = $Body
@onready var health_label: Label = $HUD/Health
@onready var status_label: Label = $HUD/Status
@onready var speed_label: Label = $HUD/Speed
@onready var crosshair: Label = $HUD/Crosshair
@onready var flight_fx: GPUParticles3D = $FlightFX

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _original_scale = scale
    _last_safe_position = global_position
    floor_snap_length = 0.6
    floor_max_angle = deg_to_rad(55.0)
    up_direction = Vector3.UP
    _update_camera()
    _update_health_ui()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _yaw -= event.relative.x * mouse_sensitivity
        # Mouse up = camera up. This is deliberately not inverted.
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
    _boost_timer = maxf(0.0, _boost_timer - delta)
    stamina = minf(max_stamina, stamina + (24.0 if not is_flying else 12.0) * delta)

    if Input.is_action_just_pressed("toggle_camera"):
        camera_mode = 1 - camera_mode
        _update_camera()
    if Input.is_action_just_pressed("ability_flight"):
        _toggle_flight()
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
    if Input.is_action_just_pressed("super_jump") and not is_flying:
        _super_jump()
    if Input.is_action_pressed("flight_boost") and is_flying and stamina > 4.0:
        _boost_timer = 0.2
        stamina -= 18.0 * delta

    var input_vec := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
    var camera_basis := pivot.global_transform.basis
    var forward := -camera_basis.z
    var right := camera_basis.x
    forward.y = 0.0
    right.y = 0.0
    forward = forward.normalized()
    right = right.normalized()
    var direction := (right * input_vec.x + forward * -input_vec.y).normalized()
    var size_multiplier := lerpf(0.55, 1.35, inverse_lerp(-2.0, 2.0, size_level))
    var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
    speed *= size_multiplier

    if is_flying:
        _fly(delta, direction, speed)
    else:
        _walk(delta, direction, speed)

    move_and_slide()
    _recover_if_fallen()
    _update_motion_ui()

func _walk(delta: float, direction: Vector3, speed: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity * lerpf(0.8, 1.5, inverse_lerp(-2.0, 2.0, size_level))
    else:
        velocity.y = -0.8
    velocity.x = move_toward(velocity.x, direction.x * speed, 42.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, 42.0 * delta)
    if _dodge_timer > 0.0 and direction.length_squared() > 0.01:
        velocity.x = direction.x * speed * 2.7
        velocity.z = direction.z * speed * 2.7

func _fly(delta: float, direction: Vector3, speed: float) -> void:
    var look_dir := -pivot.global_transform.basis.z.normalized()
    var vertical := 0.0
    if Input.is_action_pressed("jump"):
        vertical += 1.0
    if Input.is_action_pressed("flight_down"):
        vertical -= 1.0
    if absf(vertical) < 0.1 and absf(look_dir.y) > 0.35 and direction.length_squared() > 0.01:
        vertical = look_dir.y * 0.65
    var fly_dir := direction + Vector3.UP * vertical
    if fly_dir.length_squared() > 0.01:
        fly_dir = fly_dir.normalized()
    var actual_speed := flight_boost_speed if _boost_timer > 0.0 else flight_speed
    actual_speed *= lerpf(0.6, 1.4, inverse_lerp(-2.0, 2.0, size_level))
    velocity = velocity.lerp(fly_dir * actual_speed, minf(1.0, delta * 7.0))
    if fly_dir.length_squared() > 0.01:
        rotation.y = lerp_angle(rotation.y, atan2(-fly_dir.x, -fly_dir.z), minf(1.0, delta * 5.0))
    flight_fx.emitting = true

func _toggle_flight() -> void:
    is_flying = not is_flying
    if is_flying:
        velocity.y = maxf(velocity.y, 3.0)
        _update_status_ui("FLIGHT ONLINE  |  SPACE UP  CTRL DOWN  SHIFT BOOST")
    else:
        flight_fx.emitting = false
        _update_status_ui("FLIGHT OFF")

func _super_jump() -> void:
    if stamina < 20.0:
        _update_status_ui("STAMINA LOW")
        return
    stamina -= 20.0
    velocity.y = super_jump_velocity * lerpf(0.8, 1.5, inverse_lerp(-2.0, 2.0, size_level))
    _update_status_ui("SUPER JUMP")

func _change_size(step: int) -> void:
    size_level = clampi(size_level + step, -2, 2)
    var target := pow(1.8, float(size_level))
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", _original_scale * target, 0.3)
    $SizeIndicator.text = "SIZE  " + ("TINY" if size_level < -1 else "SMALL" if size_level < 0 else "NORMAL" if size_level == 0 else "LARGE" if size_level == 1 else "GIANT")
    _update_status_ui("SIZE SHIFT")

func _teleport() -> void:
    if _teleport_cooldown > 0.0 or stamina < 12.0:
        return
    _teleport_cooldown = 1.0
    stamina -= 12.0
    var distance := 14.0 if size_level <= 0 else 22.0
    var target := global_position + -global_transform.basis.z * distance
    var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, target + Vector3.UP)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        global_position = target
    else:
        global_position = hit.position - -global_transform.basis.z * 1.5
    velocity = Vector3.ZERO
    $TeleportFlash.emitting = true
    _update_status_ui("TELEPORT")

func _attack() -> void:
    if _attack_cooldown > 0.0:
        return
    _attack_cooldown = 0.32
    var origin := global_position + Vector3.UP * (1.2 * maxf(scale.y, 0.4))
    var forward := -global_transform.basis.z
    var reach := 5.0 * maxf(scale.x, 0.25)
    var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * reach)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.collider.has_method("take_damage"):
        hit.collider.take_damage(25.0)
        _update_status_ui("IMPACT")

func take_damage(amount: float) -> void:
    if Input.is_action_pressed("block"):
        amount *= 0.2
        _update_status_ui("BLOCK")
    health = maxf(0.0, health - amount)
    _update_health_ui()
    if health <= 0.0:
        _respawn()

func _respawn() -> void:
    is_flying = false
    flight_fx.emitting = false
    scale = _original_scale
    size_level = 0
    global_position = _last_safe_position
    velocity = Vector3.ZERO
    health = 100.0
    stamina = max_stamina
    _update_health_ui()
    _update_status_ui("RESPAWNED")

func _recover_if_fallen() -> void:
    if is_on_floor() and global_position.y > -10.0:
        _last_safe_position = global_position
    if global_position.y < -80.0:
        _respawn()

func _update_camera() -> void:
    third_camera.current = camera_mode == 0
    first_camera.current = camera_mode == 1
    body_mesh.visible = camera_mode == 0
    $Head.visible = camera_mode == 0
    $FirstPersonArms.visible = camera_mode == 1
    crosshair.text = "+" if camera_mode == 1 else "•"
    _update_status_ui("THIRD PERSON" if camera_mode == 0 else "FIRST PERSON")

func _update_health_ui() -> void:
    if health_label:
        health_label.text = "HP %03d   STAMINA %03d" % [int(health), int(stamina)]

func _update_status_ui(message: String = "") -> void:
    if status_label:
        status_label.text = message if not message.is_empty() else ("FLIGHT  " + ("ON" if is_flying else "OFF"))

func _update_motion_ui() -> void:
    if speed_label:
        speed_label.text = "SPEED %03d   ALT %04d" % [int(velocity.length()), int(global_position.y)]
    _update_health_ui()
