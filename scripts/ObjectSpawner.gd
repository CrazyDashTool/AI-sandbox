extends Node3D

class_name ObjectSpawner

const PROP_SCRIPT := preload("res://scripts/SpawnedProp.gd")
const PROP_CATALOG := preload("res://scripts/PropCatalog.gd")
const MIRROR_SURFACE := preload("res://scripts/MirrorSurface.gd")
const PROP_ASSET_ADAPTER := preload("res://scripts/PropAssetAdapter.gd")
const ART := preload("res://scripts/ArtMaterials.gd")

var prop_defs: Dictionary = {}

func _ready() -> void:
	add_to_group("object_spawner")
	_build_defs()

func spawn_prop(type_name: String, position: Vector3, normal: Vector3, spawned_by := "player") -> RigidBody3D:
	if prop_defs.is_empty():
		_build_defs()
	var def: Dictionary = prop_defs.get(type_name, prop_defs.Cube)
	var body := PROP_ASSET_ADAPTER.build(type_name, def)
	var scene_based := body != null
	if not body:
		body = _make_procedural_body(type_name, def)
	_configure_body(body, type_name, def)
	_apply_variants(body, def)
	var id := WorldContext.register_spawned_object(type_name, position, spawned_by)
	body.name = "%s_%03d" % [type_name.replace(" ", "_"), id]
	add_child(body)
	body.global_position = position + normal.normalized() * def.get("lift", 0.1)
	body.rotation_degrees = def.get("rotation", body.rotation_degrees)
	if not scene_based:
		_add_extra_nodes(body, type_name, def)
	body.setup(id, type_name)
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, body.global_transform)
	return body

func _configure_body(body: RigidBody3D, type_name: String, def: Dictionary) -> void:
	body.mass = def.get("mass", 1.0)
	body.gravity_scale = def.get("gravity", 1.0)
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.set_meta("impact", def.get("impact", ""))
	body.set_meta("buoyant", def.get("buoyant", false))
	body.set_meta("motorized", def.get("motorized", false))
	body.set_meta("motor_force", def.get("motor_force", 34.0))
	body.set_meta("turn_force", def.get("turn_force", 6.0))
	body.set_meta("buoyancy_offset", def.get("buoyancy_offset", 0.0))
	body.set_meta("interaction", def.get("interaction", ""))
	body.set_meta("seat_height", def.get("seat_height", 0.65))
	var material := PhysicsMaterial.new()
	material.bounce = def.get("bounce", 0.05)
	material.friction = def.get("friction", 0.75)
	body.physics_material_override = material

func _apply_variants(body: RigidBody3D, def: Dictionary) -> void:
	if str(def.get("random_color", "")) == "blanket":
		var palette := [
			Color(0.38, 0.64, 0.95),
			Color(0.95, 0.58, 0.42),
			Color(0.78, 0.5, 0.92),
			Color(0.95, 0.84, 0.42),
			Color(0.36, 0.78, 0.62)
		]
		_apply_mesh_materials(body, ART.soft(palette.pick_random(), Color.WHITE))

func _apply_mesh_materials(node: Node, material: Material, inside_outline := false) -> void:
	var now_outline := inside_outline or node.name == "Outline"
	if node is MeshInstance3D and not now_outline:
		node.material_override = material
	for child in node.get_children():
		_apply_mesh_materials(child, material, now_outline)

func _make_procedural_body(type_name: String, def: Dictionary) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(PROP_SCRIPT)
	var mesh := _make_mesh(def)
	var visible_mesh := MeshInstance3D.new()
	visible_mesh.name = "Mesh"
	visible_mesh.mesh = mesh
	visible_mesh.material_override = _material(def.get("color", Color.WHITE), type_name == "Mirror")
	body.add_child(visible_mesh)
	var collision := CollisionShape3D.new()
	collision.shape = _make_shape(def)
	body.add_child(collision)
	var outline := MeshInstance3D.new()
	outline.name = "Outline"
	outline.mesh = mesh
	outline.scale = Vector3.ONE * 1.05
	outline.visible = false
	outline.material_override = _outline_material()
	body.add_child(outline)
	return body

