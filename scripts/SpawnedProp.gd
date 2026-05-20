extends RigidBody3D

class_name SpawnedProp

const WEAPON_SYSTEM := preload("res://scripts/WeaponSystem.gd")
const PROP_CATALOG := preload("res://scripts/PropCatalog.gd")

const METAL_SOUNDS := ["res://Sounds/MetalSound1.mp3", "res://Sounds/MetalSound2.mp3", "res://Sounds/MetalSound3.mp3", "res://Sounds/MetalSound4.mp3"]
const WOOD_SOUNDS := ["res://Sounds/WoodSound.mp3", "res://Sounds/WoodSound2.mp3"]
const BOARD_SOUNDS := ["res://Sounds/WoodenBoard.mp3", "res://Sounds/WoodenBoard2.mp3"]
const ROCK_SOUNDS := ["res://Sounds/Rock.mp3", "res://Sounds/Rock2.mp3"]
const CONCRETE_SOUNDS := ["res://Sounds/ConcreateSound1.mp3", "res://Sounds/ConcreateSound2.mp3"]
const MIRROR_SOUND := "res://Sounds/Mirror falled.mp3"
const BALLOON_SOUND := "res://Sounds/Ballon.mp3"

var prop_id := 0
var prop_type := ""
var base_gravity := 1.0
var impact_material := ""
var buoyant := false
var motorized := false
var piloted := false
var pilot_player: Node3D
var motor_force := 34.0
var turn_force := 6.0
var buoyancy_offset := 0.0
var update_clock := 0.0
var pinned := false
var held := false
var impact_cooldown := 0.0
var music_player: AudioStreamPlayer3D
var in_water := false
var water_surface_y := 0.0
var interaction_kind := ""

func setup(id: int, type_name: String) -> void:
	prop_id = id
	prop_type = type_name
	base_gravity = gravity_scale
	impact_material = str(get_meta("impact", ""))
	buoyant = bool(get_meta("buoyant", false))
	motorized = bool(get_meta("motorized", false))
	motor_force = float(get_meta("motor_force", motor_force))
	turn_force = float(get_meta("turn_force", turn_force))
	buoyancy_offset = float(get_meta("buoyancy_offset", 0.0))
	interaction_kind = str(get_meta("interaction", ""))
	add_to_group("grabbable")
	add_to_group("ai_obstacle")
	if interaction_kind != "" or prop_type.begins_with("Boombox"):
		add_to_group("interactive_prop")
	if buoyant:
		add_to_group("floatable")
	if motorized:
		add_to_group("drivable")
	if prop_type.begins_with("Boombox"):
		_setup_boombox()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	impact_cooldown = max(0.0, impact_cooldown - delta)
	if _is_balloon() and not held and not pinned:
		gravity_scale = 0.0
		linear_damp = 0.65
		linear_velocity.y = lerp(linear_velocity.y, 1.65, min(1.0, delta * 1.3))
		linear_velocity.x += sin(Time.get_ticks_msec() * 0.0017 + prop_id) * delta * 0.18
		linear_velocity.z += cos(Time.get_ticks_msec() * 0.0013 + prop_id) * delta * 0.18
	if piloted and motorized and not pinned:
		_apply_pilot_control(delta)
	if in_water and not pinned:
		if buoyant:
			var target_y := water_surface_y + buoyancy_offset
			linear_damp = max(linear_damp, 1.35)
			angular_damp = max(angular_damp, 1.2)
			linear_velocity.y += clamp((target_y - global_position.y) * 0.65, -2.0, 4.5) * delta * 5.0
		elif global_position.y < water_surface_y - 0.12:
			linear_velocity.y += min(3.5, (water_surface_y - global_position.y) * 0.12)
	update_clock += delta
	if update_clock >= 1.0:
		update_clock = 0.0
		if prop_id > 0:
			WorldContext.update_object_position(prop_id, global_position)

func set_highlighted(value: bool) -> void:
	var outline := get_node_or_null("Outline")
	if outline:
		outline.visible = value

func set_held(value: bool) -> void:
	held = value
	if value:
		sleeping = false
		piloted = false
		freeze = false
		gravity_scale = 0.0
		linear_damp = 8.0
		angular_damp = 8.0
	else:
		gravity_scale = _resting_gravity()
		linear_damp = 2.2 if in_water else 0.0
		angular_damp = 2.2 if in_water else 0.0
		freeze = pinned

func toggle_pinned() -> bool:
	set_pinned(not pinned)
	return pinned

func set_pinned(value: bool) -> void:
	pinned = value
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = pinned
	gravity_scale = _resting_gravity()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func is_pinned() -> bool:
	return pinned

func enter_water(surface_y: float, _speed: float) -> void:
	in_water = true
	water_surface_y = surface_y
	if not pinned:
		gravity_scale = _resting_gravity()
		linear_damp = 2.2
		angular_damp = 2.2

func exit_water() -> void:
	in_water = false
	if not pinned:
		gravity_scale = base_gravity
		linear_damp = 0.0
		angular_damp = 0.0

func rotate_held(axis: Vector3, radians: float) -> void:
	var basis := global_transform.basis.rotated(axis.normalized(), radians).orthonormalized()
	global_transform = Transform3D(basis, global_position)

func get_display_name() -> String:
	return PROP_CATALOG.display_name(prop_type)

func get_interaction_kind() -> String:
	return interaction_kind

func set_buoyant(value: bool) -> void:
	buoyant = value
	if buoyant:
		add_to_group("floatable")
	else:
		remove_from_group("floatable")
	gravity_scale = _resting_gravity()

func is_buoyant() -> bool:
	return buoyant

