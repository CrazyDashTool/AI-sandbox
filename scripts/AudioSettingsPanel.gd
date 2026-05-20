extends VBoxContainer

class_name AudioSettingsPanel

const LIQUID_GLASS := preload("res://scripts/LiquidGlass.gd")

var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var ambient_slider: HSlider
var mute_toggle: Button
var built := false

func setup() -> void:
	if built:
		return
	built = true
	add_theme_constant_override("separation", 12)
	mute_toggle = _switch_button("Mute", false)
	add_child(mute_toggle)
	master_slider = _add_slider("Master")
	music_slider = _add_slider("Music")
	sfx_slider = _add_slider("Effects")
	ambient_slider = _add_slider("Ambient")
	load_from_state()

func load_from_state() -> void:
	if not built:
		setup()
	master_slider.value = GameState.audio_master_volume * 100.0
	music_slider.value = GameState.audio_music_volume * 100.0
	sfx_slider.value = GameState.audio_sfx_volume * 100.0
	ambient_slider.value = GameState.audio_ambient_volume * 100.0
	mute_toggle.set_pressed_no_signal(GameState.audio_muted)
	_update_switch_text(mute_toggle, "Mute", mute_toggle.button_pressed)

func save_to_state() -> void:
	GameState.save_audio_settings(
		float(master_slider.value) / 100.0,
		float(music_slider.value) / 100.0,
		float(sfx_slider.value) / 100.0,
		float(ambient_slider.value) / 100.0,
		mute_toggle.button_pressed
	)

func _add_slider(label_text: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(92, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	LIQUID_GLASS.apply_muted_label(label)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(46, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	LIQUID_GLASS.apply_label(value_label)
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(round(value))
	)
	value_label.text = "%d%%" % int(round(slider.value))
	return slider

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
