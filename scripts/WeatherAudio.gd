extends Node

const MORNING := "res://Sounds/Forest_ambient.mp3"
const NIGHT := "res://Sounds/Night.mp3"
const RAIN := "res://Sounds/Rain.mp3"
const RAIN_HEAVY := "res://Sounds/RainHeavy.mp3"
const THUNDER := "res://Sounds/Thunder.mp3"

var morning_player: AudioStreamPlayer
var night_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var heavy_rain_player: AudioStreamPlayer
var thunder_player: AudioStreamPlayer
var thunder_timer := 18.0
var ready_for_audio := false
var lightning_target: Node

func setup() -> void:
	if DisplayServer.get_name() == "headless":
		return
	morning_player = _loop_player(MORNING, GameState.AMBIENT_BUS)
	night_player = _loop_player(NIGHT, GameState.AMBIENT_BUS)
	rain_player = _loop_player(RAIN, GameState.AMBIENT_BUS)
	heavy_rain_player = _loop_player(RAIN_HEAVY, GameState.AMBIENT_BUS)
	thunder_player = _one_shot_player(THUNDER, GameState.SFX_BUS)
	ready_for_audio = true

func set_lightning_target(target: Node) -> void:
	lightning_target = target

func update_audio(delta: float, _weather: String, rain_strength: float, cloudiness: float, daylight: float) -> void:
	if not ready_for_audio:
		return
	var rain_soft: float = smoothstep(0.02, 0.72, rain_strength)
	var rain_heavy: float = smoothstep(0.55, 1.0, rain_strength)
	var day_amount: float = clamp(daylight * (1.0 - rain_strength * 0.35), 0.0, 1.0)
	var night_amount: float = clamp((1.0 - daylight) * (1.0 - rain_strength * 0.25), 0.0, 1.0)
	var rain_occlusion := _rain_occlusion()
	_set_volume(morning_player, day_amount * 0.42)
	_set_volume(night_player, night_amount * 0.48)
	_set_volume(rain_player, rain_soft * (1.0 - rain_heavy * 0.45) * 0.55 * rain_occlusion)
	_set_volume(heavy_rain_player, rain_heavy * 0.62 * rain_occlusion)
	_update_thunder(delta, rain_strength, cloudiness)

func _rain_occlusion() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return 1.0
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	var point := camera.global_position if camera else player.global_position + Vector3.UP * 1.55
	var world := player.get_world_3d()
	if not world:
		return 1.0
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point + Vector3.UP * 80.0)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	return 0.32 if not world.direct_space_state.intersect_ray(query).is_empty() else 1.0

func _update_thunder(delta: float, rain_strength: float, cloudiness: float) -> void:
	if not thunder_player:
		return
	thunder_timer -= delta
	if rain_strength < 0.62 or cloudiness < 0.62:
		thunder_timer = max(thunder_timer, 10.0)
		return
	if thunder_timer <= 0.0:
		if lightning_target and lightning_target.has_method("trigger_lightning"):
			lightning_target.call("trigger_lightning", rain_strength)
		thunder_player.volume_db = linear_to_db(clamp(rain_strength * 0.8, 0.05, 1.0))
		thunder_player.pitch_scale = randf_range(0.92, 1.06)
		thunder_player.play()
		thunder_timer = randf_range(24.0, 52.0)

func _loop_player(path: String, bus_name: String) -> AudioStreamPlayer:
	var player := _base_player(path, bus_name)
	if player and player.stream:
		player.stream.loop = true
		player.play()
	return player

func _one_shot_player(path: String, bus_name: String) -> AudioStreamPlayer:
	return _base_player(path, bus_name)

func _base_player(path: String, bus_name: String) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = bus_name
	player.volume_db = -80.0
	add_child(player)
	return player

func _set_volume(player: AudioStreamPlayer, linear: float) -> void:
	if not player:
		return
	var target := -80.0 if linear <= 0.003 else linear_to_db(clamp(linear, 0.001, 1.0))
	player.volume_db = lerp(player.volume_db, target, 0.025)
