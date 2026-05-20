extends CanvasLayer

const LIQUID_GLASS := preload("res://scripts/LiquidGlass.gd")
const SETTINGS_TABS := preload("res://scripts/SettingsTabsPanel.gd")
const MAIN_MENU_SCENE := "res://scenes/Main menu/node_3d.tscn"

var main_panel: PanelContainer
var settings_panel: PanelContainer
var settings_tabs
var ai_toggle: Button
var status_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	_build()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") and not GameState.api_dialog_open and not GameState.chat_open and not GameState.console_open:
		if visible and settings_panel and settings_panel.visible:
			_show_home()
			get_viewport().set_input_as_handled()
			return
		if not visible and GameState.menu_open:
			var spawn_menu := get_tree().current_scene.get_node_or_null("SpawnMenu")
			if spawn_menu and spawn_menu.has_method("close_menu"):
				spawn_menu.close_menu()
				get_viewport().set_input_as_handled()
				return
		toggle_pause()

func toggle_pause() -> void:
	visible = not visible
	get_tree().paused = visible
	GameState.set_pause_open(visible)
	if visible:
		_show_home()
		_update_home_status()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var wash := ColorRect.new()
	wash.color = Color(0.01, 0.015, 0.025, 0.62)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wash)

	main_panel = _base_panel(Vector2(460, 430))
	root.add_child(main_panel)
	_build_home_panel()

	settings_panel = _base_panel(Vector2(780, 660))
	settings_panel.visible = false
	root.add_child(settings_panel)
	_build_settings_panel()

func _base_panel(size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -size.x * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_bottom = size.y * 0.5
	panel.add_theme_stylebox_override("panel", LIQUID_GLASS.panel(1.14, 8))
	return panel

func _build_home_panel() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	main_panel.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	LIQUID_GLASS.apply_title(title, 32)
	box.add_child(title)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 36)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_stylebox_override("normal", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT))
	LIQUID_GLASS.apply_label(status_label)
	box.add_child(status_label)

	box.add_child(LIQUID_GLASS.divider())
	box.add_child(_button("Resume", toggle_pause, true))
	box.add_child(_button("Settings", _show_settings))
	ai_toggle = _switch_button("AI Brain", GameState.ai_brain_enabled)
	box.add_child(ai_toggle)
	box.add_child(_button("Main Menu", _return_to_menu))

func _build_settings_panel() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	settings_panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)

	var title := Label.new()
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	LIQUID_GLASS.apply_title(title, 30)
	title_row.add_child(title)

	var back := _button("Back", _show_home)
	back.custom_minimum_size = Vector2(92, 42)
	title_row.add_child(back)

	settings_tabs = SETTINGS_TABS.new()
	settings_tabs.setup()
	settings_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(settings_tabs)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	box.add_child(bottom)

	var save := _button("Save", _save_settings, true)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(save)

	var menu := _button("Main Menu", _return_to_menu)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(menu)

func _show_home() -> void:
	if settings_panel:
		settings_panel.visible = false
	if main_panel:
		main_panel.visible = true
	_update_home_status()

func _show_settings() -> void:
	if settings_tabs:
		settings_tabs.load_from_state()
	main_panel.visible = false
	settings_panel.visible = true

func _save_settings() -> void:
	if settings_tabs:
		settings_tabs.save_to_state()
	_update_home_status()

func _toggle_ai(value: bool) -> void:
	GameState.set_ai_brain_enabled(value)
	_update_ai_toggle()
	_update_home_status()

func _update_home_status() -> void:
	_update_ai_toggle()
	if not status_label:
		return
	status_label.text = "AI %s  |  %s  |  %.0f%% volume" % [
		"ON" if GameState.ai_brain_enabled else "OFF",
		GameState.graphics_quality.capitalize(),
		GameState.audio_master_volume * 100.0
	]

func _update_ai_toggle() -> void:
	if not ai_toggle:
		return
	ai_toggle.set_pressed_no_signal(GameState.ai_brain_enabled)
	_update_switch_text(ai_toggle, "AI Brain", ai_toggle.button_pressed)

func _return_to_menu() -> void:
	get_tree().paused = false
	visible = false
	GameState.set_pause_open(false)
	GameState.set_menu_open(false)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _button(text: String, target: Callable, accent := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	LIQUID_GLASS.apply_button(button, accent)
	button.pressed.connect(target)
	return button

func _switch_button(label: String, pressed: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = pressed
	button.custom_minimum_size = Vector2(0, 48)
	LIQUID_GLASS.apply_button(button)
	button.toggled.connect(_toggle_ai)
	_update_switch_text(button, label, pressed)
	return button

func _update_switch_text(button: Button, label: String, pressed: bool) -> void:
	button.text = "%s %s" % [label, "ON" if pressed else "OFF"]
