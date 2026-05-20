extends Node3D

const LIQUID_GLASS := preload("res://scripts/LiquidGlass.gd")
const SETTINGS_TABS := preload("res://scripts/SettingsTabsPanel.gd")
const GAME_SCENE := "res://main.tscn"
const MENU_TRACKS := ["res://Sounds/Jaz.mp3", "res://Sounds/Chiled.mp3", "res://Sounds/Neon.mp3"]
const MENU_CAMERA_BASE := Vector3(42.0, 5.4, -34.0)
const MENU_CAMERA_LOOK := Vector3(2.0, 1.35, 2.0)

var provider_options: OptionButton
var endpoint_edit: LineEdit
var brain_key_edit: LineEdit
var brain_toggle: Button
var guide_panel: PanelContainer
var guide_scrim: ColorRect
var guide_tween: Tween
var status_label: Label
var menu_music_player: AudioStreamPlayer
var settings_tabs

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.set_menu_open(true)
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera:
		camera.current = true
		_place_menu_camera(camera, MENU_CAMERA_BASE, MENU_CAMERA_LOOK)
	_start_menu_music()
	_build_ui()
	_load_fields()

func _exit_tree() -> void:
	if menu_music_player:
		menu_music_player.stop()
		menu_music_player.stream = null
	GameState.set_menu_open(false)

func _process(delta: float) -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if not camera:
		return
	var time := Time.get_ticks_msec() * 0.001
	var target_position := MENU_CAMERA_BASE + Vector3(sin(time * 0.12) * 1.4, sin(time * 0.09) * 0.18, cos(time * 0.1) * 1.1)
	var target_look := MENU_CAMERA_LOOK + Vector3(sin(time * 0.08) * 0.85, 0.0, cos(time * 0.07) * 0.7)
	_place_menu_camera(camera, camera.global_position.lerp(target_position, min(1.0, delta * 0.65)), target_look)

func _place_menu_camera(camera: Camera3D, position: Vector3, look_target: Vector3) -> void:
	camera.global_position = position
	camera.look_at(look_target, Vector3.UP)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var wash := ColorRect.new()
	wash.color = Color(0.015, 0.025, 0.04, 0.46)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wash)

	var top_band := ColorRect.new()
	top_band.color = Color(0.02, 0.18, 0.2, 0.22)
	top_band.anchor_right = 1.0
	top_band.anchor_bottom = 0.24
	root.add_child(top_band)

	root.add_child(_main_panel())
	root.add_child(_settings_panel())
	guide_scrim = _guide_scrim()
	root.add_child(guide_scrim)
	guide_panel = _guide_panel()
	root.add_child(guide_panel)

func _start_menu_music() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream := load(MENU_TRACKS.pick_random())
	if not stream:
		return
	stream.loop = true
	menu_music_player = AudioStreamPlayer.new()
	menu_music_player.stream = stream
	menu_music_player.bus = GameState.MUSIC_BUS
	menu_music_player.volume_db = -14.0
	add_child(menu_music_player)
	menu_music_player.play()

func _main_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.045
	panel.anchor_right = 0.43
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.86
	panel.add_theme_stylebox_override("panel", LIQUID_GLASS.panel(1.22, 8))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(62, 62)
	badge.add_theme_stylebox_override("panel", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT))
	top.add_child(badge)

	var badge_center := CenterContainer.new()
	badge.add_child(badge_center)
	var badge_text := Label.new()
	badge_text.text = "AI"
	badge_text.add_theme_font_size_override("font_size", 20)
	LIQUID_GLASS.apply_label(badge_text)
	badge_center.add_child(badge_text)

	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_constant_override("separation", 3)
	top.add_child(title)

	var name := Label.new()
	name.text = "AI Sandbox"
	LIQUID_GLASS.apply_title(name, 32)
	title.add_child(name)

	var subtitle := Label.new()
	subtitle.text = "Creative 3D sandbox with an AI companion"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	LIQUID_GLASS.apply_muted_label(subtitle)
	title.add_child(subtitle)

	box.add_child(LIQUID_GLASS.divider())
	box.add_child(_menu_button("Start Sandbox", _start_game, true))
	box.add_child(_menu_button("Sandbox Guide", _toggle_guide))
	box.add_child(_menu_button("Offline Mode", _start_offline))
	box.add_child(_menu_button("Quit", _quit_game))

	var footer := Label.new()
	footer.text = "NPC, model props, tools, water and physics are ready in one scene."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_size_override("font_size", 13)
	LIQUID_GLASS.apply_muted_label(footer)
	box.add_child(footer)
	return panel

