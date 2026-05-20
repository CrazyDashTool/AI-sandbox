extends Node3D

const ART := preload("res://scripts/ArtMaterials.gd")

var flower_white: StandardMaterial3D
var flower_yellow: StandardMaterial3D

func _ready() -> void:
	flower_white = _mat(Color(0.98, 0.98, 0.9), 1.0)
	flower_yellow = _mat(Color(1.0, 0.78, 0.18), 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_make_flower_field()

func _make_flower_field() -> void:
	var root := Node3D.new()
	root.name = "FlowerField"
	add_child(root)
	for i in 430:
		var x: float = randf_range(-52.0, 52.0)
		var z: float = randf_range(-52.0, 52.0)
		if abs(x) < 5.0 and abs(z) < 5.0:
			continue
		var ground: Dictionary = _ground_position(x, z)
		if bool(ground.get("found", false)):
			var pos: Vector3 = ground.position
			_make_flower(root, pos, randf_range(0.55, 1.05))

func _make_flower(parent: Node, pos: Vector3, scale_value: float) -> void:
	var flower := Node3D.new()
	flower.name = "TinyFlower"
	flower.position = pos
	flower.rotation_degrees.y = randf_range(0.0, 360.0)
	flower.scale = Vector3.ONE * scale_value
	parent.add_child(flower)
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.015
	stem_mesh.bottom_radius = 0.018
	stem_mesh.height = 0.22
	stem.mesh = stem_mesh
	stem.position.y = 0.11
	stem.material_override = ART.soft(Color(0.23, 0.52, 0.16), Color(0.36, 0.7, 0.22))
	flower.add_child(stem)
	for i in 5:
		var petal := MeshInstance3D.new()
		var petal_mesh := SphereMesh.new()
		petal_mesh.radius = 0.045
		petal_mesh.height = 0.07
		petal_mesh.radial_segments = 8
		petal_mesh.rings = 4
		petal.mesh = petal_mesh
		var a := TAU * float(i) / 5.0
		petal.position = Vector3(cos(a) * 0.055, 0.24, sin(a) * 0.055)
		petal.scale = Vector3(1.3, 0.5, 0.8)
		petal.material_override = flower_white
		flower.add_child(petal)
	var center := MeshInstance3D.new()
	var center_mesh := SphereMesh.new()
	center_mesh.radius = 0.035
	center_mesh.height = 0.035
	center_mesh.radial_segments = 8
	center_mesh.rings = 4
	center.mesh = center_mesh
	center.position.y = 0.245
	center.material_override = flower_yellow
	flower.add_child(center)

func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat

func _ground_position(x: float, z: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 80.0, z), Vector3(x, -20.0, z))
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return {"found": false}
	var normal: Vector3 = hit.normal
	if normal.y < 0.45:
		return {"found": false}
	var position: Vector3 = hit.position
	return {"found": true, "position": position + normal * 0.035}
