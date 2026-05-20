extends Node

const NPC_ACTIONS := preload("res://scripts/NPCSandboxActions.gd")
const AVOID_DISTANCE := 2.6
const AVOID_WIDTH := 0.42
const PROP_AVOID_RADIUS := 2.15
const STUCK_TRIGGER_TIME := 0.7
const WALK_JUMP_COOLDOWN := 0.65
const WALK_JUMP_DISTANCE := 1.18
const WALK_JUMP_LOW_HEIGHT := 0.42
const WALK_JUMP_HIGH_HEIGHT := 1.38
const WALK_JUMP_SPEED := 4.95
const WATER_SURFACE_OFFSET := 0.34
const WATER_EXIT_MARGIN := 2.8
const WATER_JUMP_COOLDOWN := 1.0
const WATER_STUCK_TRIGGER_TIME := 0.85
const FOLLOW_START_DISTANCE := 10.0
const FOLLOW_STOP_DISTANCE := 5.5
const VIEW_DOT_MIN := 0.18
const ROUTE_REACHED_DISTANCE := 1.15
const COLLECT_PICKUP_DISTANCE := 1.55
const COLLECT_DROP_DISTANCE := 1.45
const COLLECT_MAX_ITEMS := 10
const SMART_TARGET_MAX_SNAP := 90.0
const FLEE_DURATION := 11.0
const FLEE_REPLAN_INTERVAL := 0.7
const FLEE_STOP_DISTANCE := 14.0
const FLEE_COMFORT_DISTANCE := 19.0
const FLEE_TARGET_REACHED_DISTANCE := 2.3
const FLEE_MIN_CANDIDATE_DISTANCE := 8.5
const FLEE_MAX_CANDIDATE_DISTANCE := 24.0
const FLEE_PLAYER_MOVE_REPLAN := 2.0
const PERSONAL_SPACE_DISTANCE := 0.72
const PERSONAL_SPACE_APPROACH_SPEED := 2.2
const PERSONAL_SPACE_NUDGE_SPEED := 1.25
const PERSONAL_SPACE_COOLDOWN := 0.75
const FLINCH_APPROACH_DISTANCE := 1.15
const FLINCH_APPROACH_SPEED := 8.0
const PASSIVE_LOOK_DISTANCE := 22.0
const PASSIVE_LOOK_YAW_LIMIT := 2.45
const PASSIVE_LOOK_PITCH_LIMIT := 0.62

var npc: CharacterBody3D
var agent: NavigationAgent3D
var visual_root: Node3D
var head_node: Node3D
var left_arm: Node3D
var right_arm: Node3D
var current_action := "idle"
var current_emotion := "neutral"
var target_position := Vector3.ZERO
var speed_variation := 0.0
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var bob_time := 0.0
var idle_timer := 0.0
var flinch_timer := 0.0
var wave_timer := 0.0
var jump_request := false
var in_water := false
var water_surface_y := 0.0
var avoid_side := 1.0
var stuck_timer := 0.0
var stuck_escape_timer := 0.0
var last_position := Vector3.ZERO
var follow_side := 1.0
var look_at_player_timer := 0.0
var jump_cooldown := 0.0
var water_jump_cooldown := 0.0
var water_stuck_timer := 0.0
var water_last_position := Vector3.ZERO
var last_dry_position := Vector3.ZERO
var water_escape_position := Vector3.ZERO
var water_escape_active := false
var route_points: Array[Vector3] = []
var route_names: Array[String] = []
var route_index := 0
var route_active := false
var route_follow_player_at_end := false
var collect_active := false
var collect_items: Array[RigidBody3D] = []
var collect_index := 0
var collect_stage := ""
var collect_item_type := ""
var collect_all := false
var collect_search_center := Vector3.ZERO
var collect_search_radius := 0.0
var collect_drop_position := Vector3.ZERO
var collect_drop_to_player := false
var carried_item: RigidBody3D
var prop_interaction_timer := 0.0
var flee_active := false
var flee_timer := 0.0
var flee_replan_timer := 0.0
var flee_target := Vector3.ZERO
var flee_last_player_position := Vector3.ZERO
var personal_space_cooldown := 0.0

func _ready() -> void:
	npc = get_parent() as CharacterBody3D
	if npc:
		last_position = npc.global_position
		water_last_position = npc.global_position
		last_dry_position = npc.global_position
		water_escape_position = npc.global_position
	call_deferred("_setup_agent")

func bind_visual(root: Node3D, head: Node3D, left: Node3D, right: Node3D) -> void:
	visual_root = root
	head_node = head
	left_arm = left
	right_arm = right

func get_status_text() -> String:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_distance := npc.global_position.distance_to(player.global_position) if player else 0.0
	if flee_active:
		return "fleeing from player; %.1fs left; player distance %.1f; target %.1f, %.1f, %.1f" % [flee_timer, player_distance, flee_target.x, flee_target.y, flee_target.z]
	if route_active:
		return "following route point %d of %d toward %.1f, %.1f, %.1f" % [route_index + 1, route_points.size(), target_position.x, target_position.y, target_position.z]
	if collect_active:
		return "collecting items; stage %s; target %.1f, %.1f, %.1f" % [collect_stage, target_position.x, target_position.y, target_position.z]
	return "action %s; target %.1f, %.1f, %.1f" % [current_action, target_position.x, target_position.y, target_position.z]

func start_route(points: Array, names: Array = [], follow_player_at_end: bool = false) -> void:
	_clear_flee()
	_clear_collect_task()
	route_points.clear()
	route_names.clear()
	for point in points:
		if typeof(point) == TYPE_VECTOR3:
			route_points.append(point)
	for name in names:
		route_names.append(str(name))
	if route_points.is_empty():
		return
	route_index = 0
	route_active = true
	route_follow_player_at_end = follow_player_at_end
	current_action = "walk_route"
	current_emotion = "neutral"
	speed_variation = randf_range(-0.2, 0.25)
	_set_target(route_points[route_index])