func _guide_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.modulate.a = 0.0
	panel.anchor_left = 0.18
	panel.anchor_right = 0.82
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.9
	panel.add_theme_stylebox_override("panel", LIQUID_GLASS.panel(1.26, 8))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)

	var title := Label.new()
	title.text = "Sandbox Guide"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	LIQUID_GLASS.apply_title(title, 28)
	title_row.add_child(title)

	var close_top := Button.new()
	close_top.text = "Close"
	close_top.custom_minimum_size = Vector2(86, 40)
	LIQUID_GLASS.apply_button(close_top)
	close_top.pressed.connect(_toggle_guide)
	title_row.add_child(close_top)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(520, 680)
	text.text = _guide_text()
	LIQUID_GLASS.apply_rich_text(text)
	scroll.add_child(text)
	return panel

func _guide_scrim() -> ColorRect:
	var scrim := ColorRect.new()
	scrim.visible = false
	scrim.modulate.a = 0.0
	scrim.color = Color(0.0, 0.0, 0.0, 0.56)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_guide()
	)
	return scrim

func _settings_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.575
	panel.anchor_right = 0.955
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.9
	panel.add_theme_stylebox_override("panel", LIQUID_GLASS.panel(1.12, 8))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Settings"
	LIQUID_GLASS.apply_title(title, 22)
	box.add_child(title)

	settings_tabs = SETTINGS_TABS.new()
	settings_tabs.setup()
	settings_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(settings_tabs)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	var save := Button.new()
	save.text = "Save"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	LIQUID_GLASS.apply_button(save)
	save.pressed.connect(_save_settings)
	buttons.add_child(save)

	var play := Button.new()
	play.text = "Play"
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	LIQUID_GLASS.apply_button(play, true)
	play.pressed.connect(_start_game)
	buttons.add_child(play)
	return panel

func _menu_button(text: String, target: Callable, accent := false) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 58)
	button.disabled = false
	LIQUID_GLASS.apply_button(button, accent)
	button.pressed.connect(target)
	return button

