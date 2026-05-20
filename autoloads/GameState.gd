extends Node

signal selected_spawn_changed(item: Dictionary)
signal api_key_changed(key: String)
signal chat_sent(text: String)
signal brain_config_changed(config: Dictionary)
signal npc_spoke(text: String, emotion: String)
signal npc_thinking_changed(active: bool)
signal game_settings_changed(settings: Dictionary)

const API_KEY_PATH := "user://api_key.cfg"
const BRAIN_CONFIG_PATH := "user://brain.cfg"
const GAME_SETTINGS_PATH := "user://game_settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const AMBIENT_BUS := "Ambient"
const DEFAULT_GOOGLE_MODEL := "gemma-4-31b-it"
const DEFAULT_OPENROUTER_MODEL := "google/gemma-4-31b-it:free"
const DEFAULT_OLLAMA_MODEL := "gemma4:31b"
const DEFAULT_LMSTUDIO_MODEL := "local-model"

var selected_spawn_item: Dictionary = {}
var api_key := ""
var brain_provider := "google"
var brain_model := DEFAULT_GOOGLE_MODEL
var brain_base_url := ""
var menu_open := false
var chat_open := false
var api_dialog_open := false
var pause_open := false
var console_open := false
var last_player_speech := ""
var last_npc_speech := ""
var last_npc_emotion := "neutral"
var npc_thinking := false
var ai_brain_enabled := true
var display_resolution := Vector2i(1280, 720)
var display_mode := "windowed"
var graphics_quality := "high"
var vsync_enabled := true
var fps_limit := 0
var audio_master_volume := 1.0
var audio_music_volume := 0.85
var audio_sfx_volume := 0.9
var audio_ambient_volume := 0.75
var audio_muted := false

func _ready() -> void:
	randomize()
	_ensure_inputs()
	load_brain_config()
	load_game_settings()
	_update_mouse_mode()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_update_mouse_mode()

func set_selected_spawn_item(item: Dictionary) -> void:
	selected_spawn_item = item.duplicate()
	selected_spawn_changed.emit(selected_spawn_item)

func clear_selected_spawn_item() -> void:
	selected_spawn_item = {}
	selected_spawn_changed.emit(selected_spawn_item)

func set_menu_open(value: bool) -> void:
	menu_open = value
	_update_mouse_mode()

func set_chat_open(value: bool) -> void:
	chat_open = value
	_update_mouse_mode()

func set_api_dialog_open(value: bool) -> void:
	api_dialog_open = value
	_update_mouse_mode()

func set_pause_open(value: bool) -> void:
	pause_open = value
	_update_mouse_mode()

func set_console_open(value: bool) -> void:
	console_open = value
	_update_mouse_mode()

func allows_mouse_look() -> bool:
	return not menu_open and not chat_open and not api_dialog_open and not pause_open and not console_open

func submit_chat(text: String) -> void:
	last_player_speech = text.strip_edges()
	if last_player_speech != "":
		chat_sent.emit(last_player_speech)

func notify_npc_speech(text: String, emotion_value: String) -> void:
	last_npc_speech = text.strip_edges()
	last_npc_emotion = emotion_value.strip_edges()
	if last_npc_emotion == "":
		last_npc_emotion = "neutral"
	if last_npc_speech != "":
		npc_spoke.emit(last_npc_speech, last_npc_emotion)

func set_npc_thinking(value: bool) -> void:
	if npc_thinking == value:
		return
	npc_thinking = value
	npc_thinking_changed.emit(npc_thinking)

func load_api_key() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(API_KEY_PATH) == OK:
		api_key = str(cfg.get_value("google", "api_key", "")).strip_edges()

func save_api_key(key: String) -> void:
	api_key = key.strip_edges()
	var cfg := ConfigFile.new()
	cfg.set_value("google", "api_key", api_key)
	cfg.save(API_KEY_PATH)
	api_key_changed.emit(api_key)

