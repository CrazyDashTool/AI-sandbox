extends Node3D

const SPLASH := preload("res://scripts/WaterSplash.gd")
const PROP_SOUND := "res://Sounds/Prop in water.mp3"
const CREATURE_SOUND := "res://Sounds/Player or AI in water.mp3"

var inside_counts: Dictionary = {}

func _ready() -> void:
	call_deferred("_setup")

func _setup() -> void:
	for mesh in _water_meshes(get_parent()):
		_make_area(mesh)
	WorldContext.set_water_present(not get_tree().get_nodes_in_group("water_area").is_empty())

func _make_area(mesh: MeshInstance3D) -> void:
	var aabb: AABB = _global_aabb(mesh)
	if aabb.size.x <= 0.01 or aabb.size.z <= 0.01:
		return
	var area := Area3D.new()
	area.name = "WaterArea"
	area.add_to_group("water_area")
	area.collision_layer = 0
	area.collision_mask = 0xffffffff
	area.monitoring = true
	area.monitorable = false
	add_child(area)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var depth: float = max(8.0, aabb.size.y * 4.0)
	box.size = Vector3(aabb.size.x, depth, aabb.size.z)
	shape.shape = box
	var center: Vector3 = aabb.position + aabb.size * 0.5
	area.global_position = Vector3(center.x, aabb.position.y + aabb.size.y - depth * 0.5 + 0.15, center.z)
	area.set_meta("surface_y", aabb.position.y + aabb.size.y)
	area.add_child(shape)
	area.body_entered.connect(func(body: Node3D) -> void: _on_body_entered(body, area))
	area.body_exited.connect(func(body: Node3D) -> void: _on_body_exited(body))

func _on_body_entered(body: Node3D, area: Area3D) -> void:
	if not body:
		return
	var id: int = body.get_instance_id()
	inside_counts[id] = int(inside_counts.get(id, 0)) + 1
	if inside_counts[id] > 1:
		return
	var speed: float = _body_speed(body)
	var surface_y: float = float(area.get_meta("surface_y", body.global_position.y))
	if body.has_method("enter_water"):
		body.enter_water(surface_y, speed)
	SPLASH.spawn(get_tree().current_scene, Vector3(body.global_position.x, surface_y, body.global_position.z), speed)
	_play_sound(PROP_SOUND if body.is_in_group("grabbable") else CREATURE_SOUND, body.global_position, speed)
	_log_entry(body)

func _on_body_exited(body: Node3D) -> void:
	if not body:
		return
	var id: int = body.get_instance_id()
	var count: int = int(inside_counts.get(id, 0)) - 1
	if count > 0:
		inside_counts[id] = count
		return
	inside_counts.erase(id)
	if body.has_method("exit_water"):
		body.exit_water()
	if body.is_in_group("player"):
		WorldContext.set_water_state("player", false)
	elif body.is_in_group("npc"):
		WorldContext.set_water_state("npc", false)

func _body_speed(body: Node) -> float:
	var rigid := body as RigidBody3D
	if rigid:
		return rigid.linear_velocity.length()
	var character := body as CharacterBody3D
	if character:
		return character.velocity.length()
	return 0.0

func _play_sound(path: String, position: Vector3, speed: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream := load(path)
	if not stream:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = GameState.SFX_BUS
	player.global_position = position
	player.volume_db = clamp(-12.0 + speed * 1.15, -12.0, 2.0)
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _log_entry(body: Node3D) -> void:
	if body.is_in_group("player"):
		WorldContext.set_water_state("player", true)
		WorldContext.log_player_action("entered_water")
	elif body.is_in_group("npc"):
		WorldContext.set_water_state("npc", true)
		WorldContext.log_player_action("npc_entered_water")
	elif body.is_in_group("grabbable"):
		var name: String = str(body.get_display_name() if body.has_method("get_display_name") else body.name)
		WorldContext.log_player_action("object_splashed_into_water", {"object": name})

func _water_meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	_collect_water_meshes(root, result)
	return result

func _collect_water_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and _is_water_mesh(node):
		result.append(node)
	for child in node.get_children():
		if child != self:
			_collect_water_meshes(child, result)

func _is_water_mesh(mesh: MeshInstance3D) -> bool:
	if mesh.name.to_lower().contains("water"):
		return true
	var mat: Material = mesh.material_override
	if not mat and mesh.mesh and mesh.mesh.get_surface_count() > 0:
		mat = mesh.mesh.surface_get_material(0)
	if mat is ShaderMaterial and mat.shader:
		return mat.shader.resource_path.to_lower().contains("water")
	return false

func _global_aabb(mesh: MeshInstance3D) -> AABB:
	var local: AABB = mesh.get_aabb()
	var first: Vector3 = mesh.global_transform * local.position
	var result := AABB(first, Vector3.ZERO)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				result = result.expand(mesh.global_transform * (local.position + local.size * Vector3(x, y, z)))
	return result