func _switch_button(label: String, pressed: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = pressed
	button.custom_minimum_size = Vector2(0, 44)
	button.disabled = false
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	LIQUID_GLASS.apply_button(button)
	button.toggled.connect(func(value: bool) -> void:
		_update_switch_text(button, label, value)
		_update_brain_status()
	)
	_update_switch_text(button, label, pressed)
	return button

func _update_switch_text(button: Button, label: String, pressed: bool) -> void:
	button.text = "%s %s" % [label, "ON" if pressed else "OFF"]

func _field(placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	LIQUID_GLASS.apply_line_edit(field)
	return field

func _labeled_control(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(78, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	LIQUID_GLASS.apply_muted_label(label)
	row.add_child(label)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _load_fields() -> void:
	if settings_tabs:
		settings_tabs.load_from_state()

func _save_settings() -> void:
	if settings_tabs:
		settings_tabs.save_to_state()

func _provider_changed(index: int) -> void:
	var provider := provider_options.get_item_text(index)
	endpoint_edit.text = GameState.default_base_url(provider)
	brain_key_edit.placeholder_text = "Optional local key" if provider == "ollama" or provider == "lmstudio" else "AI provider key"
	_update_brain_status()

func _update_brain_status() -> void:
	if not status_label or not provider_options:
		return
	if not brain_toggle.button_pressed:
		status_label.text = "Offline mode"
		status_label.add_theme_stylebox_override("normal", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT_WARM))
		return
	var selected: int = max(0, provider_options.selected)
	var provider := provider_options.get_item_text(selected)
	var needs_key := provider != "ollama" and provider != "lmstudio"
	if needs_key and brain_key_edit and brain_key_edit.text.strip_edges() == "":
		status_label.text = "API key required"
		status_label.add_theme_stylebox_override("normal", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT_WARM))
	else:
		status_label.text = "Ready via %s" % provider.capitalize()
		status_label.add_theme_stylebox_override("normal", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT))

func _toggle_guide() -> void:
	if not guide_panel:
		return
	var opening := not guide_panel.visible
	if guide_tween:
		guide_tween.kill()
	if opening:
		if guide_scrim:
			guide_scrim.visible = true
			guide_scrim.move_to_front()
		guide_panel.visible = true
		guide_panel.move_to_front()
		guide_panel.modulate.a = 0.0
		guide_panel.scale = Vector2(0.94, 0.94)
		guide_panel.pivot_offset = guide_panel.size * 0.5
		if guide_scrim:
			guide_scrim.modulate.a = 0.0
		guide_tween = create_tween()
		guide_tween.set_parallel(true)
		guide_tween.tween_property(guide_panel, "modulate:a", 1.0, 0.22)
		guide_tween.tween_property(guide_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if guide_scrim:
			guide_tween.tween_property(guide_scrim, "modulate:a", 1.0, 0.18)
	else:
		guide_tween = create_tween()
		guide_tween.set_parallel(true)
		guide_tween.tween_property(guide_panel, "modulate:a", 0.0, 0.16)
		guide_tween.tween_property(guide_panel, "scale", Vector2(0.96, 0.96), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if guide_scrim:
			guide_tween.tween_property(guide_scrim, "modulate:a", 0.0, 0.16)
		guide_tween.chain().tween_callback(func() -> void:
			guide_panel.visible = false
			if guide_scrim:
				guide_scrim.visible = false
		)

func _guide_text() -> String:
	return (
		"[b]Quick Start[/b]\n"
		+ "AI Sandbox is a small 3D playground built around physics props, water, tools, and an AI companion. Start in offline mode if you only want to build and explore. Enable the NPC brain when a provider key or local endpoint is ready.\n\n"
		+ "[b]Movement[/b]\n"
		+ "WASD - move\nMouse - look around\nShift - sprint\nSpace - jump\nCtrl - crouch, or swim down underwater\nEsc - pause or close the active UI\n\n"
		+ "[b]Talking To The NPC[/b]\n"
		+ "Press T to open the chat panel. The panel grows from the same bottom area where NPC replies appear, so the conversation stays close to the action. The NPC remembers recent messages, world events, known places, and what it can see through its own camera.\n\n"
		+ "[b]NPC Camera[/b]\n"
		+ "Press P to switch between your camera and the NPC camera. This shows the same eye-level view used for the AI's image requests, so you can check what the model can actually see.\n\n"
		+ "[b]Spawn Menu[/b]\n"
		+ "Press Q to open props and sandbox tools. Pick an item, close the menu, then left click in the world to spawn it. E picks up or places objects. Right click throws the held object. Mouse wheel rotates what you are holding.\n\n"
		+ "[b]Interaction[/b]\n"
		+ "F uses nearby interactive objects. Benches can be sat on, blankets can be used for resting, buoyant objects float in water, and heavy props react to impacts.\n\n"
		+ "[b]Tools[/b]\n"
		+ "Weld Tool locks two nearby objects together. Float Tool toggles buoyancy. Motor Tool adds engine power. Driver Tool lets you control a motorized object with WASD.\n\n"
		+ "[b]Console[/b]\n"
		+ "~ opens the console. Use weather rain, weather clear, time 18:30, time lock 18:30, time unlock, timescale 2, noclip, fly, or spawn Cube.\n\n"
		+ "[b]NPC Brain[/b]\n"
		+ "The NPC can speak, inspect builds, walk to remembered places, collect objects, sit, rest, swim, and use sandbox tools. If the online provider fails, it retries quietly and keeps the world playable.\n\n"
		+ "[b]Audio And Atmosphere[/b]\n"
		+ "The menu plays a random looped track, the world has forest ambience, and props use material sounds for water, wood, metal, concrete, glass, and stone."
	)

func _start_game() -> void:
	_save_settings()
	GameState.set_menu_open(false)
	get_tree().change_scene_to_file(GAME_SCENE)

func _start_offline() -> void:
	if settings_tabs:
		settings_tabs.set_ai_enabled(false)
	_save_settings()
	GameState.set_menu_open(false)
	get_tree().change_scene_to_file(GAME_SCENE)

func _quit_game() -> void:
	get_tree().quit()
