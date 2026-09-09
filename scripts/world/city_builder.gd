@tool
extends Node3D
## Procedural visual city builder. Designed to sit on top of imported/open geographic layouts.

@export var city_radius := 900.0
@export var block_spacing := 72.0
@export var seed := 20260909
@export var generate_on_ready := true

func _ready() -> void:
    if generate_on_ready:
        build_city()

func build_city() -> void:
    for child in get_children():
        if child.name.begins_with("Generated_"):
            child.queue_free()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    _make_ground()
    _make_roads()
    var count := int(city_radius / block_spacing)
    for x in range(-count, count + 1):
        for z in range(-count, count + 1):
            var p := Vector3(x * block_spacing, 0, z * block_spacing)
            if p.length() > city_radius:
                continue
            if abs(x) % 5 == 0 or abs(z) % 5 == 0:
                continue
            if rng.randf() < 0.11:
                _make_park(p, rng)
            else:
                _make_block(p, rng)

func _mat(hex: String, roughness := 0.75, metallic := 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(hex)
    m.roughness = roughness
    m.metallic = metallic
    return m

func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.material_override = material
    parent.add_child(n)
    return n

func _make_ground() -> void:
    var n := Node3D.new()
    n.name = "Generated_Ground"
    add_child(n)
    _box(n, "Ground", Vector3(0, -0.5, 0), Vector3(city_radius * 2.2, 1, city_radius * 2.2), _mat("#151b1c", 0.95))

func _make_roads() -> void:
    var root := Node3D.new()
    root.name = "Generated_Roads"
    add_child(root)
    var road_mat := _mat("#080a0c", 0.98)
    var sidewalk := _mat("#686d6c", 0.92)
    var line := _mat("#d9c56a", 0.72)
    var span := city_radius * 2.0
    var count := int(city_radius / block_spacing)
    for i in range(-count, count + 1):
        var p := float(i) * block_spacing
        _box(root, "RoadX_%d" % i, Vector3(p, 0.01, 0), Vector3(18, 0.08, span), road_mat)
        _box(root, "RoadZ_%d" % i, Vector3(0, 0.02, p), Vector3(span, 0.08, 18), road_mat)
        _box(root, "SideX_%d" % i, Vector3(p - 10.5, 0.05, 0), Vector3(2, 0.12, span), sidewalk)
        _box(root, "SideX2_%d" % i, Vector3(p + 10.5, 0.05, 0), Vector3(2, 0.12, span), sidewalk)
        _box(root, "SideZ_%d" % i, Vector3(0, 0.05, p - 10.5), Vector3(span, 0.12, 2), sidewalk)
        _box(root, "SideZ2_%d" % i, Vector3(0, 0.05, p + 10.5), Vector3(span, 0.12, 2), sidewalk)
        _box(root, "StripeX_%d" % i, Vector3(p, 0.07, 0), Vector3(0.35, 0.02, span), line)
        _box(root, "StripeZ_%d" % i, Vector3(0, 0.08, p), Vector3(span, 0.02, 0.35), line)

func _make_block(center: Vector3, rng: RandomNumberGenerator) -> void:
    var root := Node3D.new()
    root.name = "Generated_Block"
    add_child(root)
    var pieces := rng.randi_range(2, 5)
    for i in range(pieces):
        var size := Vector3(rng.randf_range(18, 31), rng.randf_range(12, 95), rng.randf_range(18, 31))
        var offset := Vector3(rng.randf_range(-24, 24), size.y * 0.5, rng.randf_range(-24, 24))
        var palette := ["#39434a", "#59616a", "#70777b", "#30383d", "#7d7469", "#46565c"]
        var building := _box(root, "Building", center + offset, size, _mat(palette[rng.randi_range(0, palette.size() - 1)], 0.52, 0.12))
        _windows(building, size, rng)

func _windows(building: MeshInstance3D, size: Vector3, rng: RandomNumberGenerator) -> void:
    # Lightweight emissive facade hints instead of thousands of separate meshes.
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#b9c7bd")
    mat.emission_enabled = true
    mat.emission = Color("#7a8d78")
    mat.emission_energy_multiplier = 1.4
    if size.y > 30 and rng.randf() < 0.75:
        var facade := QuadMesh.new()
        facade.size = Vector2(max(size.x - 2.0, 2.0), max(size.y - 4.0, 4.0))
        var panel := MeshInstance3D.new()
        panel.mesh = facade
        panel.material_override = mat
        panel.position = building.position + Vector3(0, 0, size.z * 0.501)
        add_child(panel)

func _make_park(center: Vector3, rng: RandomNumberGenerator) -> void:
    var root := Node3D.new()
    root.name = "Generated_Park"
    add_child(root)
    _box(root, "Grass", center + Vector3(0, 0.08, 0), Vector3(55, 0.15, 55), _mat("#29442f", 0.95))
    for i in range(rng.randi_range(6, 14)):
        var trunk := _mat("#493a2d", 0.9)
        var crown := _mat("#35623e", 0.88)
        var x := rng.randf_range(-23, 23)
        var z := rng.randf_range(-23, 23)
        _box(root, "TreeTrunk", center + Vector3(x, 3, z), Vector3(1.2, 6, 1.2), trunk)
        var sphere := SphereMesh.new()
        sphere.radius = rng.randf_range(3.0, 4.5)
        sphere.height = sphere.radius * 2.0
        var crown_node := MeshInstance3D.new()
        crown_node.mesh = sphere
        crown_node.material_override = crown
        crown_node.position = center + Vector3(x, 7, z)
        root.add_child(crown_node)