func set_motorized(value: bool) -> void:
	motorized = value
	if motorized:
		add_to_group("drivable")
	else:
		remove_from_group("drivable")
		piloted = false

func is_motorized() -> bool:
	return motorized

func set_drive_power(force: float, turn: float) -> void:
	motor_force = max(motor_force, force)
	turn_force = max(turn_force, turn)

func get_motor_force() -> float:
	return motor_force

func get_turn_force() -> float:
	return turn_force

func set_piloted(player: Node3D) -> bool:
	if piloted and pilot_player == player:
		piloted = false
		pilot_player = null
		return false
	if not motorized:
		set_motorized(true)
	piloted = true
	pilot_player = player
	held = false
	freeze = false
	sleeping = false
	return true

func use_held(camera: Camera3D, user: Node3D) -> bool:
	if not WEAPON_SYSTEM.is_weapon(prop_type):
		return false
	WEAPON_SYSTEM.use_weapon(prop_type, camera, user, self)
	return true

func can_interact() -> bool:
	return prop_type.begins_with("Boombox") or interaction_kind != ""

func interact_with(user: Node3D) -> bool:
	if prop_type.begins_with("Boombox"):
		_toggle_boombox()
		return true
	return use_scene_prop(user)

func use_scene_prop(user: Node3D) -> bool:
	if interaction_kind == "":
		return false
	sleeping = true
	if user and user.has_method("start_prop_interaction"):
		user.start_prop_interaction(interaction_kind, self)
	var actor := "npc" if user and user.is_in_group("npc") else "player"
	WorldContext.log_player_action("%s_used_%s" % [actor, interaction_kind], {"object": prop_type})
	return true

func _on_body_entered(body: Node) -> void:
	if linear_velocity.length() > 2.2 and impact_cooldown <= 0.0:
		impact_cooldown = 0.25
		_play_impact_sound()
	if body.is_in_group("npc") and linear_velocity.length() > 4.0:
		WorldContext.log_player_action("hit_npc_with_object", {"object": prop_type})
		if body.has_method("react_to_hit"):
			body.react_to_hit(prop_type)

func _setup_boombox() -> void:
	music_player = AudioStreamPlayer3D.new()
	music_player.bus = GameState.MUSIC_BUS
	music_player.unit_size = 7.0
	music_player.volume_db = -4.0
	var style := prop_type.get_slice(" ", 1)
	var stream := load("res://Sounds/%s.mp3" % style)
	if stream:
		stream.loop = true
		music_player.stream = stream
	add_child(music_player)

func _toggle_boombox() -> void:
	if not music_player or not music_player.stream:
		return
	var enabled := not music_player.playing
	if enabled:
		music_player.play()
	else:
		music_player.stop()
	var style := prop_type.get_slice(" ", 1)
	var display_style := PROP_CATALOG.display_name(prop_type).get_slice(" ", 1)
	WorldContext.set_music(style, enabled)
	var brain := get_tree().get_first_node_in_group("npc_brain")
	if brain and brain.has_method("request_think_now"):
		brain.request_think_now("Music %s is now %s." % [display_style, "playing" if enabled else "stopped"])

func _play_impact_sound() -> void:
	var path := _impact_sound_path()
	if path == "":
		return
	var stream := load(path)
	if not stream:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = GameState.SFX_BUS
	player.global_position = global_position
	player.volume_db = -7.0
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _apply_pilot_control(_delta: float) -> void:
	if not pilot_player or not is_instance_valid(pilot_player) or not GameState.allows_mouse_look():
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var throttle := -input.y
	if abs(throttle) < 0.03 and abs(input.x) < 0.03:
		return
	var forward := -global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()
	var water_boost := 0.75 if in_water else 1.0
	apply_central_force((forward * throttle + right * input.x * 0.18) * motor_force * mass * water_boost)
	apply_torque(Vector3.UP * -input.x * turn_force * mass)

func _is_wood() -> bool:
	return ["Chair", "Table", "Crate", "Bench", "Tree", "Wheel", "Bush"].has(prop_type)

func _is_metal() -> bool:
	return ["Metal pipe", "Barrel"].has(prop_type)

func _is_board() -> bool:
	return ["Board", "Beach Blanket"].has(prop_type)

func _is_rock() -> bool:
	return prop_type == "Rock"

func _is_concrete() -> bool:
	return prop_type == "Wall"

func _is_balloon() -> bool:
	return prop_type == "Balloon" or prop_type == "Ballon"

func _impact_sound_path() -> String:
	match impact_material:
		"metal":
			return METAL_SOUNDS.pick_random()
		"wood":
			return WOOD_SOUNDS.pick_random()
		"board":
			return BOARD_SOUNDS.pick_random()
		"rock":
			return ROCK_SOUNDS.pick_random()
		"concrete":
			return CONCRETE_SOUNDS.pick_random()
		"mirror":
			return MIRROR_SOUND
		"balloon":
			return BALLOON_SOUND
	if prop_type == "Mirror":
		return MIRROR_SOUND
	if _is_balloon():
		return BALLOON_SOUND
	if _is_metal():
		return METAL_SOUNDS.pick_random()
	if _is_wood():
		return WOOD_SOUNDS.pick_random()
	if _is_board():
		return BOARD_SOUNDS.pick_random()
	if _is_rock():
		return ROCK_SOUNDS.pick_random()
	if _is_concrete():
		return CONCRETE_SOUNDS.pick_random()
	return ""

func _resting_gravity() -> float:
	if pinned:
		return 0.0
	if _is_balloon():
		return 0.0
	if buoyant and in_water:
		return base_gravity * 0.08
	return base_gravity * 0.18 if in_water else base_gravity