func load_brain_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(BRAIN_CONFIG_PATH) == OK:
		var should_save_brain_config := false
		brain_provider = str(cfg.get_value("brain", "provider", "google"))
		ai_brain_enabled = bool(cfg.get_value("brain", "enabled", true))
		api_key = str(cfg.get_value("brain", "api_key", "")).strip_edges()
		brain_model = str(cfg.get_value("brain", "model", default_model(brain_provider))).strip_edges()
		brain_base_url = str(cfg.get_value("brain", "base_url", default_base_url(brain_provider))).strip_edges()
		if brain_model == "":
			brain_model = default_model(brain_provider)
			should_save_brain_config = true
		if brain_base_url == "":
			brain_base_url = default_base_url(brain_provider)
			should_save_brain_config = true
		if brain_provider == "google" or brain_provider == "openrouter":
			var locked_model := default_model(brain_provider)
			if brain_model != locked_model:
				brain_model = locked_model
				should_save_brain_config = true
		elif brain_provider == "ollama" and brain_model == "gemma3:12b":
			brain_model = default_model(brain_provider)
			should_save_brain_config = true
		if should_save_brain_config:
			cfg.set_value("brain", "provider", brain_provider)
			cfg.set_value("brain", "api_key", api_key)
			cfg.set_value("brain", "model", brain_model)
			cfg.set_value("brain", "base_url", brain_base_url)
			cfg.set_value("brain", "enabled", ai_brain_enabled)
			cfg.save(BRAIN_CONFIG_PATH)
	else:
		load_api_key()
		brain_provider = "google"
		brain_model = DEFAULT_GOOGLE_MODEL
		brain_base_url = default_base_url(brain_provider)

func save_brain_config(provider: String, key: String, model: String, base_url: String) -> void:
	brain_provider = provider
	api_key = key.strip_edges()
	brain_model = model.strip_edges()
	brain_base_url = base_url.strip_edges()
	if brain_model == "":
		brain_model = default_model(provider)
	if brain_base_url == "":
		brain_base_url = default_base_url(provider)
	var cfg := ConfigFile.new()
	cfg.set_value("brain", "provider", brain_provider)
	cfg.set_value("brain", "api_key", api_key)
	cfg.set_value("brain", "model", brain_model)
	cfg.set_value("brain", "base_url", brain_base_url)
	cfg.set_value("brain", "enabled", ai_brain_enabled)
	cfg.save(BRAIN_CONFIG_PATH)
	if provider == "google":
		save_api_key(api_key)
	brain_config_changed.emit(get_brain_config())

func load_game_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GAME_SETTINGS_PATH) == OK:
		display_resolution = Vector2i(int(cfg.get_value("display", "width", 1280)), int(cfg.get_value("display", "height", 720)))
		display_mode = str(cfg.get_value("display", "mode", "windowed")).strip_edges()
		graphics_quality = str(cfg.get_value("graphics", "quality", "high")).strip_edges()
		vsync_enabled = bool(cfg.get_value("display", "vsync", true))
		fps_limit = int(cfg.get_value("display", "fps_limit", 0))
		audio_master_volume = float(cfg.get_value("audio", "master", 1.0))
		audio_music_volume = float(cfg.get_value("audio", "music", 0.85))
		audio_sfx_volume = float(cfg.get_value("audio", "sfx", 0.9))
		audio_ambient_volume = float(cfg.get_value("audio", "ambient", 0.75))
		audio_muted = bool(cfg.get_value("audio", "muted", false))
	display_resolution = _clean_resolution(display_resolution)
	if not _display_modes().has(display_mode):
		display_mode = "windowed"
	if not _quality_names().has(graphics_quality):
		graphics_quality = "high"
	apply_game_settings()

func save_game_settings(resolution: Vector2i, mode: String, quality: String, vsync: bool, max_fps: int) -> void:
	display_resolution = _clean_resolution(resolution)
	display_mode = mode if _display_modes().has(mode) else "windowed"
	graphics_quality = quality if _quality_names().has(quality) else "high"
	vsync_enabled = vsync
	fps_limit = clamp(max_fps, 0, 360)
	var cfg := ConfigFile.new()
	cfg.load(GAME_SETTINGS_PATH)
	cfg.set_value("display", "width", display_resolution.x)
	cfg.set_value("display", "height", display_resolution.y)
	cfg.set_value("display", "mode", display_mode)
	cfg.set_value("display", "vsync", vsync_enabled)
	cfg.set_value("display", "fps_limit", fps_limit)
	cfg.set_value("graphics", "quality", graphics_quality)
	cfg.save(GAME_SETTINGS_PATH)
	apply_game_settings()
	game_settings_changed.emit(get_game_settings())

