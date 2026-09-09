extends Area3D
class_name RealityPortal

@export_file("*.tscn") var destination_scene: String = "res://scenes/micro/micro_reality.tscn"
@export var destination_position := Vector3(0, 2, 0)
var _cooldown := 0.0

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    _cooldown = maxf(0.0, _cooldown - delta)
    $Ring.rotation.y += delta * 0.8

func _on_body_entered(body: Node3D) -> void:
    if _cooldown > 0.0 or not body.is_in_group("player"):
        return
    _cooldown = 1.0
    _travel(body)

func _travel(body: Node3D) -> void:
    var root := get_tree().current_scene
    if root.has_method("travel_to_reality"):
        root.travel_to_reality(destination_scene, destination_position)
    else:
        get_tree().change_scene_to_file(destination_scene)
