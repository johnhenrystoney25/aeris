extends Node3D
## Dense original city dressing for the Earth-scale world prototype.

@export var radius := 1400.0
@export var street_spacing := 90.0
@export var seed := 18473

func _ready() -> void:
    _generate()

func _generate() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    _ground()
    var count := int(radius / street_spacing)
    for x in range(-count, count + 1):
        for z in range(-count, count + 1):
            var p := Vector3(x * street_spacing, 0, z * street_spacing)
            if p.length() > radius:
                continue
            if abs(x) % 4 == 0 or abs(z) % 4 == 0:
                continue
            _block(p, rng)

func _ground() -> void:
    var mesh := BoxMesh.new()
    mesh.size = Vector3(radius * 2.0, 0.5, radius * 2.0)
    var ground := MeshInstance3D.new()
    ground.mesh = mesh
    ground.position.y = -0.25
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#202827")
    mat.roughness = 0.95
    ground.material_override = mat
    add_child(ground)

func _block(center: Vector3, rng: RandomNumberGenerator) -> void:
    var pieces := rng.randi_range(2, 6)
    for i in range(pieces):
        var p := center + Vector3(rng.randf_range(-28, 28), 0, rng.randf_range(-28, 28))
        var size := Vector3(rng.randf_range(16, 30), rng.randf_range(10, 85), rng.randf_range(16, 30))
        _building(p, size, rng)

func _building(p: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = p + Vector3(0, size.y * 0.5, 0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.from_hsv(rng.randf_range(0.53, 0.64), 0.10, rng.randf_range(0.35, 0.65))
    mat.roughness = 0.55
    node.material_override = mat
    add_child(node)
