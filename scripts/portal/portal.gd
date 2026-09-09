extends Area3D
class_name RealityPortal

@export_file("*.tscn") var destination_scene: String = "res://scenes/micro/micro_reality.tscn"
@export var destination_position := Vector3(0, 2, 0)
@export var require_use_key := true

var _cooldown := 0.0
var _player_inside := false
var _player: Node3D

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
    _cooldown = maxf(0.0, _cooldown - delta)
    if has_node("Ring"):
        $Ring.rotation.y += delta * 0.8
    if _player_inside and is_instance_valid(_player) and Input.is_action_just_pressed("portal_use"):
        _travel(_player)

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    _player_inside = true
    _player = body
    if has_node("PortalSign"):
        $PortalSign.text = "MICRO REALITY  [E]"
    if not require_use_key:
        _travel(body)

func _on_body_exited(body: Node3D) -> void:
    if body == _player:
        _player_inside = false
        _player = null

func _travel(body: Node3D) -> void:
    if _cooldown > 0.0:
        return
    _cooldown = 1.0
    var root := get_tree().current_scene
    if root.has_method("travel_to_reality"):
        root.travel_to_reality(destination_scene, destination_position)
    else:
        get_tree().change_scene_to_file(destination_scene)
