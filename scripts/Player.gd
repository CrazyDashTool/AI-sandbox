extends CharacterBody3D
const PLAYER_HUD := preload("res://scripts/PlayerHUD.gd")
const PLAYER_AUDIO := preload("res://scripts/PlayerAudio.gd")
const PLAYER_TOOLS := preload("res://scripts/PlayerToolActions.gd")
const PLAYER_SWIMMING := preload("res://scripts/PlayerSwimming.gd")
const UNDERWATER_EFFECT := preload("res://scripts/UnderwaterEffect.gd")
const UNDERWATER_AUDIO := preload("res://scripts/UnderwaterAudio.gd")
const PLAYER_VISUAL_LAYER := 1 << 1
const STEP_HEIGHT := 0.38
const STEP_DOWN_EXTRA := 0.12
@export var mouse_sensitivity := 0.0022
@export var walk_speed := 5.2
@export var sprint_speed := 8.2
@export var acceleration := 12.0
@export var deceleration := 15.0
@export var jump_velocity := 5.2
@export var coyote_time := 0.1
@export var throw_force := 16.0
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
var npc_view_camera: Camera3D
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var pitch := 0.0
var coyote_timer := 0.0
var bob_time := 0.0
var idle_time := 0.0
var landing_offset := 0.0
var base_camera_y := 0.0
var base_head_y := 0.0
var was_sprinting := false
var held_object: RigidBody3D
var hover_object: Node
var step_clock := 0.0
var hud_ui: CanvasLayer
var audio: PlayerAudio
var water
var underwater_effect: CanvasLayer
var underwater_audio: UnderwaterAudio
var rest_timer := 0.0
var rest_camera_offset := 0.0
var rest_target_offset := 0.0
var rest_active := false
var rest_start_position := Vector3.ZERO
var rest_target_position := Vector3.ZERO
var rest_blend := 0.0
var npc_camera_view := false
var player_capsule: CapsuleShape3D
var crouching := false
var crouch_camera_offset := 0.0
var standing_capsule_height := 1.75
var crouch_capsule_height := 1.05
var fly_mode := false
var noclip_mode := false
var fly_speed := 10.0
var fly_sprint_speed := 22.0
var normal_collision_layer := 1
var normal_collision_mask := 1
func _ready() -> void:
	add_to_group("player")
	normal_collision_layer = collision_layer
	normal_collision_mask = collision_mask
	base_camera_y = camera.position.y
	base_head_y = head.position.y
	floor_snap_length = max(floor_snap_length, STEP_HEIGHT + 0.08)
	_setup_collision_shape()
	camera.cull_mask &= ~PLAYER_VISUAL_LAYER
	_make_npc_view_camera()
	water = PLAYER_SWIMMING.new()
	underwater_effect = UNDERWATER_EFFECT.new()
	add_child(underwater_effect)
	underwater_audio = UNDERWATER_AUDIO.new()
	add_child(underwater_audio)
	hud_ui = PLAYER_HUD.new()
	add_child(hud_ui)
	audio = PLAYER_AUDIO.new()
	add_child(audio)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_npc_camera") and not GameState.menu_open and not GameState.chat_open and not GameState.api_dialog_open and not GameState.pause_open and not GameState.console_open:
		_toggle_npc_camera_view()
		return
	if event is InputEventMouseMotion and GameState.allows_mouse_look() and not npc_camera_view:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-86), deg_to_rad(86))
		head.rotation.x = pitch
	if event.is_action_pressed("chat") and not GameState.menu_open and not GameState.chat_open and not GameState.api_dialog_open and not GameState.console_open:
		hud_ui.open_chat()
	if not GameState.allows_mouse_look():
		return
	if npc_camera_view:
		return
	if event.is_action_pressed("use_object"):
		_use_object()
		return
	if event.is_action_pressed("interact"):
		_toggle_hold()
	held_object = PLAYER_TOOLS.handle_object_input(event, camera, self, held_object, hover_object)
	if event.is_action_pressed("primary_fire"):
		_primary_action()
	if event.is_action_pressed("secondary_fire"):
		_throw_held()
