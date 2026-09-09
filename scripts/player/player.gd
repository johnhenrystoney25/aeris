extends CharacterBody3D
class_name MultiversePlayer

## High-mobility superhero traversal controller for THE MULTIVERSE.
## Ground movement, super jump, dash/dodge, flight, boost, wall traversal,
## safe recovery, camera-relative controls, and size-aware movement.

@export_category("Ground Movement")
@export var walk_speed := 8.0
@export var sprint_speed := 16.0
@export var super_sprint_speed := 28.0
@export var acceleration := 42.0
@export var air_acceleration := 24.0
@export var ground_friction := 34.0
@export var jump_velocity := 12.0
@export var super_jump_velocity := 24.0
@export var gravity := 28.0

@export_category("Flight")
@export var flight_speed := 22.0
@export var flight_boost_speed := 56.0
@export var flight_acceleration := 7.0
@export var flight_vertical_speed := 18.0

@export_category("Traversal")
@export var dash_speed := 42.0
@export var dash_duration := 0.18
@export var wall_run_speed := 24.0
@export var wall_climb_speed := 12.0
@export var wall_probe_distance := 1.25
@export var wall_grace_time := 0.18

@export_category("Systems")
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
var _dash_timer := 0.0
var _boost_timer := 0.0
var _wall_grace_timer := 0.0
var _wall_normal := Vector3.ZERO
var _last_move_direction := Vector3.FORWARD
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
@onready var flight_fx: CPUParticles3D = $FlightFX

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
    _dash_timer = maxf(0.0, _dash_timer - delta)
    _boost_timer = maxf(0.0, _boost_timer - delta)
    _wall_grace_timer = maxf(0.0, _wall_grace_timer - delta)

    stamina = minf(max_stamina, stamina + (18.0 if not is_flying else 10.0) * delta)

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
        _start_dash()
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
    var direction := (right * input_vec.x + forward * input_vec.y)
    if direction.length_squared() > 0.01:
        direction = direction.normalized()
        _last_move_direction = direction

    var size_multiplier := lerpf(0.55, 1.35, inverse_lerp(-2.0, 2.0, size_level))
    var speed := walk_speed
    if Input.is_action_pressed("sprint"):
        speed = super_sprint_speed if stamina > 8.0 else sprint_speed
    speed *= size_multiplier

    if is_flying:
        _fly(delta, direction)
    else:
        _walk(delta, direction, speed)
        _update_wall_traversal(delta, direction, speed)

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

    var accel := acceleration if is_on_floor() else air_acceleration
    if direction.length_squared() > 0.01:
        velocity.x = move_toward(velocity.x, direction.x * speed, accel * delta)
        velocity.z = move_toward(velocity.z, direction.z * speed, accel * delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
        velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)

    if Input.is_action_pressed("sprint") and direction.length_squared() > 0.01 and is_on_floor():
        stamina = maxf(0.0, stamina - 8.0 * delta)

    if _dash_timer > 0.0:
        velocity.x = _last_move_direction.x * dash_speed * size_multiplier
        velocity.z = _last_move_direction.z * dash_speed * size_multiplier
        velocity.y = minf(velocity.y, 4.0)

func _fly(delta: float, direction: Vector3) -> void:
    var look_dir := -pivot.global_transform.basis.z.normalized()
    var vertical := 0.0
    if Input.is_action_pressed("jump"):
        vertical += 1.0
    if Input.is_action_pressed("flight_down"):
        vertical -= 1.0

    # Looking upward/downward while moving also gives flight pitch control.
    if absf(vertical) < 0.1 and direction.length_squared() > 0.01 and absf(look_dir.y) > 0.3:
        vertical = look_dir.y * 0.8

    var fly_dir := direction
    if fly_dir.length_squared() > 0.01:
        fly_dir = fly_dir.normalized()
    fly_dir += Vector3.UP * vertical
    if fly_dir.length_squared() > 0.01:
        fly_dir = fly_dir.normalized()

    var size_multiplier := lerpf(0.65, 1.3, inverse_lerp(-2.0, 2.0, size_level))
    var actual_speed := flight_boost_speed if _boost_timer > 0.0 else flight_speed
    actual_speed *= size_multiplier

    var target_velocity := fly_dir * actual_speed
    if absf(vertical) > 0.1 and direction.length_squared() < 0.01:
        target_velocity = Vector3.UP * vertical * flight_vertical_speed

    velocity = velocity.lerp(target_velocity, minf(1.0, delta * flight_acceleration))
    if fly_dir.length_squared() > 0.01:
        rotation.y = lerp_angle(rotation.y, atan2(-fly_dir.x, -fly_dir.z), minf(1.0, delta * 5.0))

    flight_fx.emitting = true

func _update_wall_traversal(delta: float, direction: Vector3, speed: float) -> void:
    if is_on_floor():
        _wall_grace_timer = 0.0
        return

    var space := get_world_3d().direct_space_state
    var origins := [global_position + Vector3.UP * 0.65, global_position + Vector3.UP * 1.25]
    var candidates := [global_transform.basis.x, -global_transform.basis.x, -global_transform.basis.z]
    var found := false

    for origin in origins:
        for normal_probe in candidates:
            var query := PhysicsRayQueryParameters3D.create(origin, origin + normal_probe * wall_probe_distance)
            query.exclude = [self]
            var hit := space.intersect_ray(query)
            if not hit.is_empty():
                var normal: Vector3 = hit.normal
                if absf(normal.y) < 0.35:
                    _wall_normal = normal
                    found = true
                    break
        if found:
            break

    if not found:
        return

    _wall_grace_timer = wall_grace_time
    if Input.is_action_pressed("sprint") and stamina > 0.0:
        var along_wall := Vector3.UP
        if direction.length_squared() > 0.01:
            along_wall = (direction - _wall_normal * direction.dot(_wall_normal)).normalized()
        velocity = velocity.lerp(along_wall * wall_run_speed * lerpf(0.7, 1.25, inverse_lerp(-2.0, 2.0, size_level)), minf(1.0, delta * 8.0))
        stamina = maxf(0.0, stamina - 14.0 * delta)
        _update_status_ui("WALL RUN")
    elif Input.is_action_pressed("jump") and stamina > 0.0:
        velocity.y = wall_climb_speed
        velocity = velocity.lerp(Vector3.UP * wall_climb_speed, minf(1.0, delta * 5.0))
        stamina = maxf(0.0, stamina - 10.0 * delta)
        _update_status_ui("WALL CLIMB")

func _start_dash() -> void:
    if is_flying or stamina < 12.0:
        return
    _dash_timer = dash_duration
    stamina -= 12.0
    if _last_move_direction.length_squared() < 0.01:
        _last_move_direction = -global_transform.basis.z
    _update_status_ui("DASH")

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