func _build_defs() -> void:
	prop_defs = PROP_CATALOG.definitions()

func _make_mesh(def: Dictionary) -> Mesh:
	var size: Vector3 = def.size
	match def.shape:
		"sphere":
			var mesh := SphereMesh.new()
			mesh.radius = max(size.x, size.z) * 0.5
			mesh.height = size.y
			return mesh
		"cylinder":
			var mesh := CylinderMesh.new()
			mesh.top_radius = size.x * 0.5
			mesh.bottom_radius = size.z * 0.5
			mesh.height = size.y
			return mesh
		"cone":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.0
			mesh.bottom_radius = size.x * 0.5
			mesh.height = size.y
			return mesh
		"capsule":
			var mesh := CapsuleMesh.new()
			mesh.radius = size.x * 0.5
			mesh.height = size.y
			return mesh
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _make_shape(def: Dictionary) -> Shape3D:
	var size: Vector3 = def.size
	match def.shape:
		"sphere":
			var shape := SphereShape3D.new()
			shape.radius = max(size.x, size.z) * 0.5
			return shape
		"cylinder", "cone":
			var shape := CylinderShape3D.new()
			shape.radius = max(size.x, size.z) * 0.5
			shape.height = size.y
			return shape
		"capsule":
			var shape := CapsuleShape3D.new()
			shape.radius = size.x * 0.5
			shape.height = size.y
			return shape
	var shape := BoxShape3D.new()
	shape.size = size
	return shape