func start_collect_task(command: Dictionary) -> void:
	_clear_flee()
	_clear_route()
	_clear_collect_task()
	collect_item_type = str(command.get("item_type", ""))
	collect_all = bool(command.get("collect_all", false))
	var search_value: Variant = command.get("search_center", npc.global_position)
	collect_search_center = search_value if typeof(search_value) == TYPE_VECTOR3 else npc.global_position
	collect_search_radius = float(command.get("search_radius", 18.0))
	var drop_value: Variant = command.get("drop_position", npc.global_position)
	collect_drop_position = drop_value if typeof(drop_value) == TYPE_VECTOR3 else npc.global_position
	collect_drop_to_player = bool(command.get("drop_to_player", false))
	collect_stage = "to_source" if bool(command.get("explicit_source", false)) and npc.global_position.distance_to(collect_search_center) > 2.5 else "to_item"
	collect_active = true
	collect_index = 0
	current_action = "collect_items"
	current_emotion = "curious"
	speed_variation = randf_range(-0.15, 0.25)
	if collect_stage == "to_source":
		_set_target(collect_search_center)
	else:
		_refresh_collect_items()
		_target_next_collect_item()

func perform_action(action: String, emotion: String) -> void:
	current_action = action
	current_emotion = emotion
	speed_variation = randf_range(-0.3, 0.3)
	_clear_route()
	_clear_collect_task()
	_clear_flee()
	if action.begins_with("walk_to_known_place_"):
		_walk_to_known_place(action)
		return
	match action:
		"walk_to_player":
			_walk_to_player()
		"walk_to_construction_1", "walk_to_construction_2", "walk_to_construction_3":
			_walk_to_construction(action)
		"walk_to_known_place_1", "walk_to_known_place_2", "walk_to_known_place_3", "walk_to_known_place_4", "walk_to_known_place_5":
			_walk_to_known_place(action)
		"jump":
			jump_request = true
		"run_away":
			_run_away()
		"wave":
			wave_timer = 1.8
		"use_weapon":
			if npc.has_method("use_weapon"):
				npc.use_weapon()
		"build_random_prop":
			NPC_ACTIONS.build(npc, false)
		"build_and_pin_prop":
			NPC_ACTIONS.build(npc, true)
		"move_nearby_item":
			NPC_ACTIONS.move_nearby(npc)
		"pin_nearby_item":
			NPC_ACTIONS.pin_nearby(npc)
		"rotate_nearby_item":
			NPC_ACTIONS.rotate_nearby(npc)
		"throw_nearby_item":
			NPC_ACTIONS.throw_nearby(npc)
		"use_nearby_item":
			NPC_ACTIONS.use_nearby(npc)
		"sit_on_bench":
			NPC_ACTIONS.use_or_build_interactive(npc, "Bench", "bench")
		"sit_on_chair":
			NPC_ACTIONS.use_or_build_interactive(npc, "Chair", "chair")
		"relax_on_blanket":
			NPC_ACTIONS.use_or_build_interactive(npc, "Beach Blanket", "blanket")
		"swim_in_water":
			_swim_to_water()
		"look_at_player":
			look_at_player(2.4)
			_set_target(npc.global_position)
		"look_around":
			idle_timer = 0.0
		"sit":
			target_position = npc.global_position
		_:
			target_position = npc.global_position

func flinch() -> void:
	flinch_timer = 0.45
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		var away: Vector3 = (npc.global_position - player.global_position).normalized()
		npc.velocity.x = away.x * 4.0
		npc.velocity.z = away.z * 4.0

func _physics_process(delta: float) -> void:
	if not npc or not agent:
		return
	prop_interaction_timer = max(0.0, prop_interaction_timer - delta)
	jump_cooldown = max(0.0, jump_cooldown - delta)
	personal_space_cooldown = max(0.0, personal_space_cooldown - delta)
	if not in_water:
		_remember_dry_position()
	_react_to_player()
	_keep_near_player_view()
	_update_flee(delta)
	_update_route_task()
	_update_collect_task(delta)
	var desired := _desired_direction()
	if in_water:
		_swim(delta, desired)
		return
	if jump_request and npc.is_on_floor():
		npc.velocity.y = 4.6
		jump_request = false
	if not npc.is_on_floor():
		npc.velocity.y -= gravity * delta
	var target_speed: float = _speed()
	var jumped_over_obstacle := _maybe_jump_while_moving(desired)
	if not jumped_over_obstacle:
		desired = _avoid_obstacles(desired, delta)
	var target_vel: Vector3 = desired * target_speed
	npc.velocity.x = lerp(npc.velocity.x, target_vel.x, min(1.0, delta * 7.0))
	npc.velocity.z = lerp(npc.velocity.z, target_vel.z, min(1.0, delta * 7.0))
	npc.move_and_slide()
	_update_stuck_state(delta, desired)
	_update_body(delta, desired)
	_update_look_at_player(delta)

func _setup_agent() -> void:
	agent = NavigationAgent3D.new()
	agent.name = "NavigationAgent3D"
	agent.path_desired_distance = 0.35
	agent.target_desired_distance = 0.7
	npc.add_child(agent)
	target_position = npc.global_position
	agent.target_position = target_position

func _set_target(pos: Vector3) -> void:
	target_position = _resolve_walk_target(pos)
	if agent:
		agent.target_position = target_position

func _set_swim_target(pos: Vector3) -> void:
	target_position = _resolve_walk_target(pos, true)
	if agent:
		agent.target_position = target_position

func _clear_route() -> void:
	route_active = false
	route_follow_player_at_end = false
	route_points.clear()
	route_names.clear()
	route_index = 0

func _clear_flee() -> void:
	flee_active = false
	flee_timer = 0.0
	flee_replan_timer = 0.0

func _clear_collect_task() -> void:
	if carried_item and is_instance_valid(carried_item):
		_drop_collect_item(false)
	collect_active = false
	collect_items.clear()
	collect_index = 0
	collect_stage = ""
	collect_drop_to_player = false
	carried_item = null

