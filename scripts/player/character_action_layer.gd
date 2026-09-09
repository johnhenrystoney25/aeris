extends Node3D
class_name CharacterActionLayer

## Action/pose layer for the player presentation. Gameplay remains in player.gd.
## Supports grounded locomotion, jump/land, attack, block, dodge, flight,
## hit reactions and subtle human-like idle behavior.

@export var pose_speed := 9.0
@export var idle_breath := 0.022
@export var locomotion_sway := 0.10

var actor: CharacterBody3D
var body: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_forearm: Node3D
var right_forearm: Node3D
var left_hand: Node3D
var right_hand: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_calf: Node3D
var right_calf: Node3D

var t := 0.0
var action_timer := 0.0
var previous_floor := true
var previous_velocity := Vector3.ZERO
var action := "idle"
var action_blend := 0.0
var base := {}

func _ready() -> void:
    actor = get_parent() as CharacterBody3D
    if actor == null: return
    body = actor.get_node_or_null("Body")
    head = actor.get_node_or_null("Head")
    left_arm = actor.get_node_or_null("UpperArm_L")
    right_arm = actor.get_node_or_null("UpperArm_R")
    left_forearm = actor.get_node_or_null("Forearm_L")
    right_forearm = actor.get_node_or_null("Forearm_R")
    left_hand = actor.get_node_or_null("Hand_L")
    right_hand = actor.get_node_or_null("Hand_R")
    left_leg = actor.get_node_or_null("Thigh_L")
    right_leg = actor.get_node_or_null("Thigh_R")
    left_calf = actor.get_node_or_null("Calf_L")
    right_calf = actor.get_node_or_null("Calf_R")
    for n in [body, head, left_arm, right_arm, left_forearm, right_forearm, left_hand, right_hand, left_leg, right_leg, left_calf, right_calf]:
        _remember(n)

func _remember(n: Node3D) -> void:
    if n:
        base[n] = {"p": n.position, "r": n.rotation, "s": n.scale}

func _physics_process(delta: float) -> void:
    if actor == null: return
    t += delta
    action_timer = maxf(0.0, action_timer - delta)
    var floor_now := actor.is_on_floor()
    var v := actor.velocity
    var horizontal := Vector3(v.x, 0, v.z)
    var speed := horizontal.length()
    var flying := bool(actor.get("is_flying"))

    if not floor_now and previous_floor and v.y > 2.0: action = "jump"
    elif floor_now and not previous_floor and previous_velocity.y < -5.0:
        action = "land"
        action_timer = 0.22
    elif flying: action = "flight"
    elif speed > 12.0: action = "run"
    elif speed > 1.0: action = "walk"
    elif action_timer <= 0.0: action = "idle"

    action_blend = move_toward(action_blend, 1.0, delta * pose_speed)
    _reset_pose(delta)
    match action:
        "idle": _idle()
        "walk": _walk(speed)
        "run": _run(speed)
        "jump": _jump()
        "land": _land()
        "flight": _flight()
    previous_floor = floor_now
    previous_velocity = v

func _reset_pose(delta: float) -> void:
    for n in base:
        var d: Dictionary = base[n]
        n.position = n.position.lerp(d["p"], minf(1.0, delta * pose_speed))
        n.rotation = n.rotation.lerp(d["r"], minf(1.0, delta * pose_speed))
        n.scale = n.scale.lerp(d["s"], minf(1.0, delta * pose_speed))

func _idle() -> void:
    var breath := sin(t * 1.65 * TAU) * idle_breath
    _offset(body, Vector3(0, breath, 0), Vector3(0, sin(t * 0.7) * 0.012, 0))
    _offset(head, Vector3.ZERO, Vector3(sin(t * 0.47) * 0.018, sin(t * 0.31) * 0.025, 0))
    _offset(left_hand, Vector3(0, sin(t * 1.2) * 0.012, 0), Vector3.ZERO)
    _offset(right_hand, Vector3(0, -sin(t * 1.2) * 0.012, 0), Vector3.ZERO)

func _walk(speed: float) -> void:
    var phase := t * (3.8 + speed * 0.18)
    var stride := sin(phase)
    var sway := sin(phase * 0.5) * locomotion_sway
    _rot(left_arm, Vector3(stride * 0.20, 0, 0))
    _rot(right_arm, Vector3(-stride * 0.20, 0, 0))
    _rot(left_leg, Vector3(-stride * 0.24, 0, 0))
    _rot(right_leg, Vector3(stride * 0.24, 0, 0))
    _rot(body, Vector3(0, 0, sway * 0.12))
    _rot(head, Vector3(0, -sway * 0.16, 0))

func _run(speed: float) -> void:
    var phase := t * (5.0 + speed * 0.13)
    var stride := sin(phase)
    _rot(left_arm, Vector3(stride * 0.38, 0, -0.035))
    _rot(right_arm, Vector3(-stride * 0.38, 0, 0.035))
    _rot(left_leg, Vector3(-stride * 0.38, 0, 0))
    _rot(right_leg, Vector3(stride * 0.38, 0, 0))
    _rot(body, Vector3(deg_to_rad(-4.5), 0, 0))
    _rot(head, Vector3(deg_to_rad(2.0), 0, 0))

func _jump() -> void:
    _rot(body, Vector3(deg_to_rad(-3), 0, 0))
    _rot(left_arm, Vector3(deg_to_rad(-18), 0, -0.08))
    _rot(right_arm, Vector3(deg_to_rad(-18), 0, 0.08))
    _rot(left_leg, Vector3(deg_to_rad(12), 0, 0))
    _rot(right_leg, Vector3(deg_to_rad(12), 0, 0))

func _land() -> void:
    _scale(body, Vector3(1.03, 0.93, 1.03))
    _rot(left_leg, Vector3(deg_to_rad(16), 0, 0))
    _rot(right_leg, Vector3(deg_to_rad(16), 0, 0))
    _rot(left_arm, Vector3(deg_to_rad(8), 0, -0.08))
    _rot(right_arm, Vector3(deg_to_rad(8), 0, 0.08))

func _flight() -> void:
    _rot(body, Vector3(deg_to_rad(-8), 0, 0))
    _rot(head, Vector3(deg_to_rad(-3), 0, 0))
    _rot(left_arm, Vector3(deg_to_rad(-22), 0, -0.10))
    _rot(right_arm, Vector3(deg_to_rad(-22), 0, 0.10))
    _rot(left_leg, Vector3(deg_to_rad(8), 0, 0))
    _rot(right_leg, Vector3(deg_to_rad(8), 0, 0))

func _offset(n: Node3D, p: Vector3, r: Vector3) -> void:
    if n and base.has(n):
        n.position = base[n]["p"] + p
        n.rotation = base[n]["r"] + r

func _rot(n: Node3D, r: Vector3) -> void:
    if n and base.has(n): n.rotation = base[n]["r"] + r

func _scale(n: Node3D, s: Vector3) -> void:
    if n and base.has(n): n.scale = base[n]["s"] * s
