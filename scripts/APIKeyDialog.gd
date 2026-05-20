extends AcceptDialog

const LIQUID_GLASS := preload("res://scripts/LiquidGlass.gd")

var line_edit: LineEdit
var provider_options: OptionButton
var base_url_edit: LineEdit

func _ready() -> void:
	title = "AI Sandbox NPC Brain"
	get_ok_button().visible = false

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", LIQUID_GLASS.panel(1.04, 8))
	add_child(panel)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(580, 340)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var label := Label.new()
	label.text = "Connect an AI provider for the NPC brain"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	LIQUID_GLASS.apply_title(label, 22)
	box.add_child(label)

	var note := Label.new()
	note.text = "Local providers can run without a key. Cloud providers need a saved API key."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	LIQUID_GLASS.apply_muted_label(note)
	box.add_child(note)

	provider_options = OptionButton.new()
	for provider in GameState.provider_names():
		provider_options.add_item(provider)
	provider_options.selected = max(0, GameState.provider_names().find(GameState.brain_provider))
	LIQUID_GLASS.apply_option_button(provider_options)
	box.add_child(provider_options)

	base_url_edit = _field("Endpoint", GameState.brain_base_url)
	box.add_child(base_url_edit)

	line_edit = _field("API key, not needed for Ollama or LM Studio", GameState.api_key)
	line_edit.secret = true
	box.add_child(line_edit)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	var offline := Button.new()
	offline.text = "Play Offline"
	offline.custom_minimum_size = Vector2(138, 42)
	LIQUID_GLASS.apply_button(offline)
	buttons.add_child(offline)

	var save := Button.new()
	save.text = "Save & Continue"
	save.custom_minimum_size = Vector2(170, 42)
	LIQUID_GLASS.apply_button(save, true)
	buttons.add_child(save)

	offline.pressed.connect(_play_offline)
	save.pressed.connect(_save_key)
	provider_options.item_selected.connect(_provider_changed)
	line_edit.text_submitted.connect(func(_text: String) -> void:
		_save_key()
	)
	confirmed.connect(_save_key)
	close_requested.connect(func() -> void:
		GameState.set_api_dialog_open(false)
	)
	visibility_changed.connect(func() -> void:
		GameState.set_api_dialog_open(visible)
	)
	if GameState.ai_brain_enabled and not GameState.is_brain_configured():
		call_deferred("_show_dialog")

func _show_dialog() -> void:
	GameState.set_api_dialog_open(true)
	popup_centered(Vector2i(640, 400))
	line_edit.grab_focus()

func _save_key() -> void:
	var provider := provider_options.get_item_text(max(0, provider_options.selected))
	var key := line_edit.text.strip_edges()
	GameState.ai_brain_enabled = true
	GameState.save_brain_config(provider, key, GameState.default_model(provider), base_url_edit.text)
	hide()
	GameState.set_api_dialog_open(false)

func _play_offline() -> void:
	var provider := provider_options.get_item_text(max(0, provider_options.selected))
	GameState.ai_brain_enabled = false
	GameState.save_brain_config(provider, line_edit.text, GameState.default_model(provider), base_url_edit.text)
	hide()
	GameState.set_api_dialog_open(false)

func _provider_changed(index: int) -> void:
	var provider := provider_options.get_item_text(index)
	base_url_edit.text = GameState.default_base_url(provider)
	line_edit.placeholder_text = "Optional local key" if provider == "ollama" or provider == "lmstudio" else "API key"

func _field(placeholder: String, text_value: String) -> LineEdit:
	var field := LineEdit.new()
	field.text = text_value
	field.placeholder_text = placeholder
	LIQUID_GLASS.apply_line_edit(field)
	return field