func start_prop_interaction(kind: String, prop: Node3D) -> void:
	if not prop:
		return
	_clear_flee()
	_clear_route()
	_clear_collect_task()
	npc.velocity = Vector3.ZERO
	if kind == "bench":
		npc.global_position = prop.global_position + Vector3.UP * 0.8
		current_action = "sit"
		current_emotion = "happy"
		prop_interaction_timer = 5.5
	elif kind == "seat":
		npc.global_position = prop.global_position + Vector3.UP * float(prop.get_meta("seat_height", 0.65))
		current_action = "sit"
		current_emotion = "happy"
		prop_interaction_timer = 5.5
	elif kind == "blanket":
		npc.global_position = prop.global_position + Vector3.UP * 0.35
		current_action = "relax"
		current_emotion = "curious"
		prop_interaction_timer = 7.0
	_set_target(npc.global_position)

func _update_route_task() -> void:
	if not route_active:
		return
	if route_index >= route_points.size():
		_finish_route()
		return
	_update_route_player_target()
	if _reached_target(ROUTE_REACHED_DISTANCE):
		route_index += 1
		if route_index >= route_points.size():
			_finish_route()
		else:
			_update_route_player_target()
			_set_target(route_points[route_index])

func _finish_route() -> void:
	route_active = false
	route_follow_player_at_end = false
	current_action = "idle"
	_set_target(npc.global_position)

func _update_route_player_target() -> void:
	if not route_follow_player_at_end or route_index != route_points.size() - 1:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	route_points[route_index] = player.global_position
	_set_target(player.global_position)

func _update_collect_task(_delta: float) -> void:
	if not collect_active:
		return
	_update_carried_item()
	match collect_stage:
		"to_source":
			if _reached_target(ROUTE_REACHED_DISTANCE):
				_refresh_collect_items()
				collect_stage = "to_item"
				_target_next_collect_item()
		"to_item":
			_prune_collect_items()
			if collect_index >= collect_items.size():
				_finish_collect_task()
				return
			var item := collect_items[collect_index]
			if not item or not is_instance_valid(item):
				collect_index += 1
				_target_next_collect_item()
				return
			_set_target(item.global_position)
			if npc.global_position.distance_to(item.global_position) <= COLLECT_PICKUP_DISTANCE:
				_pickup_collect_item(item)
				collect_stage = "to_drop"
				_set_target(collect_drop_position)
		"to_drop":
			if carried_item and is_instance_valid(carried_item):
				_update_carried_item()
			_update_collect_drop_position()
			if _reached_target(COLLECT_DROP_DISTANCE):
				_drop_collect_item(true)
				collect_index += 1
				if collect_index >= collect_items.size():
					_finish_collect_task()
				else:
					collect_stage = "to_item"
					_target_next_collect_item()

func _target_next_collect_item() -> void:
	_prune_collect_items()
	if collect_index >= collect_items.size():
		_finish_collect_task()
		return
	var item := collect_items[collect_index]
	if item and is_instance_valid(item):
		_set_target(item.global_position)

func _refresh_collect_items() -> void:
	collect_items.clear()
	var candidates: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("grabbable"):
		var item := node as RigidBody3D
		if not item or item == carried_item or not item.is_inside_tree():
			continue
		if item.has_method("is_pinned") and item.is_pinned():
			continue
		if not _collect_item_matches_type(item):
			continue
		var distance := item.global_position.distance_to(collect_search_center)
		if distance > collect_search_radius:
			continue
		candidates.append({"item": item, "distance": distance})
	candidates.sort_custom(_sort_collect_candidates)
	var limit := COLLECT_MAX_ITEMS if collect_all else 1
	for i in min(limit, candidates.size()):
		collect_items.append(candidates[i].item)

func _prune_collect_items() -> void:
	for i in range(collect_items.size() - 1, -1, -1):
		var item := collect_items[i]
		if not item or not is_instance_valid(item) or not item.is_inside_tree():
			collect_items.remove_at(i)
			if i <= collect_index and collect_index > 0:
				collect_index -= 1

func _sort_collect_candidates(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0))

func _collect_item_matches_type(item: RigidBody3D) -> bool:
	if collect_item_type == "":
		return true
	var display_name := _item_display_name(item).to_lower()
	var target_name := collect_item_type.to_lower()
	return display_name == target_name or display_name.find(target_name) >= 0 or target_name.find(display_name) >= 0

func _item_display_name(item: RigidBody3D) -> String:
	return str(item.get_display_name() if item.has_method("get_display_name") else item.name)

func _pickup_collect_item(item: RigidBody3D) -> void:
	carried_item = item
	if carried_item.has_method("set_held"):
		carried_item.set_held(true)
	carried_item.sleeping = false
	carried_item.freeze = false
	_update_carried_item()

func _update_carried_item() -> void:
	if not carried_item or not is_instance_valid(carried_item):
		carried_item = null
		return
	var forward := -npc.global_transform.basis.z.normalized()
	var carry_target := npc.global_position + forward * 1.15 + Vector3.UP * 1.0
	carried_item.linear_velocity = (carry_target - carried_item.global_position) * 12.0
	carried_item.angular_velocity = carried_item.angular_velocity.lerp(Vector3.ZERO, 0.3)

func _update_collect_drop_position() -> void:
	if not collect_drop_to_player:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		collect_drop_position = player.global_position
		_set_target(collect_drop_position)

func _drop_collect_item(place_near_drop: bool) -> void:
	if not carried_item or not is_instance_valid(carried_item):
		carried_item = null
		return
	var item := carried_item
	carried_item = null
	if item.has_method("set_held"):
		item.set_held(false)
	if place_near_drop:
		var angle := float(collect_index % 8) / 8.0 * TAU
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * 1.25
		item.global_position = collect_drop_position + offset + Vector3.UP * 0.75
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO

func _finish_collect_task() -> void:
	if carried_item and is_instance_valid(carried_item):
		_drop_collect_item(true)
	collect_active = false
	collect_items.clear()
	collect_stage = ""
	current_action = "idle"
	_set_target(npc.global_position)

func _reached_target(distance: float) -> bool:
	if target_position.distance_to(npc.global_position) <= distance:
		return true
	return agent != null and agent.is_navigation_finished()

func _resolve_walk_target(pos: Vector3, allow_water: bool = false) -> Vector3:
	var resolved := pos
	if not allow_water and _is_point_submerged_in_any_water(resolved):
		resolved = _nearest_dry_position(resolved)
	if agent:
		var navigation_map := agent.get_navigation_map()
		if navigation_map.is_valid():
			var closest := NavigationServer3D.map_get_closest_point(navigation_map, resolved)
			if closest.distance_to(resolved) <= SMART_TARGET_MAX_SNAP:
				resolved = closest
	return resolved

func _nearest_dry_position(origin: Vector3) -> Vector3:
	if not _is_point_submerged_in_any_water(origin):
		return origin
	var best := npc.global_position
	var best_distance := INF
	for radius in [2.5, 4.5, 7.0, 10.0]:
		for step in 12:
			var angle := TAU * float(step) / 12.0
			var candidate := origin + Vector3(cos(angle), 0.0, sin(angle)) * float(radius)
			if _is_point_submerged_in_any_water(candidate):
				continue
			var distance := candidate.distance_to(npc.global_position)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best

func _start_ground_jump(strength: float = WALK_JUMP_SPEED) -> void:
	npc.velocity.y = max(npc.velocity.y, strength)
	jump_cooldown = WALK_JUMP_COOLDOWN
	jump_request = false

func _remember_dry_position() -> void:
	if not npc:
		return
	if _is_point_submerged_in_any_water(npc.global_position):
		return
	last_dry_position = npc.global_position

func _walk_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	var away: Vector3 = (npc.global_position - player.global_position).normalized()
	_set_target(player.global_position + away * 1.8)

func _walk_to_construction(action: String) -> void:
	var index := int(action.get_slice("_", 3)) - 1
	if index >= 0 and index < WorldContext.constructions.size():
		var construction: Dictionary = WorldContext.constructions[index]
		_set_target(construction.center)

func _walk_to_known_place(action: String) -> void:
	var index := int(action.get_slice("_", 4)) - 1
	var place: Dictionary = WorldContext.get_known_place_by_index(index)
	if place.is_empty():
		return
	_set_target(place.position)

func _run_away() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	flee_active = true
	flee_timer = FLEE_DURATION
	flee_replan_timer = 0.0
	flee_last_player_position = player.global_position
	current_action = "run_away"
	current_emotion = "scared"
	_plan_flee_target(true)

func _swim_to_water() -> void:
	var best: Area3D
	var best_distance := INF
	for area in get_tree().get_nodes_in_group("water_area"):
		var water := area as Area3D
		if not water:
			continue
		var dist := npc.global_position.distance_to(water.global_position)
		if dist < best_distance:
			best = water
			best_distance = dist
	if best:
		_set_swim_target(Vector3(best.global_position.x, float(best.get_meta("surface_y", best.global_position.y)), best.global_position.z))

func enter_water(surface_y: float, _speed: float) -> void:
	in_water = true
	water_surface_y = surface_y
	water_stuck_timer = 0.0
	water_last_position = npc.global_position
	water_jump_cooldown = 0.0
	water_escape_position = _select_water_escape_position()
	water_escape_active = true

func exit_water() -> void:
	in_water = false
	water_stuck_timer = 0.0
	water_escape_active = false
	_remember_dry_position()

func _react_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		return
	var to_npc: Vector3 = npc.global_position - player.global_position
	to_npc.y = 0.0
	var distance: float = to_npc.length()
	if distance <= 0.05:
		return
	var away := to_npc.normalized()
	var approach_speed := player.velocity.dot(away)
	if distance < FLINCH_APPROACH_DISTANCE and approach_speed > FLINCH_APPROACH_SPEED and flinch_timer <= 0.0 and personal_space_cooldown <= 0.0:
		flinch()
		personal_space_cooldown = PERSONAL_SPACE_COOLDOWN
	elif not _has_locked_target() and distance < PERSONAL_SPACE_DISTANCE and approach_speed > PERSONAL_SPACE_APPROACH_SPEED and personal_space_cooldown <= 0.0:
		npc.velocity.x += away.x * PERSONAL_SPACE_NUDGE_SPEED
		npc.velocity.z += away.z * PERSONAL_SPACE_NUDGE_SPEED
		personal_space_cooldown = PERSONAL_SPACE_COOLDOWN

func look_at_player(seconds: float = 1.8) -> void:
	look_at_player_timer = max(look_at_player_timer, seconds)

func _update_flee(delta: float) -> void:
	if not flee_active:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		_clear_flee()
		return
	flee_timer = max(0.0, flee_timer - delta)
	flee_replan_timer = max(0.0, flee_replan_timer - delta)
	var flat_to_player := npc.global_position - player.global_position
	flat_to_player.y = 0.0
	var distance := flat_to_player.length()
	var player_moved := player.global_position.distance_to(flee_last_player_position)
	var reached_target := npc.global_position.distance_to(flee_target) <= FLEE_TARGET_REACHED_DISTANCE or agent.is_navigation_finished()
	var target_bad := _is_point_submerged_in_any_water(flee_target) or flee_target.distance_to(player.global_position) < FLEE_STOP_DISTANCE
	if flee_timer <= 0.0 and distance >= FLEE_STOP_DISTANCE:
		_finish_flee()
		return
	if distance < FLEE_STOP_DISTANCE or reached_target or target_bad or flee_replan_timer <= 0.0 or player_moved >= FLEE_PLAYER_MOVE_REPLAN:
		_plan_flee_target(false)

