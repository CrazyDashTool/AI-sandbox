extends CanvasLayer

const LIQUID_GLASS := preload("res://scripts/LiquidGlass.gd")

var panel: PanelContainer
var log_label: RichTextLabel
var input: LineEdit
var history: PackedStringArray = []
var history_index := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	_build()
	_write("AI Sandbox console. Type help.")

func _exit_tree() -> void:
	if visible:
		GameState.set_console_open(false)

func _input(event: InputEvent) -> void:
	if _is_console_key(event):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed("pause_menu"):
		_close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			_history_step(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_history_step(1)
			get_viewport().set_input_as_handled()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	panel = PanelContainer.new()
	panel.anchor_left = 0.015
	panel.anchor_right = 0.985
	panel.anchor_top = 0.02
	panel.anchor_bottom = 0.46
	panel.add_theme_stylebox_override("panel", LIQUID_GLASS.panel(1.28, 8))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "AI Sandbox Console"
	LIQUID_GLASS.apply_title(title, 18)
	box.add_child(title)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = false
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.custom_minimum_size = Vector2(0, 210)
	LIQUID_GLASS.apply_rich_text(log_label)
	box.add_child(log_label)
	input = LineEdit.new()
	input.placeholder_text = "Type command, e.g. weather rain, time lock 18:30, noclip, fly"
	LIQUID_GLASS.apply_line_edit(input)
	input.text_submitted.connect(_submit)
	box.add_child(input)

func _toggle() -> void:
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	visible = true
	GameState.set_console_open(true)
	input.grab_focus()
	input.caret_column = input.text.length()

func _close() -> void:
	visible = false
	GameState.set_console_open(false)
	input.release_focus()

func _submit(text: String) -> void:
	var command := text.strip_edges()
	input.clear()
	if command == "":
		return
	history.append(command)
	history_index = history.size()
	_write("> %s" % command)
	_execute(command)

func _execute(command: String) -> void:
	var tokens := command.split(" ", false)
	var head := str(tokens[0]).to_lower()
	match head:
		"help":
			_help()
		"clear", "cls":
			log_label.clear()
		"weather":
			_command_weather(tokens)
		"lightning":
			_command_lightning()
		"time":
			_command_time(tokens)
		"timescale", "time_scale":
			_command_timescale(tokens)
		"host_timescale":
			_command_host_timescale(tokens)
		"noclip":
			_command_fly(tokens, true)
		"fly":
			_command_fly(tokens, false)
		"flyspeed", "speed":
			_command_speed(tokens)
		"tp", "teleport":
			_command_tp(tokens)
		"respawn":
			_command_respawn()
		"spawn":
			_command_spawn(tokens)
		"status":
			_command_status()
		"close", "exit":
			_close()
		_:
			_write("Unknown command. Type help.")

func _help() -> void:
	_write("Commands: weather clear/cloudy/mist/rain [now], weather lock [type], weather unlock, lightning, time 0-24|morning|noon|evening|night, time lock [hour], time unlock, timescale N, host_timescale N, noclip [on/off], fly [on/off], flyspeed N, tp x y z, respawn, spawn Type Name, status, clear.")
	_write("Weather examples: weather rain, weather rain lock, weather lock, weather lock clear, weather unlock.")
	_write("Time examples: time 18:30, time night, time lock, time lock 18:30, time lock night, time 18:30 lock, time unlock.")

func _command_weather(tokens: PackedStringArray) -> void:
	var weather := _weather()
	if not weather:
		_write("No WeatherCycle found.")
		return
	if tokens.size() < 2:
		_write("Weather: %s" % weather.call("get_weather_status"))
		return
	var name := str(tokens[1]).to_lower()
	if name == "list":
		_write("Weather types: clear, cloudy, mist, rain.")
		return
	if ["lock", "freeze", "hold"].has(name):
		var immediate := tokens.has("now") or tokens.has("instant")
		if tokens.size() >= 3 and not ["now", "instant"].has(str(tokens[2]).to_lower()):
			var locked_name := str(tokens[2]).to_lower()
			if not weather.call("set_weather", locked_name, immediate):
				_write("Unknown weather. Use clear, cloudy, mist, rain.")
				return
			if weather.has_method("set_weather_locked"):
				weather.call("set_weather_locked", true)
			_write("Weather locked to %s%s." % [locked_name, " instantly" if immediate else " smoothly"])
			return
		if weather.has_method("set_weather_locked"):
			weather.call("set_weather_locked", true)
		_write("Weather locked. Use weather unlock or set another weather manually.")
		return
	if ["unlock", "unfreeze", "resume", "auto", "off"].has(name):
		if weather.has_method("set_weather_locked"):
			weather.call("set_weather_locked", false)
		_write("Weather auto cycle enabled.")
		return
	var immediate := tokens.has("now") or tokens.has("instant")
	var should_lock := tokens.has("lock") or tokens.has("freeze") or tokens.has("hold")
	var was_weather_locked := weather.has_method("is_weather_locked") and bool(weather.call("is_weather_locked"))
	var was_time_locked := weather.has_method("is_time_locked") and bool(weather.call("is_time_locked"))
	if weather.call("set_weather", name, immediate):
		if weather.has_method("set_weather_locked"):
			weather.call("set_weather_locked", should_lock or was_weather_locked)
		var unlock_text := " Time lock disabled." if was_time_locked else ""
		var lock_text := " Weather locked." if should_lock or was_weather_locked else ""
		_write("Weather set to %s%s.%s%s" % [name, " instantly" if immediate else " smoothly", lock_text, unlock_text])
	else:
		_write("Unknown weather. Use clear, cloudy, mist, rain.")

func _command_lightning() -> void:
	var weather := _weather()
	if weather and weather.has_method("trigger_lightning"):
		weather.call("trigger_lightning")
		_write("Distant lightning triggered.")
	else:
		_write("No lightning system found.")

func _command_time(tokens: PackedStringArray) -> void:
	var weather := _weather()
	if not weather:
		_write("No WeatherCycle found.")
		return
	if tokens.size() < 2:
		var lock_text := ""
		if weather.has_method("is_time_locked"):
			lock_text = " locked" if bool(weather.call("is_time_locked")) else " running"
		_write("Time: %.2f%s" % [float(weather.call("get_time_of_day")), lock_text])
		return
	var mode := str(tokens[1]).to_lower()
	if ["lock", "freeze", "hold"].has(mode):
		var parsed := float(weather.call("get_time_of_day"))
		if tokens.size() >= 3:
			parsed = _parse_time(str(tokens[2]))
			if parsed < 0.0:
				_write("Use time lock, time lock 18:30, or time lock night.")
				return
			weather.call("set_time_of_day", parsed)
		if weather.has_method("set_time_locked"):
			weather.call("set_time_locked", true)
		_write("Time locked at %.2f. Use time unlock or change weather to resume." % parsed)
		return
	if ["unlock", "unfreeze", "resume", "run", "off"].has(mode):
		if weather.has_method("set_time_locked"):
			weather.call("set_time_locked", false)
		_write("Time unlocked.")
		return
	var parsed := _parse_time(str(tokens[1]))
	if parsed < 0.0:
		_write("Use time 0-24, time 18:30, morning/noon/evening/night, time lock, or time unlock.")
		return
	weather.call("set_time_of_day", parsed)
	if tokens.has("lock") or tokens.has("freeze") or tokens.has("hold"):
		if weather.has_method("set_time_locked"):
			weather.call("set_time_locked", true)
		_write("Time set and locked at %.2f." % parsed)
	else:
		_write("Time set to %.2f." % parsed)

func _command_timescale(tokens: PackedStringArray) -> void:
	var weather := _weather()
	if not weather:
		_write("No WeatherCycle found.")
		return
	if tokens.size() < 2:
		_write("World timescale: %.2fx." % float(weather.call("get_time_scale")))
		return
	if not str(tokens[1]).is_valid_float():
		_write("Use timescale 1, timescale 4, or timescale 0.25.")
		return
	var value: float = clamp(float(tokens[1]), 0.0, 64.0)
	weather.call("set_time_scale", value)
	_write("World timescale set to %.2fx." % value)

func _command_host_timescale(tokens: PackedStringArray) -> void:
	if tokens.size() < 2:
		_write("Host timescale: %.2fx." % Engine.time_scale)
		return
	if not str(tokens[1]).is_valid_float():
		_write("Use host_timescale 1, host_timescale 0.5, or host_timescale 2.")
		return
	Engine.time_scale = clamp(float(tokens[1]), 0.05, 8.0)
	_write("Host timescale set to %.2fx." % Engine.time_scale)

func _command_fly(tokens: PackedStringArray, noclip: bool) -> void:
	var player := _player()
	if not player or not player.has_method("set_fly_mode"):
		_write("No player found.")
		return
	var current := bool(player.get("fly_mode")) and (not noclip or bool(player.get("noclip_mode")))
	var enabled := _toggle_value(tokens, current)
	player.call("set_fly_mode", enabled, noclip if enabled else false)
	_write("%s %s." % ["Noclip" if noclip else "Fly", "ON" if enabled else "OFF"])

func _command_speed(tokens: PackedStringArray) -> void:
	var player := _player()
	if tokens.size() < 2 or not str(tokens[1]).is_valid_float():
		_write("Use flyspeed 10.")
		return
	if player and player.has_method("set_fly_speed"):
		player.call("set_fly_speed", float(tokens[1]))
		_write("Fly speed set to %.1f." % float(tokens[1]))

func _command_tp(tokens: PackedStringArray) -> void:
	var player := _player()
	if not player:
		_write("No player found.")
		return
	if tokens.size() < 4 or not str(tokens[1]).is_valid_float() or not str(tokens[2]).is_valid_float() or not str(tokens[3]).is_valid_float():
		_write("Use tp x y z.")
		return
	player.global_position = Vector3(float(tokens[1]), float(tokens[2]), float(tokens[3]))
	player.set("velocity", Vector3.ZERO)
	_write("Teleported to %.1f %.1f %.1f." % [float(tokens[1]), float(tokens[2]), float(tokens[3])])

func _command_respawn() -> void:
	var player := _player()
	if player and player.has_method("_respawn"):
		player.call("_respawn")
		_write("Player respawned.")
	else:
		_write("No player found.")

func _command_spawn(tokens: PackedStringArray) -> void:
	var player := _player()
	var spawner := get_tree().get_first_node_in_group("object_spawner")
	if not player or not spawner:
		_write("Need player and object spawner.")
		return
	if tokens.size() < 2:
		_write("Use spawn Cube or spawn Metal pipe.")
		return
	var type_parts: Array = Array(tokens).slice(1, tokens.size())
	var type_name := " ".join(type_parts)
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	var pos: Vector3 = player.global_position + Vector3(0, 1.0, -3.0)
	if camera:
		pos = camera.global_position - camera.global_transform.basis.z * 4.0
	spawner.call("spawn_prop", type_name, pos, Vector3.UP, "console")
	_write("Spawned %s." % type_name)

func _command_status() -> void:
	var player := _player()
	var weather := _weather()
	if weather:
		_write("Weather %s, time %.2f, host %.2fx." % [weather.call("get_weather_status"), float(weather.call("get_time_of_day")), Engine.time_scale])
	if player:
		_write("Player %.1f %.1f %.1f, fly=%s, noclip=%s." % [player.global_position.x, player.global_position.y, player.global_position.z, str(player.get("fly_mode")), str(player.get("noclip_mode"))])

func _parse_time(value: String) -> float:
	var clean := value.to_lower().strip_edges()
	match clean:
		"morning":
			return 8.0
		"noon", "day":
			return 12.0
		"evening", "sunset":
			return 18.5
		"night":
			return 22.0
		"midnight":
			return 0.0
	if clean.find(":") >= 0:
		var parts := clean.split(":", false)
		if parts.size() == 2 and str(parts[0]).is_valid_float() and str(parts[1]).is_valid_float():
			return fposmod(float(parts[0]) + clamp(float(parts[1]), 0.0, 59.0) / 60.0, 24.0)
	if clean.is_valid_float():
		return fposmod(float(clean), 24.0)
	return -1.0

func _toggle_value(tokens: PackedStringArray, current: bool) -> bool:
	if tokens.size() < 2:
		return not current
	var value := str(tokens[1]).to_lower()
	if ["on", "1", "true", "yes"].has(value):
		return true
	if ["off", "0", "false", "no"].has(value):
		return false
	return not current

func _history_step(step: int) -> void:
	if history.is_empty():
		return
	history_index = clamp(history_index + step, 0, history.size())
	input.text = "" if history_index >= history.size() else history[history_index]
	input.caret_column = input.text.length()

func _is_console_key(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo and (key.is_action_pressed("console") or key.keycode == KEY_QUOTELEFT or key.physical_keycode == KEY_QUOTELEFT or key.unicode == 96 or key.unicode == 126 or key.unicode == 1105 or key.unicode == 1025)

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _weather() -> Node:
	return get_tree().get_first_node_in_group("weather_cycle")

func _write(text: String) -> void:
	log_label.append_text("%s\n" % text)
