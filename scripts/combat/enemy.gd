extends CharacterBody3D
class_name PrototypeEnemy

@export var max_health := 60.0
@export var attack_range := 2.5
@export var move_speed := 3.5
var health := 60.0
var attack_timer := 0.0
@onready var player: Node3D = get_tree().get_first_node_in_group("player")

func _ready() -> void:
    health = max_health
    add_to_group("enemy")

func _physics_process(delta: float) -> void:
    attack_timer = maxf(0.0, attack_timer - delta)
    if not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player")
        return
    var offset := player.global_position - global_position
    var distance := offset.length()
    if distance > attack_range:
        velocity = offset.normalized() * move_speed
        velocity.y = -0.5
        look_at(global_position + Vector3(offset.x, 0, offset.z), Vector3.UP)
        move_and_slide()
    elif attack_timer <= 0.0:
        attack_timer = 1.2
        if player.has_method("take_damage"):
            player.take_damage(8.0)

func take_damage(amount: float) -> void:
    health -= amount
    if health <= 0.0:
        queue_free()