func _finish_flee() -> void:
	_clear_flee()
	current_action = "idle"
	_set_target(npc.global_position)

func _plan_flee_target(force: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	var away := npc.global_position - player.global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = -player.global_transform.basis.z
		away.y = 0.0
	if away.length() < 0.05:
		away = Vector3.FORWARD
	away = away.normalized()
	var best := flee_target
	var best_score := -INF
	for distance in [FLEE_COMFORT_DISTANCE, FLEE_COMFORT_DISTANCE * 0.75, FLEE_MAX_CANDIDATE_DISTANCE, FLEE_MIN_CANDIDATE_DISTANCE]:
		for angle in [0.0, 22.0, -22.0, 45.0, -45.0, 75.0, -75.0, 115.0, -115.0, 160.0, -160.0]:
			var dir := away.rotated(Vector3.UP, deg_to_rad(float(angle))).normalized()
			var raw_candidate := npc.global_position + dir * float(distance)
			var candidate := _resolve_walk_target(raw_candidate)
			var score := _score_flee_candidate(candidate, player.global_position, away, dir)
			if score > best_score:
				best_score = score
				best = candidate
	if not force and best.distance_to(flee_target) < 1.0 and target_position.distance_to(npc.global_position) > FLEE_TARGET_REACHED_DISTANCE:
		flee_replan_timer = FLEE_REPLAN_INTERVAL
		return
	flee_target = best
	flee_last_player_position = player.global_position
	flee_replan_timer = FLEE_REPLAN_INTERVAL
	_set_target(flee_target)

func _score_flee_candidate(candidate: Vector3, player_position: Vector3, away: Vector3, direction: Vector3) -> float:
	if _is_point_submerged_in_any_water(candidate):
		return -100000.0
	var from_player := candidate - player_position
	from_player.y = 0.0
	var candidate_distance := from_player.length()
	if candidate_distance < FLEE_MIN_CANDIDATE_DISTANCE:
		return -10000.0 + candidate_distance
	var score := candidate_distance * 4.0
	score += max(0.0, direction.dot(away)) * 12.0
	score += _direction_clearance(npc.global_position + Vector3.UP * 0.72, direction, AVOID_DISTANCE * 1.4) * 2.2
	if candidate_distance >= FLEE_STOP_DISTANCE:
		score += 24.0
	if candidate_distance > FLEE_COMFORT_DISTANCE:
		score -= (candidate_distance - FLEE_COMFORT_DISTANCE) * 0.85
	if _has_cover_from_player(candidate, player_position):
		score += 10.0
	score -= _nearby_obstacle_density(candidate) * 5.0
	return score

func _has_cover_from_player(candidate: Vector3, player_position: Vector3) -> bool:
	var from := candidate + Vector3.UP * 1.1
	var to := player_position + Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var exclude: Array[RID] = [npc.get_rid()]
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	query.exclude = exclude
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := npc.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()

func _nearby_obstacle_density(point: Vector3) -> float:
	var density := 0.0
	for node in get_tree().get_nodes_in_group("ai_obstacle"):
		var obstacle := node as Node3D
		if not obstacle or obstacle == npc or not obstacle.is_inside_tree():
			continue
		var distance := point.distance_to(obstacle.global_position)
		if distance < PROP_AVOID_RADIUS:
			density += (PROP_AVOID_RADIUS - distance) / PROP_AVOID_RADIUS
	return density

func _keep_near_player_view() -> void:
	if not _allows_passive_follow():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		return
	var to_npc: Vector3 = npc.global_position - player.global_position
	to_npc.y = 0.0
	var distance := to_npc.length()
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.05:
		forward = -player.global_transform.basis.z
	forward = forward.normalized()
	var in_view := false
	if distance > 0.05:
		in_view = forward.dot(to_npc.normalized()) >= VIEW_DOT_MIN
	if distance <= FOLLOW_STOP_DISTANCE and in_view:
		return
	if distance < FOLLOW_START_DISTANCE and in_view and not agent.is_navigation_finished():
		return
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.05:
		right = Vector3(-forward.z, 0.0, forward.x)
	right = right.normalized()
	if distance > 0.05 and right.dot(to_npc.normalized()) < 0.0:
		follow_side = -1.0
	else:
		follow_side = 1.0
	var target: Vector3 = player.global_position + forward * 6.2 + right * follow_side * 2.4
	target.y = player.global_position.y
	if target_position.distance_to(target) > 1.35:
		_set_target(target)

func _allows_passive_follow() -> bool:
	return current_action == "walk_to_player"

func _has_locked_target() -> bool:
	return flee_active or route_active or collect_active or current_action == "sit" or current_action == "relax" or current_action.begins_with("walk_to_known_place_") or current_action.begins_with("walk_to_construction_")

func _speed() -> float:
	var base := 3.5 + speed_variation
	if flee_active or current_action == "run_away":
		return base + 2.1
	if current_action == "walk_route":
		return base + 0.25
	if current_action == "collect_items":
		return base + 0.15
	match current_emotion:
		"happy":
			return base + 0.35
		"scared":
			return base + 1.6
		"curious":
			return base - 0.8
		"annoyed":
			return base - 0.45
	return base

func _desired_direction() -> Vector3:
	if agent.is_navigation_finished():
		return Vector3.ZERO
	var next: Vector3 = agent.get_next_path_position()
	var desired := next - npc.global_position
	desired.y = 0.0
	return desired.normalized() if desired.length() > 0.1 else Vector3.ZERO

func _maybe_jump_while_moving(direction: Vector3) -> bool:
	if direction.length() < 0.05 or jump_cooldown > 0.0 or not npc.is_on_floor():
		return false
	if target_position.distance_to(npc.global_position) < 1.0:
		return false
	var forward: Vector3 = direction.normalized()
	if _jumpable_obstacle_ahead(forward) or _higher_ground_ahead(forward):
		_start_ground_jump(WALK_JUMP_SPEED)
		stuck_timer = 0.0
		return true
	return false

func _jumpable_obstacle_ahead(direction: Vector3) -> bool:
	var low_origin: Vector3 = npc.global_position + Vector3.UP * WALK_JUMP_LOW_HEIGHT
	var low_hit: Dictionary = _cast_obstacle_ray(low_origin, direction, WALK_JUMP_DISTANCE)
	if low_hit.is_empty():
		return false
	var hit_position: Vector3 = low_hit.get("position", low_origin)
	if hit_position.y > npc.global_position.y + 1.08:
		return false
	return _high_path_clear(direction)

func _higher_ground_ahead(direction: Vector3) -> bool:
	var ahead: Vector3 = npc.global_position + direction.normalized() * 0.95 + Vector3.UP * 1.35
	var query := PhysicsRayQueryParameters3D.create(ahead, ahead - Vector3.UP * 2.3)
	query.exclude = [npc.get_rid()]
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := npc.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var position: Vector3 = hit.get("position", ahead)
	var height_delta: float = position.y - npc.global_position.y
	return height_delta > 0.26 and height_delta < 1.05 and _high_path_clear(direction)

func _high_path_clear(direction: Vector3) -> bool:
	var high_origin: Vector3 = npc.global_position + Vector3.UP * WALK_JUMP_HIGH_HEIGHT
	return _cast_obstacle_ray(high_origin, direction, WALK_JUMP_DISTANCE + 0.25).is_empty()

func _avoid_obstacles(direction: Vector3, delta: float) -> Vector3:
	if direction.length() < 0.05:
		return direction
	var forward: Vector3 = direction.normalized()
	var origin: Vector3 = npc.global_position + Vector3.UP * 0.72
	var forward_clearance: float = _direction_clearance(origin, forward, AVOID_DISTANCE)
	var steering: Vector3 = forward
	var blocked: bool = forward_clearance < AVOID_DISTANCE * 0.92
	if blocked or stuck_escape_timer > 0.0:
		var best_dir: Vector3 = forward
		var best_score: float = -INF
		for angle in [-85.0, -55.0, -30.0, 0.0, 30.0, 55.0, 85.0]:
			var angle_value: float = float(angle)
			var candidate: Vector3 = forward.rotated(Vector3.UP, deg_to_rad(angle_value)).normalized()
			var clearance: float = _direction_clearance(origin, candidate, AVOID_DISTANCE)
			var side: float = sign(angle_value)
			var score: float = clearance + max(0.0, candidate.dot(forward)) * 0.75
			if side != 0.0 and side == avoid_side:
				score += 0.2
			if score > best_score:
				best_score = score
				best_dir = candidate
				if side != 0.0:
					avoid_side = side
		steering = best_dir
		if stuck_escape_timer > 0.0:
			var side_dir := Vector3(-forward.z, 0.0, forward.x).normalized() * avoid_side
			steering = (steering + side_dir * 1.15).normalized()
			stuck_escape_timer = max(0.0, stuck_escape_timer - delta)
	var push := _nearby_obstacle_push()
	if push.length() > 0.01:
		steering = (steering + push).normalized()
	return steering if steering.length() > 0.05 else forward

func _direction_clearance(origin: Vector3, direction: Vector3, distance: float) -> float:
	var dir := direction.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x).normalized()
	var center := _ray_clearance(origin, dir, distance)
	var left := _ray_clearance(origin + side * AVOID_WIDTH, dir, distance)
	var right := _ray_clearance(origin - side * AVOID_WIDTH, dir, distance)
	return min(center, min(left, right))

