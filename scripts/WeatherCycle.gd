extends Node3D

const WEATHER_VISUALS := preload("res://scripts/WeatherVisuals.gd")
const WEATHER_AUDIO := preload("res://scripts/WeatherAudio.gd")
const START_CLEAR_SECONDS := 90.0
const WEATHER_TRANSITION_SECONDS := 120.0
@export var day_length_seconds := 720.0
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var visuals: Node3D
var audio: Node
var night_lights: Array[Light3D] = []
var night_light_energy: Dictionary = {}
var night_fire_meshes: Array[MeshInstance3D] = []
var night_fire_emission: Dictionary = {}
var time_of_day := 11.3
var weather := "clear"
var target_weather := "clear"
var transition_from_weather := "clear"
var transition_progress := 1.0
var startup_clear_timer := START_CLEAR_SECONDS
var weather_timer := 180.0
var cloudiness := 0.08
var rain_strength := 0.0
var fog_strength := 0.0
var dimness := 0.0
var context_clock := 0.0
var first_weather_change_done := false
var time_scale := 2.0
var time_locked := false
var weather_locked := false
func _ready() -> void:
	add_to_group("weather_cycle")
	randomize()
	world_env = _find_first(WorldEnvironment) as WorldEnvironment
	sun = _find_first(DirectionalLight3D) as DirectionalLight3D
	if not world_env:
		world_env = WorldEnvironment.new()
		world_env.environment = Environment.new()
		add_child(world_env)
	if not world_env.environment:
		world_env.environment = Environment.new()
	if not sun:
		sun = DirectionalLight3D.new()
		sun.name = "Sun"
		get_parent().add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.shadow_enabled = false
	get_parent().add_child(moon)
	_collect_night_lights()
	_grab_sky_material()
	visuals = WEATHER_VISUALS.new()
	visuals.name = "WeatherVisuals"
	add_child(visuals)
	visuals.call("setup")
	audio = WEATHER_AUDIO.new()
	audio.name = "WeatherAudio"
	add_child(audio)
	audio.call("setup")
	audio.call("set_lightning_target", visuals)
	weather = "clear"
	target_weather = "clear"
	transition_from_weather = "clear"
	transition_progress = 1.0
	weather_timer = 0.0
	_apply_all(0.0)
func _process(delta: float) -> void:
	var world_delta := delta * time_scale
	if not time_locked:
		time_of_day = fposmod(time_of_day + world_delta * 24.0 / day_length_seconds, 24.0)
	startup_clear_timer = max(0.0, startup_clear_timer - world_delta)
	if startup_clear_timer <= 0.0 and not weather_locked:
		weather_timer -= world_delta
	if weather_timer <= 0.0 and transition_progress >= 1.0 and startup_clear_timer <= 0.0 and not weather_locked:
		_pick_next_weather()
	_smooth_weather(world_delta)
	_apply_all(delta)
	visuals.call("update_visuals", delta, rain_strength, cloudiness, _daylight_value())
	audio.call("update_audio", delta, weather, rain_strength, cloudiness, _daylight_value())
	context_clock += delta
	if context_clock >= 1.0:
		context_clock = 0.0
		if WorldContext and WorldContext.has_method("set_environment_state"):
			WorldContext.set_environment_state(weather, time_of_day, _phase_name())
func _pick_next_weather() -> void:
	var options: Array[String] = ["clear", "clear", "clear", "cloudy", "cloudy", "rain", "mist"]
	if not first_weather_change_done:
		options = ["cloudy", "rain", "mist"]
	var next_weather: String = options[randi() % options.size()]
	if next_weather == target_weather:
		weather_timer = randf_range(90.0, 150.0)
		return
	transition_from_weather = weather
	target_weather = next_weather
	transition_progress = 0.0
	first_weather_change_done = true
	weather_timer = randf_range(180.0, 300.0)