func save_audio_settings(master: float, music: float, sfx: float, ambient: float, muted: bool) -> void:
	audio_master_volume = clamp(master, 0.0, 1.0)
	audio_music_volume = clamp(music, 0.0, 1.0)
	audio_sfx_volume = clamp(sfx, 0.0, 1.0)
	audio_ambient_volume = clamp(ambient, 0.0, 1.0)
	audio_muted = muted
	var cfg := ConfigFile.new()
	cfg.load(GAME_SETTINGS_PATH)
	cfg.set_value("audio", "master", audio_master_volume)
	cfg.set_value("audio", "music", audio_music_volume)
	cfg.set_value("audio", "sfx", audio_sfx_volume)
	cfg.set_value("audio", "ambient", audio_ambient_volume)
	cfg.set_value("audio", "muted", audio_muted)
	cfg.save(GAME_SETTINGS_PATH)
	_apply_audio_settings()
	game_settings_changed.emit(get_game_settings())

func apply_game_settings() -> void:
	Engine.max_fps = fps_limit
	_ensure_audio_buses()
	_apply_audio_settings()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
		_apply_window_settings()
	_apply_graphics_quality()

func get_game_settings() -> Dictionary:
	return {
		"resolution": display_resolution,
		"display_mode": display_mode,
		"quality": graphics_quality,
		"vsync": vsync_enabled,
		"fps_limit": fps_limit,
		"audio_master": audio_master_volume,
		"audio_music": audio_music_volume,
		"audio_sfx": audio_sfx_volume,
		"audio_ambient": audio_ambient_volume,
		"audio_muted": audio_muted
	}

func resolution_options() -> Array[Vector2i]:
	return [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160)
	]

func display_mode_names() -> PackedStringArray:
	return PackedStringArray(["windowed", "fullscreen", "exclusive_fullscreen"])

func quality_names() -> PackedStringArray:
	return PackedStringArray(["low", "medium", "high", "ultra"])

func fps_limit_options() -> Array[int]:
	return [0, 60, 90, 120, 144, 165, 240]

func master_volume_db() -> float:
	return _volume_to_db(0.0 if audio_muted else audio_master_volume)

func get_brain_config() -> Dictionary:
	return {"provider": brain_provider, "api_key": api_key, "model": brain_model, "base_url": brain_base_url}

func set_ai_brain_enabled(value: bool) -> void:
	ai_brain_enabled = value
	save_brain_config(brain_provider, api_key, brain_model, brain_base_url)

func is_brain_configured() -> bool:
	if not ai_brain_enabled:
		return false
	if brain_provider == "ollama" or brain_provider == "lmstudio":
		return brain_model.strip_edges() != "" and brain_base_url.strip_edges() != ""
	return api_key.strip_edges() != "" and brain_model.strip_edges() != ""

func provider_names() -> PackedStringArray:
	return PackedStringArray(["google", "openrouter", "ollama", "lmstudio"])

func default_model(provider: String) -> String:
	match provider:
		"openrouter":
			return DEFAULT_OPENROUTER_MODEL
		"ollama":
			return DEFAULT_OLLAMA_MODEL
		"lmstudio":
			return DEFAULT_LMSTUDIO_MODEL
	return DEFAULT_GOOGLE_MODEL

func default_base_url(provider: String) -> String:
	match provider:
		"openrouter":
			return "https://openrouter.ai/api/v1/chat/completions"
		"ollama":
			return "http://localhost:11434/api/chat"
		"lmstudio":
			return "http://localhost:1234/v1/chat/completions"
	return "https://generativelanguage.googleapis.com/v1beta"