func _ray_clearance(origin: Vector3, direction: Vector3, distance: float) -> float:
	var hit := _cast_obstacle_ray(origin, direction, distance)
	if hit.is_empty():
		return distance
	return origin.distance_to(hit.position)

func _cast_obstacle_ray(origin: Vector3, direction: Vector3, distance: float) -> Dictionary:
	if not npc or direction.length() < 0.01:
		return {}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * distance)
	query.exclude = [npc.get_rid()]
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := npc.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	var position: Vector3 = hit.get("position", origin)
	if normal.dot(Vector3.UP) > 0.72 and position.y < npc.global_position.y + 0.35:
		return {}
	return hit

func _nearby_obstacle_push() -> Vector3:
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("ai_obstacle"):
		var obstacle := node as Node3D
		if not obstacle or obstacle == npc or not obstacle.is_inside_tree():
			continue
		var away := npc.global_position - obstacle.global_position
		away.y = 0.0
		var distance := away.length()
		if distance <= 0.05 or distance >= PROP_AVOID_RADIUS:
			continue
		var strength := (PROP_AVOID_RADIUS - distance) / PROP_AVOID_RADIUS
		push += away.normalized() * strength * 1.25
	return push

func _update_stuck_state(delta: float, desired: Vector3) -> void:
	if desired.length() < 0.05 or target_position.distance_to(npc.global_position) < 1.0:
		stuck_timer = 0.0
		last_position = npc.global_position
		return
	var moved := npc.global_position.distance_to(last_position)
	last_position = npc.global_position
	if moved < 0.025:
		stuck_timer += delta
	else:
		stuck_timer = max(0.0, stuck_timer - delta * 2.0)
	if stuck_timer >= STUCK_TRIGGER_TIME:
		if npc.is_on_floor() and jump_cooldown <= 0.0 and desired.length() > 0.05 and _high_path_clear(desired.normalized()):
			_start_ground_jump(WALK_JUMP_SPEED + 0.35)
		avoid_side *= -1.0
		stuck_escape_timer = 0.85
		if flee_active:
			_plan_flee_target(true)
		stuck_timer = 0.0