func set_weather(weather_name: String, immediate := false) -> bool:
	var clean := weather_name.to_lower().strip_edges()
	if not _preset_names().has(clean):
		return false
	time_locked = false
	startup_clear_timer = 0.0
	transition_from_weather = weather
	target_weather = clean
	transition_progress = 1.0 if immediate else 0.0
	first_weather_change_done = true
	weather_timer = randf_range(180.0, 300.0)
	if immediate:
		weather = clean
		_smooth_weather(0.0)
		_apply_all(0.0)
	return true

func trigger_lightning() -> void:
	if visuals and visuals.has_method("trigger_lightning"):
		visuals.call("trigger_lightning", max(0.65, rain_strength))

func set_time_of_day(hour: float) -> void:
	time_of_day = fposmod(hour, 24.0)
	_apply_all(0.0)

func get_time_of_day() -> float:
	return time_of_day

func get_weather_status() -> String:
	return "%s -> %s %.0f%%, weather %s, timescale %.2fx, time %s" % [weather, target_weather, transition_progress * 100.0, "locked" if weather_locked else "auto", time_scale, "locked" if time_locked else "running"]

func set_weather_locked(value: bool) -> void:
	weather_locked = value

func is_weather_locked() -> bool:
	return weather_locked

func set_time_locked(value: bool) -> void:
	time_locked = value

func is_time_locked() -> bool:
	return time_locked

func set_time_scale(value: float) -> void:
	time_scale = clamp(value, 0.0, 64.0)

func get_time_scale() -> float:
	return time_scale

func _preset_names() -> Array[String]:
	return ["clear", "cloudy", "mist", "rain"]
func _smooth_weather(delta: float) -> void:
	if startup_clear_timer > 0.0:
		transition_from_weather = "clear"
		target_weather = "clear"
		transition_progress = 1.0
	transition_progress = min(1.0, transition_progress + delta / WEATHER_TRANSITION_SECONDS)
	var from_preset: Dictionary = _preset(transition_from_weather)
	var to_preset: Dictionary = _preset(target_weather)
	var blend: float = smoothstep(0.0, 1.0, transition_progress)
	cloudiness = lerp(float(from_preset.clouds), float(to_preset.clouds), blend)
	rain_strength = lerp(float(from_preset.rain), float(to_preset.rain), blend)
	fog_strength = lerp(float(from_preset.fog), float(to_preset.fog), blend)
	dimness = lerp(float(from_preset.dim), float(to_preset.dim), blend)
	weather = target_weather if transition_progress >= 0.78 else transition_from_weather
func _preset(name: String) -> Dictionary:
	match name:
		"cloudy":
			return {"clouds": 0.52, "rain": 0.0, "fog": 0.0, "dim": 0.12}
		"mist":
			return {"clouds": 0.58, "rain": 0.0, "fog": 0.018, "dim": 0.08}
		"rain":
			return {"clouds": 0.86, "rain": 1.0, "fog": 0.014, "dim": 0.24}
	return {"clouds": 0.12, "rain": 0.0, "fog": 0.0, "dim": 0.0}
func _apply_all(_delta: float) -> void:
	var phase: float = (time_of_day - 6.0) / 24.0 * TAU
	var sun_height: float = sin(phase)
	var daylight: float = smoothstep(-0.12, 0.34, sun_height)
	var sunset: float = max(0.0, 1.0 - abs(time_of_day - 6.4) / 1.7) + max(0.0, 1.0 - abs(time_of_day - 18.6) / 1.7)
	sunset = clamp(sunset, 0.0, 1.0)
	var light_scale: float = clamp(1.0 - dimness - rain_strength * 0.18, 0.28, 1.0)
	_update_lights(phase, daylight, sunset, light_scale)
	_update_night_lights(daylight, light_scale)
	_update_environment(daylight, sunset, light_scale)
	_update_sky(daylight, sunset)

