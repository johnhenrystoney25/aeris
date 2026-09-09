extends Node3D

func _ready() -> void:
    var player := get_node_or_null("Player")
    if player:
        player.add_to_group("player")
    print("THE MULTIVERSE vertical slice: MAIN CITY online")

func travel_to_reality(scene_path: String, spawn_position: Vector3) -> void:
    var scene := load(scene_path)
    if scene:
        get_tree().change_scene_to_packed(scene)
