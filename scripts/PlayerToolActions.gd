extends RefCounted

class_name PlayerToolActions

const CONSTRUCTION_LINK := preload("res://scripts/ConstructionLink.gd")

static var weld_anchor: RigidBody3D
static var piloted_target: RigidBody3D

static func handle_object_input(event: InputEvent, camera: Camera3D, player: Node3D, held: RigidBody3D, hover: Node) -> RigidBody3D:
	var current := held
	if event.is_action_pressed("pin_object"):
		var target := current if current else hover
		if target and target.has_method("toggle_pinned"):
			var pinned: bool = target.toggle_pinned()
			WorldContext.log_player_action("pinned_object" if pinned else "unpinned_object", {"object": target.get_display_name()})
			if pinned and target == current:
				current.set_held(false)
				current = null
	if current and event is InputEventMouseButton and event.pressed:
		var dir := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0.0
		if dir != 0.0 and current.has_method("rotate_held"):
			var axis := camera.global_transform.basis.y if not Input.is_action_pressed("rotate_object_alt") else camera.global_transform.basis.x
			current.rotate_held(axis, dir * 0.2)
	return current

static func use_selected_tool(tool_name: String, camera: Camera3D, player: Node3D) -> bool:
	var target := _raycast_prop(camera, player, 8.0)
	match tool_name:
		"Weld Tool":
			_use_weld(target)
			return true
		"Float Tool":
			_toggle_float(target)
			return true
		"Motor Tool":
			_toggle_motor(target)
			return true
		"Driver Tool":
			_toggle_driver(target, player)
			return true
	return false

static func _use_weld(target: RigidBody3D) -> void:
	if not target:
		weld_anchor = null
		return
	target = _weld_root(target)
	if not weld_anchor or not is_instance_valid(weld_anchor):
		weld_anchor = target
		WorldContext.log_player_action("weld_anchor_selected", {"object": _name(target)})
		return
	weld_anchor = _weld_root(weld_anchor)
	if weld_anchor == target:
		weld_anchor = null
		return
	var link := CONSTRUCTION_LINK.new()
	link.configure(weld_anchor, target)
	target.freeze = false
	target.set_meta("weld_anchor_path", str(weld_anchor.get_path()))
	weld_anchor.get_tree().current_scene.add_child(link)
	_sync_construction_traits(weld_anchor, target)
	WorldContext.log_player_action("welded_objects", {"anchor": _name(weld_anchor), "object": _name(target)})
	weld_anchor = target

static func _toggle_float(target: RigidBody3D) -> void:
	if target and target.has_method("set_buoyant"):
		var enabled: bool = not target.is_buoyant()
		target.set_buoyant(enabled)
		WorldContext.log_player_action("float_tool_used", {"object": _name(target), "enabled": enabled})

static func _toggle_motor(target: RigidBody3D) -> void:
	if target and target.has_method("set_motorized"):
		var enabled: bool = not target.is_motorized()
		target.set_motorized(enabled)
		WorldContext.log_player_action("motor_tool_used", {"object": _name(target), "enabled": enabled})

static func _toggle_driver(target: RigidBody3D, player: Node3D) -> void:
	if not target or not target.has_method("set_piloted"):
		return
	target = _weld_root(target)
	if piloted_target and is_instance_valid(piloted_target) and piloted_target != target and piloted_target.has_method("set_piloted"):
		piloted_target.set_piloted(null)
	piloted_target = target
	var enabled: bool = target.set_piloted(player)
	if not enabled:
		piloted_target = null
	WorldContext.log_player_action("driver_tool_used", {"object": _name(target), "enabled": enabled})

static func _raycast_prop(camera: Camera3D, player: Node3D, distance: float) -> RigidBody3D:
	var space := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var result := space.intersect_ray(query)
	if result and result.collider is RigidBody3D and result.collider.is_in_group("grabbable"):
		return result.collider
	return null

static func _weld_root(target: RigidBody3D) -> RigidBody3D:
	if target and target.has_meta("weld_anchor_path"):
		var root := target.get_node_or_null(NodePath(str(target.get_meta("weld_anchor_path"))))
		if root is RigidBody3D:
			return root
	return target

static func _sync_construction_traits(a: RigidBody3D, b: RigidBody3D) -> void:
	var motorized := _flag(a, "is_motorized") or _flag(b, "is_motorized")
	var buoyant := _flag(a, "is_buoyant") or _flag(b, "is_buoyant")
	var motor_force: float = max(_float_value(a, "get_motor_force", 34.0), _float_value(b, "get_motor_force", 34.0))
	var turn_force: float = max(_float_value(a, "get_turn_force", 6.0), _float_value(b, "get_turn_force", 6.0))
	for item in [a, b]:
		if motorized and item.has_method("set_motorized"):
			item.set_motorized(true)
		if motorized and item.has_method("set_drive_power"):
			item.set_drive_power(motor_force, turn_force)
		if buoyant and item.has_method("set_buoyant"):
			item.set_buoyant(true)

static func _flag(item: Node, method: String) -> bool:
	return bool(item.call(method)) if item and item.has_method(method) else false

static func _float_value(item: Node, method: String, fallback: float) -> float:
	return float(item.call(method)) if item and item.has_method(method) else fallback

static func _name(item: Node) -> String:
	return item.get_display_name() if item and item.has_method("get_display_name") else "object"