func _collect_night_lights() -> void:
	night_lights.clear()
	night_light_energy.clear()
	night_fire_meshes.clear()
	night_fire_emission.clear()
	var root := get_parent()
	if not root:
		return
	_collect_night_lights_recursive(root)
	_update_night_lights(_daylight_value(), 1.0)

func _collect_night_lights_recursive(node: Node) -> void:
	if node is MeshInstance3D and _is_night_fire(node):
		_setup_night_fire_mesh(node as MeshInstance3D)
	if node is Light3D and _is_night_lamp(node):
		var light := node as Light3D
		night_lights.append(light)
		night_light_energy[light.get_instance_id()] = max(0.1, light.light_energy)
		if light is OmniLight3D:
			var omni := light as OmniLight3D
			omni.omni_range = max(omni.omni_range, 9.5)
			omni.shadow_enabled = false
	for child in node.get_children():
		_collect_night_lights_recursive(child)

func _is_night_lamp(node: Node) -> bool:
	var path := str(node.get_path()).to_lower()
	return path.find("street lights") >= 0 or path.find("streetlight") >= 0 or path.find("street_light") >= 0 or path.find("campfire") >= 0

func _is_night_fire(node: Node) -> bool:
	return str(node.get_path()).to_lower().find("campfire") >= 0

func _setup_night_fire_mesh(mesh_instance: MeshInstance3D) -> void:
	var mat: Material = mesh_instance.material_override
	if not mat and mesh_instance.mesh and mesh_instance.mesh.get_surface_count() > 0:
		mat = mesh_instance.mesh.surface_get_material(0)
	if not mat is ShaderMaterial:
		return
	var shader_mat := (mat as ShaderMaterial).duplicate()
	mesh_instance.material_override = shader_mat
	night_fire_meshes.append(mesh_instance)
	night_fire_emission[mesh_instance.get_instance_id()] = float(shader_mat.get_shader_parameter("emission_strength"))

func _update_night_lights(daylight: float, light_scale: float) -> void:
	var darkness: float = _night_darkness(daylight)
	var storm_boost: float = 1.0 + rain_strength * 0.16 + dimness * 0.22
	for light in night_lights:
		if not is_instance_valid(light):
			continue
		var base_energy: float = float(night_light_energy.get(light.get_instance_id(), 8.0))
		var energy: float = base_energy * darkness * storm_boost * clamp(1.15 - light_scale * 0.08, 0.9, 1.15)
		light.visible = darkness > 0.02
		light.light_energy = energy if light.visible else 0.0
	_update_night_fire_visuals(darkness)

func _night_darkness(daylight: float) -> float:
	return smoothstep(0.0, 1.0, clamp((0.42 - daylight) / 0.34, 0.0, 1.0))

func _update_night_fire_visuals(darkness: float) -> void:
	for fire in night_fire_meshes:
		if not is_instance_valid(fire):
			continue
		fire.visible = darkness > 0.02
		var mat := fire.material_override as ShaderMaterial
		if mat:
			var base_emission: float = float(night_fire_emission.get(fire.get_instance_id(), 12.5))
			mat.set_shader_parameter("emission_strength", base_emission * darkness)
func _update_lights(phase: float, daylight: float, sunset: float, light_scale: float) -> void:
	var sun_vector := Vector3(cos(phase) * 0.72, sin(phase), sin(phase * 0.57 + 1.2) * 0.42).normalized()
	sun.look_at(-sun_vector, Vector3.UP)
	sun.light_energy = lerp(0.02, 1.15, daylight) * light_scale
	sun.light_color = Color(1.0, 0.95, 0.84).lerp(Color(1.0, 0.52, 0.28), sunset * 0.72)
	sun.shadow_enabled = daylight > 0.04
	sun.directional_shadow_max_distance = 96.0
	var moon_vector := -sun_vector
	moon.look_at(-moon_vector, Vector3.UP)
	moon.light_energy = (1.0 - daylight) * (0.18 if rain_strength < 0.45 else 0.08)
	moon.light_color = Color(0.48, 0.58, 0.86)

