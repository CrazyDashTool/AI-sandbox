extends RefCounted

class_name NPCSandboxActions

const BUILD_ITEMS := ["Cube", "Ball", "Cone", "Board", "Wall", "Rock", "Crate", "Chair", "Table", "Bench", "Tree", "Bush", "Beach Blanket", "Barrel", "Lamp", "Wheel", "Gemma Token", "Metal pipe"]

static func build(npc: Node3D, pin := false) -> void:
	var item: String = BUILD_ITEMS.pick_random()
	var prop := build_named(npc, item, pin)
	if prop:
		WorldContext.log_player_action("npc_built_object", {"object": item})
		if pin:
			WorldContext.log_player_action("npc_pinned_object", {"object": item})

static func build_named(npc: Node3D, type_name: String, pin := false) -> RigidBody3D:
	var spawner := npc.get_tree().get_first_node_in_group("object_spawner")
	if not spawner:
		return null
	var forward := -npc.global_transform.basis.z.normalized()
	var pos := npc.global_position + forward * 2.0 + Vector3.UP * 0.4
	var prop: RigidBody3D = spawner.spawn_prop(type_name, pos, Vector3.UP, "npc")
	if pin and prop and prop.has_method("set_pinned"):
		prop.set_pinned(true)
	return prop

static func move_nearby(npc: Node3D) -> void:
	var item := _nearest_prop(npc, 4.2)
	if not item:
		build(npc, false)
		return
	if item.has_method("set_pinned") and item.has_method("is_pinned") and item.is_pinned():
		item.set_pinned(false)
	var forward := -npc.global_transform.basis.z.normalized()
	item.global_position = npc.global_position + forward * 1.8 + Vector3.UP * 0.7
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	WorldContext.log_player_action("npc_moved_object", {"object": _name(item)})

static func pin_nearby(npc: Node3D) -> void:
	var item := _nearest_prop(npc, 4.2)
	if not item:
		build(npc, true)
		return
	if item.has_method("set_pinned"):
		item.set_pinned(true)
		WorldContext.log_player_action("npc_pinned_object", {"object": _name(item)})

static func rotate_nearby(npc: Node3D) -> void:
	var item := _nearest_prop(npc, 4.2)
	if not item:
		return
	if item.has_method("rotate_held"):
		item.rotate_held(Vector3.UP, randf_range(0.35, 1.2))
		WorldContext.log_player_action("npc_rotated_object", {"object": _name(item)})

static func throw_nearby(npc: Node3D) -> void:
	var item := _nearest_prop(npc, 3.2)
	if not item:
		return
	if item.has_method("set_pinned") and item.has_method("is_pinned") and item.is_pinned():
		item.set_pinned(false)
	var forward := -npc.global_transform.basis.z.normalized()
	item.apply_central_impulse((forward + Vector3.UP * 0.25) * 9.0)
	WorldContext.log_player_action("npc_threw_object", {"object": _name(item)})

static func use_nearby(npc: Node3D) -> void:
	var best := _nearest_prop(npc, 3.2)
	if best and best.has_method("interact_with") and best.interact_with(npc):
		return
	if best and best.has_method("_toggle_boombox"):
		best._toggle_boombox()
	elif npc.has_method("use_weapon"):
		npc.use_weapon()

static func use_nearest_interactive(npc: Node3D, preferred_kind := "") -> bool:
	var best: RigidBody3D
	var best_distance := 5.0
	for node in npc.get_tree().get_nodes_in_group("interactive_prop"):
		var item := node as RigidBody3D
		if not item:
			continue
		if preferred_kind != "":
			if not item.has_method("get_interaction_kind") or item.get_interaction_kind() != preferred_kind:
				continue
		var dist := item.global_position.distance_to(npc.global_position)
		if dist < best_distance:
			best = item
			best_distance = dist
	if best and best.has_method("interact_with"):
		return best.interact_with(npc)
	return false

static func use_or_build_interactive(npc: Node3D, type_name: String, preferred_kind: String) -> void:
	if use_nearest_interactive(npc, preferred_kind):
		return
	var prop := build_named(npc, type_name, false)
	if prop and prop.has_method("interact_with"):
		WorldContext.log_player_action("npc_built_object", {"object": type_name})
		prop.interact_with(npc)

static func _nearest_prop(npc: Node3D, max_distance: float) -> RigidBody3D:
	var best: RigidBody3D
	var best_distance := max_distance
	for node in npc.get_tree().get_nodes_in_group("grabbable"):
		var item := node as RigidBody3D
		if not item:
			continue
		var dist := item.global_position.distance_to(npc.global_position)
		if dist < best_distance:
			best = item
			best_distance = dist
	return best

static func _name(item: Node) -> String:
	return item.get_display_name() if item.has_method("get_display_name") else item.name