func _physics_process(delta: float) -> void:
	_update_npc_camera_view()
	if global_position.y < -20.0:
		_respawn()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if GameState.allows_mouse_look() and not npc_camera_view else Vector2.ZERO
	var resting := _update_rest_state(delta, input)
	if fly_mode:
		_update_fly(delta, input)
		return
	if resting and not water.active:
		_set_crouching(false)
		_update_crouch_shape(delta)
		_update_camera(delta, Vector2.ZERO, false)
		_update_underwater_effect()
		_update_held(delta)
		_update_hover()
		_update_hud()
		return
	if water.active:
		var water_jump := Input.is_action_just_pressed("jump") and GameState.allows_mouse_look()
		var dive_down := Input.is_action_pressed("crouch") and GameState.allows_mouse_look()
		_set_crouching(false)
		_update_crouch_shape(delta)
		water.apply(self, delta, input, camera, Input.is_action_pressed("sprint"), dive_down)
		if water_jump:
			audio.play_jump()
			WorldContext.log_player_action("jumped_out_of_water")
		move_and_slide()
		_update_camera(delta, input, false)
		_update_underwater_effect()
		_update_held(delta)
		_update_hover()
		_update_hud()
		return
	var floor_before := is_on_floor()
	if floor_before:
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
		velocity.y -= gravity * delta
	var sprinting := Input.is_action_pressed("sprint") and input.y < 0.0 and floor_before
	if sprinting and not was_sprinting:
		WorldContext.log_player_action("sprinted")
	was_sprinting = sprinting
	if Input.is_action_just_pressed("jump") and coyote_timer > 0.0 and GameState.allows_mouse_look():
		velocity.y = jump_velocity
		coyote_timer = 0.0
		audio.play_jump()
		WorldContext.log_player_action("jumped")
	_update_crouch(delta)
	var wish_dir := (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var target_speed := sprint_speed if sprinting else walk_speed
	if crouching:
		target_speed *= 0.55
	var target_velocity := wish_dir * target_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if target_velocity.length() > horizontal.length() else deceleration
	horizontal = horizontal.lerp(target_velocity, min(1.0, rate * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var pre_move_transform := global_transform
	var step_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	move_and_slide()
	if _try_step_up(pre_move_transform, step_motion, floor_before):
		velocity.y = 0.0
	if not floor_before and is_on_floor():
		_landing_impact()
		audio.play_land()
		WorldContext.log_player_action("landed")
	_update_camera(delta, input, sprinting)
	_update_underwater_effect()
	_update_held(delta)
	_update_hover()
	_update_hud()
	_update_footsteps(delta, input, sprinting)
func _update_camera(delta: float, input: Vector2, sprinting: bool) -> void:
	if npc_camera_view:
		return
	var moving := input.length() > 0.05 and is_on_floor()
	var y_offset := 0.0
	if moving:
		var freq := 3.0 if sprinting else 2.0
		var amp := 0.06 if sprinting else 0.03
		bob_time += delta * TAU * freq
		y_offset = sin(bob_time) * amp
	else:
		idle_time += delta * TAU * 0.3
		y_offset = sin(idle_time) * 0.005
	var head_pos := head.position
	head_pos.y = lerp(head_pos.y, base_head_y + rest_camera_offset + crouch_camera_offset, min(1.0, delta * 10.0))
	head.position = head_pos
	var pos := camera.position
	pos.y = lerp(pos.y, base_camera_y + y_offset + landing_offset, min(1.0, delta * 14.0))
	camera.position = pos
	camera.rotation.z = lerp_angle(camera.rotation.z, -input.x * deg_to_rad(2.0), min(1.0, delta * 9.0))
	camera.fov = lerp(camera.fov, 85.0 if sprinting else 75.0, min(1.0, delta * 6.0))

func _update_underwater_effect() -> void:
	if underwater_effect:
		underwater_effect.update_from_water(camera, water)
	if underwater_audio:
		underwater_audio.update_from_water(camera, water)

func _make_npc_view_camera() -> void:
	npc_view_camera = Camera3D.new()
	npc_view_camera.name = "NPCViewCamera"
	npc_view_camera.current = false
	npc_view_camera.fov = 75.0
	npc_view_camera.near = 0.05
	npc_view_camera.far = 120.0
	npc_view_camera.cull_mask |= PLAYER_VISUAL_LAYER
	add_child(npc_view_camera)

func _toggle_npc_camera_view() -> void:
	npc_camera_view = not npc_camera_view
	if npc_camera_view and not _update_npc_camera_view():
		npc_camera_view = false
	camera.current = not npc_camera_view
	if npc_view_camera:
		npc_view_camera.current = npc_camera_view
	if hud_ui and hud_ui.has_method("set_npc_camera_view"):
		hud_ui.set_npc_camera_view(npc_camera_view)

func _update_npc_camera_view() -> bool:
	if not npc_camera_view or not npc_view_camera:
		return false
	var npc := get_tree().get_first_node_in_group("npc")
	if not npc or not npc.has_method("get_brain_camera_transform"):
		npc_camera_view = false
		camera.current = true
		npc_view_camera.current = false
		if hud_ui and hud_ui.has_method("set_npc_camera_view"):
			hud_ui.set_npc_camera_view(false)
		return false
	npc_view_camera.global_transform = npc.get_brain_camera_transform()
	return true
func _landing_impact() -> void:
	var tween := create_tween()
	tween.tween_property(self, "landing_offset", -0.075, 0.05)
	tween.tween_property(self, "landing_offset", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _try_step_up(from_transform: Transform3D, horizontal_motion: Vector3, was_on_floor: bool) -> bool:
	if not was_on_floor or crouching or horizontal_motion.length() < 0.001:
		return false
	if not test_move(from_transform, horizontal_motion):
		return false
	var up := Vector3.UP * STEP_HEIGHT
	if test_move(from_transform, up):
		return false
	var raised_transform := from_transform.translated(up)
	if test_move(raised_transform, horizontal_motion):
		return false
	var forward_transform := raised_transform.translated(horizontal_motion)
	var collision := KinematicCollision3D.new()
	if not test_move(forward_transform, Vector3.DOWN * (STEP_HEIGHT + STEP_DOWN_EXTRA), collision):
		return false
	if collision.get_normal().y < cos(floor_max_angle):
		return false
	var final_transform := forward_transform.translated(collision.get_travel())
	var step_delta := final_transform.origin.y - from_transform.origin.y
	if step_delta < 0.025 or step_delta > STEP_HEIGHT + 0.02:
		return false
	global_transform = final_transform
	return true

func _setup_collision_shape() -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		player_capsule = (collision_shape.shape as CapsuleShape3D).duplicate()
		collision_shape.shape = player_capsule
		standing_capsule_height = player_capsule.height

func _update_crouch(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("crouch") and GameState.allows_mouse_look() and not npc_camera_view
	if wants_crouch:
		_set_crouching(true)
	elif crouching and _can_stand_up():
		_set_crouching(false)
	_update_crouch_shape(delta)

func _update_crouch_shape(delta: float) -> void:
	var target_height := crouch_capsule_height if crouching else standing_capsule_height
	if player_capsule:
		player_capsule.height = lerp(player_capsule.height, target_height, min(1.0, delta * 12.0))
	if collision_shape:
		collision_shape.position.y = lerp(collision_shape.position.y, target_height * 0.5, min(1.0, delta * 12.0))
	var target_camera := -0.52 if crouching else 0.0
	crouch_camera_offset = lerp(crouch_camera_offset, target_camera, min(1.0, delta * 10.0))

func _set_crouching(value: bool) -> void:
	crouching = value

func _can_stand_up() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * crouch_capsule_height
	var to := global_position + Vector3.UP * (standing_capsule_height + 0.18)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	if held_object:
		query.exclude.append(held_object.get_rid())
	return space.intersect_ray(query).is_empty()

func set_fly_mode(enabled: bool, noclip := false) -> void:
	fly_mode = enabled
	noclip_mode = enabled and noclip
	velocity = Vector3.ZERO
	_set_crouching(false)
	if water and water.active:
		water.exit()
		WorldContext.set_water_state("player", false)
	_update_crouch_shape(1.0)
	if enabled and noclip_mode:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = normal_collision_layer
		collision_mask = normal_collision_mask
	WorldContext.log_player_action("noclip_enabled" if noclip_mode else ("fly_enabled" if enabled else "fly_disabled"))

func set_fly_speed(value: float) -> void:
	fly_speed = clamp(value, 1.0, 80.0)
	fly_sprint_speed = max(fly_speed * 1.8, fly_speed + 4.0)

func _update_fly(delta: float, input: Vector2) -> void:
	var direction := camera.global_transform.basis.x * input.x + camera.global_transform.basis.z * input.y
	if Input.is_action_pressed("jump") and GameState.allows_mouse_look():
		direction += Vector3.UP
	if Input.is_action_pressed("crouch") and GameState.allows_mouse_look():
		direction -= Vector3.UP
	if direction.length() > 0.05:
		direction = direction.normalized()
	var speed := fly_sprint_speed if Input.is_action_pressed("sprint") else fly_speed
	velocity = direction * speed
	if noclip_mode:
		global_position += velocity * delta
	else:
		move_and_slide()
	_update_camera(delta, input, false)
	_update_underwater_effect()
	_update_held(delta)
	_update_hover()
	_update_hud()

func _toggle_hold() -> void:
	if held_object:
		_drop_held(true)
		return
	var result := _raycast(4.5)
	if result and result.collider.is_in_group("grabbable"):
		held_object = result.collider
		held_object.set_held(true)
		WorldContext.log_player_action("picked_up_object", {"object": _held_name()})
func _primary_action() -> void:
	if GameState.selected_spawn_item.has("type"):
		if str(GameState.selected_spawn_item.get("category", "")) == "Tools":
			PLAYER_TOOLS.use_selected_tool(str(GameState.selected_spawn_item.type), camera, self)
			return
		_spawn_selected()
	elif held_object:
		if not held_object.has_method("use_held") or not held_object.use_held(camera, self):
			held_object.apply_central_impulse(-camera.global_transform.basis.z * 2.0)
func _throw_held() -> void:
	if not held_object:
		return
	var object := held_object
	var name := _held_name()
	_drop_held(false)
	object.apply_central_impulse(-camera.global_transform.basis.z * throw_force)
	WorldContext.log_player_action("threw_object", {"object": name})
func _drop_held(place: bool) -> void:
	if not held_object:
		return
	var name := _held_name()
	held_object.set_held(false)
	if place:
		WorldContext.log_player_action("placed_object", {"object": name})
	held_object = null
func _spawn_selected() -> void:
	var spawner := get_tree().get_first_node_in_group("object_spawner")
	if not spawner:
		return
	var normal := Vector3.UP
	var pos := camera.global_position - camera.global_transform.basis.z * 4.0
	var hit := _raycast(12.0)
	if hit:
		pos = hit.position
		normal = hit.normal
	var type_name := str(GameState.selected_spawn_item.type)
	spawner.spawn_prop(type_name, pos, normal, "player")
	WorldContext.log_player_action("spawned_object", {"object": type_name})
	var npc := get_tree().get_first_node_in_group("npc")
	if npc and pos.distance_to(npc.global_position) < 3.0:
		WorldContext.log_player_action("built_near_npc", {"object": type_name})
func _update_held(delta: float) -> void:
	if not held_object or not is_instance_valid(held_object):
		held_object = null
		return
	var target := camera.global_position - camera.global_transform.basis.z * 2.7
	held_object.linear_velocity = (target - held_object.global_position) * 12.0
	held_object.angular_velocity = held_object.angular_velocity.lerp(Vector3.ZERO, min(1.0, delta * 8.0))
	if held_object.global_position.distance_to(global_position) > 8.0:
		_drop_held(false)
func _update_hover() -> void:
	var result := _raycast(4.5)
	var next_hover: Node = null
	if result and result.collider.is_in_group("grabbable"):
		next_hover = result.collider
	if hover_object != next_hover:
		if hover_object and hover_object.has_method("set_highlighted"):
			hover_object.set_highlighted(false)
		hover_object = next_hover
		if hover_object and hover_object.has_method("set_highlighted"):
			hover_object.set_highlighted(true)

func _try_use_hovered_prop() -> bool:
	var target := hover_object
	if not target:
		var result := _raycast(4.5)
		if result:
			target = result.collider
	return _try_interact_with(target)

func _try_interact_with(target: Node) -> bool:
	var current := target
	while current:
		if current.has_method("can_interact") and not current.can_interact():
			return false
		if current.has_method("interact_with"):
			return current.interact_with(self)
		if current.has_method("use_scene_prop"):
			return current.use_scene_prop(self)
		current = current.get_parent()
	return false

func _use_object() -> void:
	if held_object and _try_interact_with(held_object):
		return
	_try_use_hovered_prop()

func _update_hud() -> void:
	hud_ui.update_status(_held_name() if held_object else "")
func _raycast(distance: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	if held_object:
		query.exclude.append(held_object.get_rid())
	return space.intersect_ray(query)
func _update_footsteps(delta: float, input: Vector2, sprinting: bool) -> void:
	if input.length() < 0.05 or not is_on_floor():
		step_clock = 0.0
		return
	step_clock += delta
	var interval := 0.28 if sprinting else 0.45
	if step_clock >= interval:
		step_clock = 0.0
		hud_ui.flash_step()
		audio.play_step(sprinting)
func _held_name() -> String: return held_object.get_display_name() if held_object and held_object.has_method("get_display_name") else "object"
func enter_water(surface_y: float, _speed: float) -> void: water.enter(surface_y)
func exit_water() -> void:
	water.exit()
	_update_underwater_effect()

func start_prop_interaction(kind: String, prop: Node3D) -> void:
	if not prop:
		return
	if held_object:
		_drop_held(true)
	velocity = Vector3.ZERO
	_set_crouching(false)
	rest_active = true
	rest_start_position = global_position
	rest_blend = 0.0
	var height := float(prop.get_meta("seat_height", 0.65))
	var forward := -prop.global_transform.basis.z.normalized()
	var side_offset := Vector3.ZERO
	if kind == "bench":
		height = float(prop.get_meta("seat_height", 0.85))
		rest_target_offset = -0.5
		rest_timer = 4.0
	elif kind == "chair" or kind == "seat":
		height = float(prop.get_meta("seat_height", 0.68))
		side_offset = forward * 0.18
		rest_target_offset = -0.5
		rest_timer = 4.0
	elif kind == "blanket":
		height = float(prop.get_meta("seat_height", 0.28))
		rest_target_offset = -0.95
		rest_timer = 5.0
	else:
		rest_target_offset = -0.5
		rest_timer = 3.0
	rest_target_position = prop.global_position + side_offset + Vector3.UP * height
	WorldContext.log_player_action("started_%s_interaction" % kind)

func _update_rest_state(delta: float, input: Vector2) -> bool:
	if rest_timer > 0.0 and (input.length() > 0.05 or Input.is_action_just_pressed("jump")):
		rest_timer = 0.0
		rest_active = false
	if rest_timer > 0.0:
		rest_timer = max(0.0, rest_timer - delta)
		rest_blend = min(1.0, rest_blend + delta * 2.35)
		global_position = rest_start_position.lerp(rest_target_position, smoothstep(0.0, 1.0, rest_blend))
		velocity = Vector3.ZERO
		if rest_timer <= 0.0:
			rest_active = false
	else:
		rest_active = false
	var target := rest_target_offset if rest_timer > 0.0 else 0.0
	rest_camera_offset = lerp(rest_camera_offset, target, min(1.0, delta * 5.5))
	return rest_timer > 0.0 or rest_active

func _respawn() -> void:
	if water:
		water.exit()
	rest_timer = 0.0
	rest_active = false
	rest_camera_offset = 0.0
	WorldContext.set_water_state("player", false)
	velocity = Vector3.ZERO
	global_position = Vector3(0, 1.2, 6)
	WorldContext.log_player_action("respawned_after_fall")