func _swim(delta: float, desired: Vector3) -> void:
	water_jump_cooldown = max(0.0, water_jump_cooldown - delta)
	var swim_direction: Vector3 = desired
	if current_action != "swim_in_water":
		water_escape_position = _select_water_escape_position()
		water_escape_active = true
		var to_escape: Vector3 = water_escape_position - npc.global_position
		to_escape.y = 0.0
		if desired.length() < 0.05 or target_position.distance_to(npc.global_position) < 1.0 or water_stuck_timer > 0.25 or _is_point_submerged_in_any_water(target_position):
			swim_direction = to_escape.normalized() if to_escape.length() > 0.05 else Vector3.ZERO
	if swim_direction.length() > 0.05:
		swim_direction = swim_direction.normalized()
	var target_vel: Vector3 = swim_direction * max(2.6, _speed() * 0.78)
	target_vel.y = clamp((water_surface_y - WATER_SURFACE_OFFSET - npc.global_position.y) * 2.35, -1.4, 2.35)
	var near_exit := false
	if water_escape_active:
		var flat_to_exit: Vector3 = water_escape_position - npc.global_position
		flat_to_exit.y = 0.0
		near_exit = flat_to_exit.length() < 2.4
	var should_leap := jump_request or (swim_direction.length() > 0.05 and (near_exit or water_stuck_timer >= WATER_STUCK_TRIGGER_TIME))
	if should_leap and water_jump_cooldown <= 0.0:
		target_vel.y = max(target_vel.y, 7.0)
		npc.velocity.y = max(npc.velocity.y, 7.0)
		npc.velocity.x += swim_direction.x * 2.1
		npc.velocity.z += swim_direction.z * 2.1
		water_jump_cooldown = WATER_JUMP_COOLDOWN
		water_stuck_timer = 0.0
		jump_request = false
	npc.velocity.x = lerp(npc.velocity.x, target_vel.x, min(1.0, delta * 4.5))
	npc.velocity.y = lerp(npc.velocity.y, target_vel.y, min(1.0, delta * 3.5))
	npc.velocity.z = lerp(npc.velocity.z, target_vel.z, min(1.0, delta * 4.5))
	npc.move_and_slide()
	_update_water_stuck_state(delta, swim_direction)
	if not _is_point_in_any_water_xz(npc.global_position) and npc.global_position.y > water_surface_y - 0.25:
		exit_water()
		WorldContext.set_water_state("npc", false)
	_update_body(delta, swim_direction)
	_update_look_at_player(delta)

func _update_water_stuck_state(delta: float, desired: Vector3) -> void:
	if desired.length() < 0.05:
		water_stuck_timer = 0.0
		water_last_position = npc.global_position
		return
	var current_flat := Vector2(npc.global_position.x, npc.global_position.z)
	var last_flat := Vector2(water_last_position.x, water_last_position.z)
	var moved: float = current_flat.distance_to(last_flat)
	water_last_position = npc.global_position
	if moved < 0.018:
		water_stuck_timer += delta
	else:
		water_stuck_timer = max(0.0, water_stuck_timer - delta * 2.0)

func _select_water_escape_position() -> Vector3:
	if _uses_current_target_in_water() and _is_good_water_escape_position(target_position):
		return target_position
	if _is_good_water_escape_position(last_dry_position):
		return last_dry_position
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and _is_good_water_escape_position(player.global_position):
		return player.global_position
	var exit_info: Dictionary = _nearest_water_exit_target()
	if not exit_info.is_empty():
		return exit_info.position
	return npc.global_position

func _uses_current_target_in_water() -> bool:
	if current_action == "swim_in_water" or current_action == "idle" or current_action == "sit" or current_action == "relax" or current_action == "look_at_player" or current_action == "look_around":
		return false
	return target_position.distance_to(npc.global_position) > 0.7

func _is_good_water_escape_position(position: Vector3) -> bool:
	if position.distance_to(npc.global_position) < 0.45:
		return false
	return not _is_point_submerged_in_any_water(position)

func _nearest_water_exit_target() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for area_node in get_tree().get_nodes_in_group("water_area"):
		var area := area_node as Area3D
		if not area:
			continue
		var target_info: Dictionary = _water_exit_target(area, npc.global_position)
		if target_info.is_empty():
			continue
		var pos: Vector3 = target_info.position
		var flat_distance := Vector2(pos.x, pos.z).distance_to(Vector2(npc.global_position.x, npc.global_position.z))
		if flat_distance < best_distance:
			best_distance = flat_distance
			best = target_info
	return best

func _water_exit_target(area: Area3D, point: Vector3) -> Dictionary:
	var shape_node: CollisionShape3D = _water_box_shape_node(area)
	if not shape_node:
		return {}
	var box := shape_node.shape as BoxShape3D
	if not box:
		return {}
	var local: Vector3 = shape_node.global_transform.affine_inverse() * point
	var half: Vector3 = box.size * 0.5
	if abs(local.x) > half.x or abs(local.z) > half.z:
		return {}
	var exit_local := local
	var x_gap: float = half.x - abs(local.x)
	var z_gap: float = half.z - abs(local.z)
	if x_gap < z_gap:
		exit_local.x = (half.x + WATER_EXIT_MARGIN) * (1.0 if local.x >= 0.0 else -1.0)
	else:
		exit_local.z = (half.z + WATER_EXIT_MARGIN) * (1.0 if local.z >= 0.0 else -1.0)
	var exit_position: Vector3 = shape_node.global_transform * exit_local
	exit_position.y = float(area.get_meta("surface_y", water_surface_y))
	return {"position": exit_position}

func _is_point_in_any_water_xz(point: Vector3) -> bool:
	for area_node in get_tree().get_nodes_in_group("water_area"):
		var area := area_node as Area3D
		if area and _is_point_in_water_xz(area, point):
			return true
	return false

func _is_point_submerged_in_any_water(point: Vector3) -> bool:
	for area_node in get_tree().get_nodes_in_group("water_area"):
		var area := area_node as Area3D
		if area and _is_point_in_water_xz(area, point):
			var surface_y: float = float(area.get_meta("surface_y", water_surface_y))
			if point.y < surface_y - 0.05:
				return true
	return false

