extends VBoxContainer

class_name AISettingsPanel

const LIQUID_GLASS := preload("res://scripts/LiquidGlass.gd")

var provider_options: OptionButton
var endpoint_edit: LineEdit
var key_edit: LineEdit
var brain_toggle: Button
var status_label: Label
var built := false

func setup() -> void:
	if built:
		return
	built = true
	add_theme_constant_override("separation", 12)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 34)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_stylebox_override("normal", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT))
	LIQUID_GLASS.apply_label(status_label)
	add_child(status_label)
	brain_toggle = _switch_button("AI Brain", true)
	add_child(brain_toggle)
	provider_options = OptionButton.new()
	var providers: PackedStringArray = GameState.provider_names()
	for provider_index in range(providers.size()):
		provider_options.add_item(providers[provider_index])
	LIQUID_GLASS.apply_option_button(provider_options)
	add_child(_labeled_control("Provider", provider_options))
	endpoint_edit = _field("AI endpoint")
	add_child(_labeled_control("Endpoint", endpoint_edit))
	key_edit = _field("AI provider key")
	key_edit.secret = true
	add_child(_labeled_control("Key", key_edit))
	provider_options.item_selected.connect(_provider_changed)
	load_from_state()

func load_from_state() -> void:
	if not built:
		setup()
	var providers: PackedStringArray = GameState.provider_names()
	provider_options.selected = max(0, providers.find(GameState.brain_provider))
	endpoint_edit.text = GameState.brain_base_url
	key_edit.text = GameState.api_key
	brain_toggle.set_pressed_no_signal(GameState.ai_brain_enabled)
	_update_switch_text(brain_toggle, "AI Brain", brain_toggle.button_pressed)
	_update_status()

func save_to_state() -> void:
	var selected: int = max(0, provider_options.selected)
	var provider := provider_options.get_item_text(selected)
	GameState.ai_brain_enabled = brain_toggle.button_pressed
	GameState.save_brain_config(provider, key_edit.text, GameState.default_model(provider), endpoint_edit.text)
	_update_status()

func set_ai_enabled(value: bool) -> void:
	if not built:
		setup()
	brain_toggle.set_pressed_no_signal(value)
	_update_switch_text(brain_toggle, "AI Brain", value)
	_update_status()

func _provider_changed(index: int) -> void:
	var provider := provider_options.get_item_text(index)
	endpoint_edit.text = GameState.default_base_url(provider)
	key_edit.placeholder_text = "Optional local key" if provider == "ollama" or provider == "lmstudio" else "AI provider key"
	_update_status()

func _update_status() -> void:
	if not brain_toggle.button_pressed:
		status_label.text = "Offline mode"
		status_label.add_theme_stylebox_override("normal", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT_WARM))
		return
	var selected: int = max(0, provider_options.selected)
	var provider := provider_options.get_item_text(selected)
	var needs_key := provider != "ollama" and provider != "lmstudio"
	if needs_key and key_edit.text.strip_edges() == "":
		status_label.text = "API key required"
		status_label.add_theme_stylebox_override("normal", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT_WARM))
	else:
		status_label.text = "Ready via %s" % provider.capitalize()
		status_label.add_theme_stylebox_override("normal", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT))

func _switch_button(label: String, pressed: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = pressed
	button.custom_minimum_size = Vector2(0, 42)
	LIQUID_GLASS.apply_button(button)
	button.toggled.connect(func(value: bool) -> void:
		_update_switch_text(button, label, value)
		_update_status()
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
	label.custom_minimum_size = Vector2(86, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	LIQUID_GLASS.apply_muted_label(label)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row
