extends VBoxContainer

class_name GraphicsSettingsPanel

const LIQUID_GLASS := preload("res://scripts/LiquidGlass.gd")

var resolution_options: OptionButton
var mode_options: OptionButton
var quality_options: OptionButton
var fps_options: OptionButton
var vsync_toggle: Button
var built := false

func setup() -> void:
	if built:
		return
	built = true
	add_theme_constant_override("separation", 10)
	add_child(_section_title("Display"))
	resolution_options = OptionButton.new()
	for resolution_index in range(GameState.resolution_options().size()):
		var resolution: Vector2i = GameState.resolution_options()[resolution_index]
		resolution_options.add_item("%dx%d" % [resolution.x, resolution.y])
		resolution_options.set_item_metadata(resolution_index, resolution)
	LIQUID_GLASS.apply_option_button(resolution_options)
	add_child(_labeled_control("Resolution", resolution_options))
	mode_options = OptionButton.new()
	for mode_index in range(GameState.display_mode_names().size()):
		var mode: String = GameState.display_mode_names()[mode_index]
		mode_options.add_item(_mode_label(mode))
		mode_options.set_item_metadata(mode_index, mode)
	LIQUID_GLASS.apply_option_button(mode_options)
	add_child(_labeled_control("Window", mode_options))
	vsync_toggle = _switch_button("VSync", true)
	add_child(vsync_toggle)
	add_child(LIQUID_GLASS.divider())
	add_child(_section_title("Graphics"))
	quality_options = OptionButton.new()
	for quality_index in range(GameState.quality_names().size()):
		var quality: String = GameState.quality_names()[quality_index]
		quality_options.add_item(quality.capitalize())
		quality_options.set_item_metadata(quality_index, quality)
	LIQUID_GLASS.apply_option_button(quality_options)
	add_child(_labeled_control("Quality", quality_options))
	fps_options = OptionButton.new()
	for fps_index in range(GameState.fps_limit_options().size()):
		var limit: int = GameState.fps_limit_options()[fps_index]
		fps_options.add_item("Unlimited" if limit == 0 else "%d FPS" % limit)
		fps_options.set_item_metadata(fps_index, limit)
	LIQUID_GLASS.apply_option_button(fps_options)
	add_child(_labeled_control("FPS Cap", fps_options))
	load_from_state()

func load_from_state() -> void:
	if not built:
		setup()
	_select_resolution(GameState.display_resolution)
	_select_metadata(mode_options, GameState.display_mode)
	_select_metadata(quality_options, GameState.graphics_quality)
	_select_metadata(fps_options, GameState.fps_limit)
	vsync_toggle.set_pressed_no_signal(GameState.vsync_enabled)
	_update_switch_text(vsync_toggle, "VSync", vsync_toggle.button_pressed)

func save_to_state() -> void:
	var resolution: Vector2i = resolution_options.get_item_metadata(max(0, resolution_options.selected))
	var mode: String = str(mode_options.get_item_metadata(max(0, mode_options.selected)))
	var quality: String = str(quality_options.get_item_metadata(max(0, quality_options.selected)))
	var max_fps: int = int(fps_options.get_item_metadata(max(0, fps_options.selected)))
	GameState.save_game_settings(resolution, mode, quality, vsync_toggle.button_pressed, max_fps)

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	LIQUID_GLASS.apply_title(label, 18)
	return label

func _switch_button(label: String, pressed: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = pressed
	button.custom_minimum_size = Vector2(0, 42)
	LIQUID_GLASS.apply_button(button)
	button.toggled.connect(func(value: bool) -> void:
		_update_switch_text(button, label, value)
	)
	_update_switch_text(button, label, pressed)
	return button

func _update_switch_text(button: Button, label: String, pressed: bool) -> void:
	button.text = "%s %s" % [label, "ON" if pressed else "OFF"]

func _labeled_control(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(96, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	LIQUID_GLASS.apply_muted_label(label)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _select_resolution(value: Vector2i) -> void:
	var best_index := 0
	for index in range(resolution_options.item_count):
		var option: Vector2i = resolution_options.get_item_metadata(index)
		if option == value:
			best_index = index
			break
	resolution_options.selected = best_index

func _select_metadata(options: OptionButton, value: Variant) -> void:
	for index in range(options.item_count):
		if options.get_item_metadata(index) == value:
			options.selected = index
			return
	options.selected = 0

func _mode_label(value: String) -> String:
	match value:
		"fullscreen":
			return "Fullscreen"
		"exclusive_fullscreen":
			return "Exclusive"
	return "Windowed"
