extends RefCounted

class_name PropAssetAdapter

const PROP_SCRIPT := preload("res://scripts/SpawnedProp.gd")

static func build(type_name: String, def: Dictionary) -> RigidBody3D:
	var path := str(def.get("scene", ""))
	if path == "":
		return null
	var packed := load(path) as PackedScene
	if not packed:
		return null
	var source := packed.instantiate()
	var body := source as RigidBody3D
	if body:
		body.set_script(PROP_SCRIPT)
	else:
		body = RigidBody3D.new()
		_copy_assets(source, body)
		source.free()
		if _mesh_nodes(body).is_empty() and _collision_nodes(body).is_empty():
			body.free()
			return null
		body.set_script(PROP_SCRIPT)
	_ensure_collisions(body)
	_ensure_outline(body)
	return body

static func _copy_assets(source: Node, body: RigidBody3D) -> void:
	for mesh in _mesh_nodes(source):
		var copy := _copy_mesh(mesh, source)
		body.add_child(copy)
	for collision in _collision_nodes(source):
		var shape := CollisionShape3D.new()
		shape.shape = collision.shape
		shape.transform = _relative_transform(collision, source)
		body.add_child(shape)

static func _ensure_collisions(body: RigidBody3D) -> void:
	var meshes := _mesh_nodes(body)
	if meshes.is_empty():
		return
	for mesh in meshes:
		_add_mesh_collision(body, mesh)

static func _add_mesh_collision(body: RigidBody3D, mesh: MeshInstance3D) -> void:
	var aabb := mesh.mesh.get_aabb()
	if aabb.size.length() <= 0.01:
		return
	var shape := CollisionShape3D.new()
	shape.name = "%sAutoCollision" % mesh.name
	var box := BoxShape3D.new()
	box.size = aabb.size.max(Vector3(0.08, 0.08, 0.08))
	shape.shape = box
	var rel := _relative_transform(mesh, body)
	shape.transform = rel
	shape.position += rel.basis * aabb.get_center()
	body.add_child(shape)

static func _ensure_outline(body: RigidBody3D) -> void:
	if body.get_node_or_null("Outline"):
		return
	var outline := Node3D.new()
	outline.name = "Outline"
	outline.visible = false
	body.add_child(outline)
	var mat := _outline_material()
	for mesh in _mesh_nodes(body):
		if mesh.is_ancestor_of(outline):
			continue
		var copy := _copy_mesh(mesh, body)
		copy.material_override = mat
		copy.scale *= 1.04
		outline.add_child(copy)

static func _copy_mesh(mesh: MeshInstance3D, root: Node) -> MeshInstance3D:
	var copy := MeshInstance3D.new()
	copy.name = "%sCopy" % mesh.name
	copy.mesh = mesh.mesh
	copy.skeleton = NodePath()
	copy.material_override = mesh.material_override
	copy.cast_shadow = mesh.cast_shadow
	copy.transform = _relative_transform(mesh, root)
	return copy

static func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent and parent != root:
		if parent is Node3D:
			result = parent.transform * result
		parent = parent.get_parent()
	return result

static func _mesh_nodes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	_collect_meshes(root, result)
	return result

static func _collision_nodes(root: Node) -> Array[CollisionShape3D]:
	var result: Array[CollisionShape3D] = []
	_collect_collisions(root, result)
	return result

static func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh:
		result.append(node)
	for child in node.get_children():
		if child.name != "Outline":
			_collect_meshes(child, result)

static func _collect_collisions(node: Node, result: Array[CollisionShape3D]) -> void:
	if node is CollisionShape3D and node.shape:
		result.append(node)
	for child in node.get_children():
		_collect_collisions(child, result)

static func _outline_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.75, 1.0, 0.34)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