func _update_environment(daylight: float, sunset: float, light_scale: float) -> void:
	var env := world_env.environment
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = lerp(0.055, 0.46, daylight) * light_scale + fog_strength * 0.5
	env.ambient_light_color = Color(0.12, 0.17, 0.28).lerp(Color(0.62, 0.72, 0.78), daylight).lerp(Color(1.0, 0.62, 0.42), sunset * 0.25)
	env.adjustment_enabled = true
	env.adjustment_saturation = lerp(0.78, 1.08, daylight) - rain_strength * 0.12
	env.adjustment_contrast = lerp(1.04, 1.0, daylight) + sunset * 0.03
	env.adjustment_brightness = lerp(0.72, 1.02, daylight) * light_scale
	var final_fog: float = fog_strength + rain_strength * 0.004
	env.set("fog_enabled", true)
	env.set("fog_density", max(0.000001, final_fog))
	env.set("fog_light_color", Color(0.32, 0.42, 0.56).lerp(Color(0.78, 0.88, 0.95), daylight))
	env.set("fog_sky_affect", lerp(0.02, 0.46, clamp(final_fog * 22.0 + rain_strength * 0.2, 0.0, 1.0)))

func _update_sky(daylight: float, sunset: float) -> void:
	if not sky_mat:
		return
	var storm := rain_strength
	sky_mat.set_shader_parameter("clouds_cutoff", lerp(0.58, 0.22, cloudiness))
	sky_mat.set_shader_parameter("clouds_fuzziness", lerp(0.38, 0.78, cloudiness))
	sky_mat.set_shader_parameter("clouds_weight", clamp(cloudiness * 0.38 + storm * 0.68, 0.0, 1.0))
	sky_mat.set_shader_parameter("clouds_speed", lerp(0.8, 4.3, storm + cloudiness * 0.35))
	sky_mat.set_shader_parameter("day_top_color", Color(0.05, 0.48, 0.95).lerp(Color(0.32, 0.44, 0.58), storm))
	sky_mat.set_shader_parameter("day_bottom_color", Color(0.48, 0.78, 1.0).lerp(Color(0.56, 0.62, 0.68), storm))
	sky_mat.set_shader_parameter("sunset_bottom_color", Color(1.0, 0.47, 0.24).lerp(Color(0.72, 0.36, 0.3), storm))
	sky_mat.set_shader_parameter("clouds_top_color", Color(1, 1, 1).lerp(Color(0.42, 0.48, 0.56), storm))
	sky_mat.set_shader_parameter("clouds_middle_color", Color(0.9, 0.92, 0.96).lerp(Color(0.28, 0.32, 0.38), storm))
	sky_mat.set_shader_parameter("clouds_bottom_color", Color(0.76, 0.8, 0.86).lerp(Color(0.12, 0.15, 0.2), storm))
	sky_mat.set_shader_parameter("horizon_blur", lerp(0.05, 0.1, fog_strength + storm * 0.12))

func _daylight_value() -> float:
	return smoothstep(-0.12, 0.34, sin((time_of_day - 6.0) / 24.0 * TAU))

func _grab_sky_material() -> void:
	var env := world_env.environment
	if env and env.sky and env.sky.sky_material is ShaderMaterial:
		sky_mat = env.sky.sky_material as ShaderMaterial

func _find_first(type: Variant) -> Node:
	var root := get_parent()
	if not root:
		return null
	for child in root.get_children():
		if child != self and is_instance_of(child, type):
			return child
	return null

func _phase_name() -> String:
	if time_of_day < 5.0:
		return "night"
	if time_of_day < 8.0:
		return "sunrise"
	if time_of_day < 12.0:
		return "morning"
	if time_of_day < 17.0:
		return "afternoon"
	if time_of_day < 20.0:
		return "sunset"
	return "night"
