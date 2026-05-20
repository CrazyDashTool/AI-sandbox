extends RefCounted

class_name WaterSplash

static func spawn(parent: Node, position: Vector3, speed: float) -> void:
	if not parent or DisplayServer.get_name() == "headless":
		return
	var root := Node3D.new()
	root.name = "WaterSplash"
	root.global_position = position
	parent.add_child(root)
	_add_ring(root, speed)
	var count: int = clampi(int(8.0 + speed * 3.0), 8, 34)
	var mat: StandardMaterial3D = _mat(Color(0.78, 0.95, 1.0, 0.82))
	for i in count:
		var drop := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var size: float = randf_range(0.025, 0.065) * clamp(speed * 0.18, 0.7, 2.1)
		mesh.radius = size
		mesh.height = size * 2.0
		mesh.radial_segments = 8
		mesh.rings = 4
		drop.mesh = mesh
		drop.material_override = mat
		root.add_child(drop)
		var angle: float = randf() * TAU
		var distance: float = randf_range(0.25, 0.55 + speed * 0.13)
		var up: float = randf_range(0.18, 0.55 + speed * 0.06)
		var target: Vector3 = Vector3(cos(angle) * distance, up, sin(angle) * distance)
		var tween := root.create_tween()
		tween.tween_property(drop, "position", target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(drop, "position", Vector3(target.x * 1.25, -0.05, target.z * 1.25), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(drop, "scale", Vector3.ZERO, 0.34)
	var cleanup := root.create_tween()
	cleanup.tween_interval(0.72)
	cleanup.tween_callback(Callable(root, "queue_free"))

static func _add_ring(root: Node3D, speed: float) -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.018
	mesh.radial_segments = 40
	ring.mesh = mesh
	ring.material_override = _mat(Color(0.84, 0.96, 1.0, 0.42))
	root.add_child(ring)
	var scale_value: float = clamp(0.8 + speed * 0.16, 0.9, 3.4)
	var tween := root.create_tween()
	tween.tween_property(ring, "scale", Vector3(scale_value, 0.2, scale_value), 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "position:y", 0.025, 0.46)

static func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
