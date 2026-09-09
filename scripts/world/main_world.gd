extends Node3D
## Main world coordinator for the recorded Federal Way -> Tacoma geography.

@export var enable_geography_streaming := true
@export var stream_interval := 0.75
var _stream_clock := 0.0

func _ready() -> void:
    var player := get_node_or_null("Player")
    if player:
        player.add_to_group("player")
    print("THE MULTIVERSE: FEDERAL WAY -> TACOMA world online")

func _process(delta: float) -> void:
    if not enable_geography_streaming:
        return
    _stream_clock += delta
    if _stream_clock < stream_interval:
        return
    _stream_clock = 0.0
    var player := get_node_or_null("Player")
    var geography := get_node_or_null("RecordedGeography")
    if player and geography and geography.has_method("update_streaming"):
        geography.update_streaming(player.global_position)

func travel_to_reality(scene_path: String, spawn_position: Vector3) -> void:
    var scene := load(scene_path)
    if scene:
        get_tree().change_scene_to_packed(scene)
