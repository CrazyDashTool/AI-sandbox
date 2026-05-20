extends VBoxContainer

class_name SettingsTabsPanel

const LIQUID_GLASS := preload("res://scripts/LiquidGlass.gd")
const GRAPHICS_SETTINGS := preload("res://scripts/GraphicsSettingsPanel.gd")
const AUDIO_SETTINGS := preload("res://scripts/AudioSettingsPanel.gd")
const AI_SETTINGS := preload("res://scripts/AISettingsPanel.gd")

var tabs: TabContainer
var graphics_settings
var audio_settings
var ai_settings
var built := false

func setup() -> void:
	if built:
		return
	built = true
	add_theme_constant_override("separation", 10)
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	graphics_settings = GRAPHICS_SETTINGS.new()
	_add_tab("Video", graphics_settings)
	audio_settings = AUDIO_SETTINGS.new()
	_add_tab("Audio", audio_settings)
	ai_settings = AI_SETTINGS.new()
	_add_tab("AI", ai_settings)
	load_from_state()

func load_from_state() -> void:
	if not built:
		setup()
	graphics_settings.load_from_state()
	audio_settings.load_from_state()
	ai_settings.load_from_state()

func save_to_state() -> void:
	graphics_settings.save_to_state()
	audio_settings.save_to_state()
	ai_settings.save_to_state()

func set_ai_enabled(value: bool) -> void:
	if not built:
		setup()
	ai_settings.set_ai_enabled(value)

func _add_tab(tab_name: String, content: Control) -> void:
	var margin := MarginContainer.new()
	margin.name = tab_name
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.call("setup")
	margin.add_child(content)
	tabs.add_child(margin)
