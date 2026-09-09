extends Node3D
class_name RealityManager

@export var current_reality := "main_city"
var gravity_multiplier := 1.0
var world_scale := 1.0

func set_reality(id: String, gravity: float = 1.0, scale_multiplier: float = 1.0) -> void:
    current_reality = id
    gravity_multiplier = gravity
    world_scale = scale_multiplier
    var environment := get_viewport().get_camera_3d()
    if environment:
        environment.environment.tonemap_exposure = 1.0 if id == "main_city" else 1.15
    print("REALITY -> ", current_reality)

func get_reality_scale() -> float:
    return world_scale