func _apply_window_settings() -> void:
	if display_mode == "windowed":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(display_resolution)
		var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - display_resolution) / 2)
	elif display_mode == "exclusive_fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _apply_graphics_quality() -> void:
	var viewport := get_tree().root
	match graphics_quality:
		"low":
			_set_viewport_quality(viewport, Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED, false, 0.72, 1024, 2.0)
		"medium":
			_set_viewport_quality(viewport, Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_FXAA, false, 0.88, 2048, 1.35)
		"ultra":
			_set_viewport_quality(viewport, Viewport.MSAA_8X, Viewport.SCREEN_SPACE_AA_DISABLED, false, 1.0, 8192, 0.45)
		_:
			_set_viewport_quality(viewport, Viewport.MSAA_4X, Viewport.SCREEN_SPACE_AA_DISABLED, false, 1.0, 4096, 0.85)

func _set_viewport_quality(viewport: Viewport, msaa: int, ssaa: int, taa: bool, scale: float, shadow_size: int, lod: float) -> void:
	viewport.msaa_3d = msaa
	viewport.screen_space_aa = ssaa
	viewport.use_taa = taa
	viewport.scaling_3d_scale = scale
	viewport.positional_shadow_atlas_size = shadow_size
	viewport.mesh_lod_threshold = lod

func _ensure_audio_buses() -> void:
	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)
	_ensure_audio_bus(AMBIENT_BUS)

func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var index: int = AudioServer.get_bus_count()
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")

func _apply_audio_settings() -> void:
	_ensure_audio_buses()
	_set_bus_volume("Master", 0.0 if audio_muted else audio_master_volume)
	_set_bus_volume(MUSIC_BUS, 0.0 if audio_muted else audio_music_volume)
	_set_bus_volume(SFX_BUS, 0.0 if audio_muted else audio_sfx_volume)
	_set_bus_volume(AMBIENT_BUS, 0.0 if audio_muted else audio_ambient_volume)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, _volume_to_db(linear))

func _volume_to_db(value: float) -> float:
	var clean: float = clamp(value, 0.0, 1.0)
	return -80.0 if clean <= 0.001 else linear_to_db(clean)

func _clean_resolution(value: Vector2i) -> Vector2i:
	var width: int = clamp(value.x, 960, 7680)
	var height: int = clamp(value.y, 540, 4320)
	return Vector2i(width, height)

func _display_modes() -> PackedStringArray:
	return display_mode_names()

func _quality_names() -> PackedStringArray:
	return quality_names()

func _update_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open or chat_open or api_dialog_open or pause_open or console_open else Input.MOUSE_MODE_CAPTURED

func _ensure_inputs() -> void:
	_ensure_key("move_forward", KEY_W)
	_ensure_key("move_backward", KEY_S)
	_ensure_key("move_left", KEY_A)
	_ensure_key("move_right", KEY_D)
	_ensure_key("jump", KEY_SPACE)
	_ensure_key("sprint", KEY_SHIFT)
	_ensure_key("crouch", KEY_CTRL)
	_ensure_key("interact", KEY_E)
	_ensure_key("spawn_menu", KEY_Q)
	_ensure_key("chat", KEY_T)
	_ensure_key("toggle_npc_camera", KEY_P)
	_ensure_key("pause_menu", KEY_ESCAPE)
	_ensure_key("console", KEY_QUOTELEFT)
	_ensure_key("pin_object", KEY_G)
	_ensure_key("rotate_object", KEY_R)
	_ensure_key("rotate_object_alt", KEY_R)
	_ensure_key("use_object", KEY_F)
	_ensure_mouse("primary_fire", MOUSE_BUTTON_LEFT)
	_ensure_mouse("secondary_fire", MOUSE_BUTTON_RIGHT)

func _ensure_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == keycode:
			return
	var input := InputEventKey.new()
	input.keycode = keycode
	input.physical_keycode = keycode
	InputMap.action_add_event(action, input)

func _ensure_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return
	var input := InputEventMouseButton.new()
	input.button_index = button
	InputMap.action_add_event(action, input)