func _is_point_in_water_xz(area: Area3D, point: Vector3) -> bool:
	var shape_node: CollisionShape3D = _water_box_shape_node(area)
	if not shape_node:
		return false
	var box := shape_node.shape as BoxShape3D
	if not box:
		return false
	var local: Vector3 = shape_node.global_transform.affine_inverse() * point
	var half: Vector3 = box.size * 0.5
	return abs(local.x) <= half.x and abs(local.z) <= half.z

func _water_box_shape_node(area: Area3D) -> CollisionShape3D:
	for child in area.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node and shape_node.shape is BoxShape3D:
			return shape_node
	return null

func _update_body(delta: float, desired: Vector3) -> void:
	flinch_timer = max(0.0, flinch_timer - delta)
	wave_timer = max(0.0, wave_timer - delta)
	var moving: bool = desired.length() > 0.05
	if moving:
		var yaw: float = atan2(-desired.x, -desired.z)
		npc.rotation.y = lerp_angle(npc.rotation.y, yaw, min(1.0, delta * 5.0))
		bob_time += delta * TAU * (2.6 if current_emotion == "happy" else 2.0)
		var bob: float = sin(bob_time) * (0.05 if current_emotion == "happy" else 0.025)
		visual_root.position.y = lerp(visual_root.position.y, bob, min(1.0, delta * 10.0))
		left_arm.rotation.x = sin(bob_time) * 0.45
		right_arm.rotation.x = -sin(bob_time) * 0.45
	else:
		_idle_motion(delta)
	if current_action == "sit":
		visual_root.position.y = lerp(visual_root.position.y, -0.35, min(1.0, delta * 5.0))
	elif current_action == "relax":
		visual_root.position.y = lerp(visual_root.position.y, -0.55, min(1.0, delta * 5.0))
		left_arm.rotation.x = lerp(left_arm.rotation.x, 0.55, min(1.0, delta * 5.0))
		right_arm.rotation.x = lerp(right_arm.rotation.x, 0.55, min(1.0, delta * 5.0))
	if flinch_timer > 0.0:
		visual_root.rotation.x = lerp(visual_root.rotation.x, deg_to_rad(-8.0), min(1.0, delta * 12.0))
	else:
		visual_root.rotation.x = lerp(visual_root.rotation.x, 0.0, min(1.0, delta * 6.0))
	if wave_timer > 0.0:
		right_arm.rotation.z = sin(Time.get_ticks_msec() * 0.012) * 0.8 - 1.2
	else:
		right_arm.rotation.z = lerp(right_arm.rotation.z, 0.0, min(1.0, delta * 4.0))

func _update_look_at_player(delta: float) -> void:
	if not head_node:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	var direct_look := look_at_player_timer > 0.0
	if direct_look:
		look_at_player_timer = max(0.0, look_at_player_timer - delta)
	elif not _should_passively_look_at_player(player):
		return
	var target: Vector3 = player.global_position + Vector3.UP * 1.35
	var flat_target := target - npc.global_position
	flat_target.y = 0.0
	if _can_turn_body_to_player() and flat_target.length() > 0.05:
		var body_yaw := atan2(-flat_target.x, -flat_target.z)
		var body_speed := 4.5 if direct_look else 2.4
		npc.rotation.y = lerp_angle(npc.rotation.y, body_yaw, min(1.0, delta * body_speed))
	var direction: Vector3 = target - head_node.global_position
	if direction.length() < 0.05:
		return
	var local_direction: Vector3 = npc.global_transform.basis.inverse() * direction.normalized()
	var yaw: float = clamp(atan2(-local_direction.x, -local_direction.z), -PASSIVE_LOOK_YAW_LIMIT, PASSIVE_LOOK_YAW_LIMIT)
	var pitch: float = clamp(asin(local_direction.y), -PASSIVE_LOOK_PITCH_LIMIT, PASSIVE_LOOK_PITCH_LIMIT)
	var look_speed := 9.0 if direct_look else 5.2
	head_node.rotation.y = lerp_angle(head_node.rotation.y, yaw, min(1.0, delta * look_speed))
	head_node.rotation.x = lerp_angle(head_node.rotation.x, -pitch, min(1.0, delta * look_speed))

func _should_passively_look_at_player(player: Node3D) -> bool:
	if flee_active or current_action == "run_away":
		return false
	var flat := player.global_position - npc.global_position
	flat.y = 0.0
	return flat.length() <= PASSIVE_LOOK_DISTANCE

func _can_turn_body_to_player() -> bool:
	if flee_active or route_active or collect_active:
		return false
	if current_action.begins_with("walk_to_known_place_") or current_action.begins_with("walk_to_construction_"):
		return false
	var flat_velocity := Vector3(npc.velocity.x, 0.0, npc.velocity.z)
	return flat_velocity.length() < 0.35

func _idle_motion(delta: float) -> void:
	idle_timer -= delta
	visual_root.position.y = lerp(visual_root.position.y, 0.0, min(1.0, delta * 7.0))
	left_arm.rotation.x = lerp(left_arm.rotation.x, 0.0, min(1.0, delta * 4.0))
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if look_at_player_timer > 0.0 or (player and _should_passively_look_at_player(player)):
		return
	if idle_timer <= 0.0:
		idle_timer = randf_range(3.0, 8.0)
		if head_node:
			var target_y: float = randf_range(-0.45, 0.45)
			create_tween().tween_property(head_node, "rotation:y", target_y, 0.45)
	if current_emotion == "curious" and head_node:
		head_node.rotation.z = lerp(head_node.rotation.z, deg_to_rad(7.0), min(1.0, delta * 3.0))
	elif head_node:
		head_node.rotation.z = lerp(head_node.rotation.z, 0.0, min(1.0, delta * 3.0))
	if head_node and look_at_player_timer <= 0.0:
		head_node.rotation.x = lerp_angle(head_node.rotation.x, 0.0, min(1.0, delta * 4.0))