func _add_extra_nodes(body: RigidBody3D, type_name: String, def: Dictionary) -> void:
	if def.get("extra", "") == "light" or type_name == "Light Source":
		var light := OmniLight3D.new()
		light.light_energy = 2.4
		light.omni_range = 7.0
		body.add_child(light)
	if def.get("extra", "") == "chair":
		_add_part(body, Vector3(0, 0.55, 0.32), Vector3(0.8, 0.9, 0.12))
	if def.get("extra", "") == "table":
		for x in [-0.55, 0.55]:
			for z in [-0.3, 0.3]:
				_add_part(body, Vector3(x, -0.45, z), Vector3(0.12, 0.9, 0.12))
	if def.get("extra", "") == "stairs":
		for i in 3:
			_add_part(body, Vector3(0, 0.1 + i * 0.26, -0.45 + i * 0.45), Vector3(2.05, 0.25, 0.42))
	if def.get("extra", "") == "mirror":
		var mirror := Node3D.new()
		mirror.set_script(MIRROR_SURFACE)
		body.add_child(mirror)
	if def.get("extra", "") == "pipe":
		_add_part(body, Vector3(0, 0.0, 0.45), Vector3(0.16, 0.16, 1.0))
	if def.get("extra", "") == "bench":
		for x in [-0.65, 0.65]:
			_add_part(body, Vector3(x, -0.38, -0.12), Vector3(0.16, 0.75, 0.16))
	if def.get("extra", "") == "tree_prop":
		_add_part(body, Vector3(0, -0.55, 0), Vector3(0.28, 1.1, 0.28), Color(0.35, 0.22, 0.12))
		_add_part(body, Vector3(0, 0.35, 0), Vector3(1.2, 1.1, 1.2), Color(0.22, 0.48, 0.2))
	if def.get("extra", "") == "boombox":
		_add_part(body, Vector3(-0.32, 0.0, -0.22), Vector3(0.28, 0.28, 0.08))
		_add_part(body, Vector3(0.32, 0.0, -0.22), Vector3(0.28, 0.28, 0.08))
		_add_part(body, Vector3(0.0, 0.22, -0.02), Vector3(0.42, 0.08, 0.08))
	if def.get("extra", "") == "raft" or def.get("extra", "") == "raft_motor":
		_add_part(body, Vector3(0, 0.16, 0), Vector3(3.5, 0.12, 2.35), Color(0.55, 0.35, 0.2))
		_add_cylinder_part(body, Vector3(-1.1, -0.2, 0), Vector3(0.42, 2.25, 0.42), Color(0.72, 0.42, 0.22), Vector3(0, 0, 90))
		_add_cylinder_part(body, Vector3(1.1, -0.2, 0), Vector3(0.42, 2.25, 0.42), Color(0.72, 0.42, 0.22), Vector3(0, 0, 90))
		_add_part(body, Vector3(0.0, 0.52, 0.35), Vector3(0.75, 0.28, 0.55), Color(0.18, 0.25, 0.3))
	if def.get("extra", "") == "raft_motor":
		_add_part(body, Vector3(0.0, 0.42, 1.1), Vector3(0.48, 0.42, 0.45), Color(0.16, 0.2, 0.23))
		_add_cylinder_part(body, Vector3(0.0, 0.42, 1.55), Vector3(0.42, 0.55, 0.42), Color(0.38, 0.52, 0.72), Vector3(90, 0, 0))
	if def.get("extra", "") == "chassis":
		_add_part(body, Vector3(0, 0.3, 0), Vector3(2.3, 0.22, 1.15), Color(0.26, 0.3, 0.34))
	if def.get("extra", "") == "car":
		_add_part(body, Vector3(0, 0.22, 0), Vector3(2.6, 0.22, 1.25), Color(0.16, 0.28, 0.38))
		_add_part(body, Vector3(0, 0.58, -0.15), Vector3(0.78, 0.42, 0.65), Color(0.12, 0.2, 0.26))
		for x in [-1.0, 1.0]:
			for z in [-0.68, 0.68]:
				_add_cylinder_part(body, Vector3(x, -0.18, z), Vector3(0.56, 0.28, 0.56), Color(0.08, 0.07, 0.06), Vector3(90, 0, 0))
	if def.get("extra", "") == "seat":
		_add_part(body, Vector3(0, 0.28, 0.25), Vector3(0.68, 0.7, 0.1), Color(0.12, 0.18, 0.22))
	if def.get("extra", "") == "motor":
		_add_cylinder_part(body, Vector3(0, 0.0, 0.48), Vector3(0.45, 0.34, 0.45), Color(0.4, 0.5, 0.58), Vector3(90, 0, 0))
	if def.get("extra", "") == "thruster":
		_add_cylinder_part(body, Vector3(0, 0.0, 0.52), Vector3(0.62, 0.18, 0.62), Color(0.86, 0.45, 0.22), Vector3(90, 0, 0))

func _add_part(body: Node3D, pos: Vector3, size: Vector3, color := Color.TRANSPARENT) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = pos
	part.material_override = ART.soft(color, color.lightened(0.2)) if color.a > 0.0 else body.get_node("Mesh").material_override
	body.add_child(part)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	body.add_child(collision)

func _add_cylinder_part(body: Node3D, pos: Vector3, size: Vector3, color := Color.TRANSPARENT, rotation := Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = size.x * 0.5
	mesh.bottom_radius = size.z * 0.5
	mesh.height = size.y
	part.mesh = mesh
	part.position = pos
	part.rotation_degrees = rotation
	part.material_override = ART.soft(color, color.lightened(0.2)) if color.a > 0.0 else body.get_node("Mesh").material_override
	body.add_child(part)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = max(size.x, size.z) * 0.5
	shape.height = size.y
	collision.shape = shape
	collision.position = pos
	collision.rotation_degrees = rotation
	body.add_child(collision)

func _material(color: Color, mirror := false) -> Material:
	if mirror or color.a < 0.95:
		return ART.glass(color)
	return ART.soft(color, color.lightened(0.22))

func _outline_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.75, 1.0, 0.34)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
