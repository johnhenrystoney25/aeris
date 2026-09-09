extends Node3D
class_name HighDetailCharacterBridge

## Asset-ready bridge for the next-generation original superhero body.
## Gameplay remains owned by MultiversePlayer. This layer is presentation-only
## so replacing the current primitive body with a rigged GLB does not change
## movement, flight, teleport, size, or combat code.

@export_category("Asset")
@export var character_scene: PackedScene
@export var character_scale := 1.0
@export var hide_fallback_body := true

@export_category("Animation")
@export var animation_tree_path: NodePath
@export var animation_player_path: NodePath
@export var locomotion_parameter := "parameters/Locomotion/blend_position"
@export var speed_parameter := "parameters/Speed/scale"

@export_category("Sizing")
@export var inherit_player_scale := true

var _character: Node3D
var _animation_tree: AnimationTree
var _animation_player: AnimationPlayer
var _actor: CharacterBody3D
var _last_state := ""

func _ready() -> void:
    _actor = get_parent() as CharacterBody3D
    if _actor == null:
        push_warning("HighDetailCharacterBridge must be a child of the player CharacterBody3D.")
        return
    _spawn_character()
    _cache_animation_system()
    _hide_fallback_visuals()

func _spawn_character() -> void:
    if character_scene == null:
        return
    _character = character_scene.instantiate() as Node3D
    if _character == null:
        push_warning("Configured character_scene is not a Node3D scene.")
        return
    _character.name = "HighDetailCharacter"
    _character.scale = Vector3.ONE * character_scale
    add_child(_character)

func _hide_fallback_visuals() -> void:
    if not hide_fallback_body or _actor == null:
        return

    # The old procedural body is made from many separate MeshInstance3D nodes,
    # not one mesh. Hide those presentation meshes together so they cannot
    # overlap the rigged GLB and produce the malformed/double-body appearance.
    for child in _actor.get_children():
        if child == self:
            continue
        if child is MeshInstance3D:
            (child as MeshInstance3D).visible = false

    # First-person arms are intentionally left alone; they are a camera-space
    # presentation layer and are not part of the third-person replacement body.

func _cache_animation_system() -> void:
    if _character == null:
        return
    _animation_tree = _character.get_node_or_null(animation_tree_path) as AnimationTree
    _animation_player = _character.get_node_or_null(animation_player_path) as AnimationPlayer
    if _animation_tree:
        _animation_tree.active = true

func _process(_delta: float) -> void:
    if _actor == null or _character == null:
        return

    if inherit_player_scale:
        # The player root remains the authoritative size-change system.
        # The GLB is uniformly scaled locally; the actor's uniform scale is
        # inherited automatically by this child.
        _character.scale = Vector3.ONE * character_scale

    var velocity: Vector3 = _actor.velocity
    var planar_speed: float = Vector2(velocity.x, velocity.z).length()
    var flying: bool = _actor.get("is_flying") == true
    var grounded: bool = _actor.is_on_floor()
    var state := _state_for(planar_speed, flying, grounded)

    if state != _last_state:
        _play_state(state)
        _last_state = state

    _drive_blend(planar_speed, flying)

func _state_for(speed: float, flying: bool, grounded: bool) -> String:
    if flying:
        return "fly"
    if not grounded:
        return "air"
    if speed > 20.0:
        return "sprint"
    if speed > 0.6:
        return "walk"
    return "idle"

func _play_state(state: String) -> void:
    if _animation_player == null:
        return

    var candidates := {
        "idle": ["idle", "Idle", "idle_loop"],
        "walk": ["walk", "Walk", "walk_forward"],
        "sprint": ["run", "Run", "sprint", "Sprint"],
        "air": ["jump", "Jump", "fall", "Fall"],
        "fly": ["fly", "Fly", "flight", "Flight"],
    }

    for clip_name in candidates.get(state, []):
        if _animation_player.has_animation(clip_name):
            _animation_player.play(clip_name)
            return

func _drive_blend(planar_speed: float, flying: bool) -> void:
    if _animation_tree == null:
        return

    # AnimationTree silently ignores a parameter path that is not present in
    # the imported asset, keeping the gameplay layer independent of the rig.
    _animation_tree.set(locomotion_parameter, planar_speed)
    _animation_tree.set(speed_parameter, 1.35 if flying else clampf(planar_speed / 8.0, 0.5, 2.2))
