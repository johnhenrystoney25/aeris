extends Node3D
## Earth-scale world coordinator.
## Region geometry is streamed/generated locally; source map data stays separate.

@export var planet_radius_km: float = 6371.0
@export var region_size_m: float = 2000.0
@export var stream_radius_regions: int = 2

var loaded_regions: Dictionary = {}

func _ready() -> void:
    _ensure_world_root()

func _ensure_world_root() -> void:
    if not has_node("WorldRegions"):
        var root := Node3D.new()
        root.name = "WorldRegions"
        add_child(root)

func world_to_lat_lon(world_position: Vector3) -> Vector2:
    var meters_per_degree := 111320.0
    var latitude := world_position.z / meters_per_degree
    var longitude := world_position.x / (meters_per_degree * max(cos(deg_to_rad(latitude)), 0.1))
    return Vector2(latitude, longitude)

func region_key(world_position: Vector3) -> Vector2i:
    return Vector2i(floori(world_position.x / region_size_m), floori(world_position.z / region_size_m))

func load_region(key: Vector2i) -> void:
    if loaded_regions.has(key):
        return
    loaded_regions[key] = true
    # Region generators/importers attach generated original geometry here.

func unload_region(key: Vector2i) -> void:
    loaded_regions.erase(key)

func update_streaming(player_position: Vector3) -> void:
    var center := region_key(player_position)
    for x in range(center.x - stream_radius_regions, center.x + stream_radius_regions + 1):
        for z in range(center.y - stream_radius_regions, center.y + stream_radius_regions + 1):
            load_region(Vector2i(x, z))

func earth_surface_position(latitude_deg: float, longitude_deg: float, altitude_m := 0.0) -> Vector3:
    var r := planet_radius_km * 1000.0 + altitude_m
    var lat := deg_to_rad(latitude_deg)
    var lon := deg_to_rad(longitude_deg)
    return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * r
