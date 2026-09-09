extends Node3D
## Main world coordinator for the recorded Federal Way -> Tacoma geography.

@export var enable_geography_streaming := true
@export var stream_interval := 0.5
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
        if geography.has_method("get_streaming_stats"):
            var stats: Dictionary = geography.get_streaming_stats()
            if Engine.get_process_frames() % 120 == 0:
                print("GEOGRAPHY STREAM | chunks=%d roads=%d buildings=%d parks=%d water=%d rail=%d" % [stats.loaded_chunks, stats.roads, stats.buildings, stats.parks, stats.water, stats.railways])

func travel_to_reality(scene_path: String, spawn_position: Vector3) -> void:
    var scene := load(scene_path)
    if scene == null:
        push_error("Could not load reality scene: %s" % scene_path)
        return
    get_tree().change_scene_to_packed(scene)
    await get_tree().process_frame
    var player := get_tree().current_scene.get_node_or_null("Player")
    if player:
        player.global_position = spawn_position
