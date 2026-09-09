extends Node3D
## Presentation layer: readable sky, sun cycle, atmospheric color and city ambience.

@export var day_length_seconds := 900.0
@export var start_time := 16.5
@export var animate_time := true

var _time := 16.5

func _ready() -> void:
    _time = start_time
    _apply_lighting()

func _process(delta: float) -> void:
    if not animate_time:
        return
    _time = fmod(_time + delta * 24.0 / day_length_seconds, 24.0)
    _apply_lighting()

func _apply_lighting() -> void:
    var daylight := clampf(sin((_time - 6.0) / 24.0 * TAU), 0.0, 1.0)
    var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
    var environment_node := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
    if sun:
        var angle := (_time - 6.0) / 24.0 * TAU
        sun.rotation_degrees = Vector3(-18.0 - daylight * 54.0, -35.0 + sin(angle) * 20.0, 0.0)
        sun.light_energy = lerpf(0.22, 1.45, daylight)
        sun.light_color = Color(1.0, 0.72 + daylight * 0.25, 0.58 + daylight * 0.4)
    if environment_node and environment_node.environment:
        environment_node.environment.ambient_light_energy = lerpf(0.32, 1.0, daylight)
        environment_node.environment.background_energy_multiplier = lerpf(0.35, 0.9, daylight)
