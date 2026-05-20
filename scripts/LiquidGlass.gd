extends RefCounted

class_name LiquidGlass

const TEXT := Color(0.94, 0.97, 1.0)
const TEXT_MUTED := Color(0.72, 0.82, 0.9)
const ACCENT := Color(0.15, 0.78, 0.76)
const ACCENT_WARM := Color(1.0, 0.58, 0.28)
const SURFACE := Color(0.035, 0.05, 0.075)

static func panel(strength := 0.7, radius := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(SURFACE.r, SURFACE.g, SURFACE.b, 0.62 * strength)
	box.border_color = Color(0.74, 0.86, 0.96, 0.22 * strength)
	box.set_border_width_all(1)
	box.set_corner_radius_all(min(radius, 8))
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	box.shadow_size = 22
	box.shadow_offset = Vector2(0, 10)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box

static func surface(strength := 0.55, radius := 8) -> StyleBoxFlat:
	var box := panel(strength, radius)
	box.bg_color = Color(0.07, 0.09, 0.12, 0.52 * strength)
	box.border_color = Color(0.88, 0.95, 1.0, 0.12 * strength)
	box.shadow_size = 8
	box.shadow_offset = Vector2.ZERO
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

static func button(selected := false, accent := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if accent:
		box.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.44 if selected else 0.28)
		box.border_color = Color(0.68, 1.0, 0.96, 0.78 if selected else 0.42)
	else:
		box.bg_color = Color(0.14, 0.18, 0.23, 0.72 if selected else 0.48)
		box.border_color = Color(0.78, 0.9, 1.0, 0.32 if selected else 0.16)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	box.shadow_size = 6
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func line() -> StyleBoxFlat:
	var box := surface(0.85, 8)
	box.bg_color = Color(0.08, 0.11, 0.15, 0.78)
	box.border_color = Color(0.76, 0.88, 1.0, 0.2)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func chip(color := ACCENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color.r, color.g, color.b, 0.16)
	box.border_color = Color(color.r, color.g, color.b, 0.48)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

static func swatch(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(1.0, 1.0, 1.0, 0.32)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	return box

static func apply_button(button_node: Button, accent := false) -> void:
	button_node.add_theme_stylebox_override("normal", button(false, accent))
	button_node.add_theme_stylebox_override("hover", button(true, accent))
	button_node.add_theme_stylebox_override("pressed", button(true, accent))
	button_node.add_theme_stylebox_override("checked", button(true, accent))
	button_node.add_theme_stylebox_override("focus", button(true, accent))
	button_node.add_theme_stylebox_override("disabled", button(false, accent))
	button_node.add_theme_color_override("font_color", TEXT)
	button_node.add_theme_color_override("font_hover_color", Color.WHITE)
	button_node.add_theme_color_override("font_pressed_color", Color.WHITE)
	button_node.add_theme_color_override("font_focus_color", Color.WHITE)
	button_node.add_theme_color_override("font_disabled_color", Color(TEXT.r, TEXT.g, TEXT.b, 0.52))
	button_node.add_theme_font_size_override("font_size", 15)
	var sound_callable := Callable(LiquidGlass, "_play_button_sound")
	if not button_node.pressed.is_connected(sound_callable):
		button_node.pressed.connect(sound_callable)

static func apply_option_button(option_node: OptionButton) -> void:
	apply_button(option_node)
	option_node.custom_minimum_size = Vector2(0, 42)
	option_node.add_theme_color_override("arrow_color", TEXT_MUTED)
	var popup := option_node.get_popup()
	if popup:
		popup.add_theme_stylebox_override("panel", panel(1.05, 8))
		popup.add_theme_color_override("font_color", TEXT)
		popup.add_theme_color_override("font_hover_color", Color.WHITE)
		popup.add_theme_color_override("font_accelerator_color", TEXT_MUTED)
		popup.add_theme_color_override("font_separator_color", TEXT_MUTED)

static func apply_line_edit(field: LineEdit) -> void:
	field.custom_minimum_size = Vector2(0, 42)
	field.add_theme_stylebox_override("normal", line())
	field.add_theme_stylebox_override("focus", line())
	field.add_theme_stylebox_override("read_only", line())
	field.add_theme_color_override("font_color", TEXT)
	field.add_theme_color_override("font_selected_color", Color.WHITE)
	field.add_theme_color_override("selection_color", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.36))
	field.add_theme_color_override("placeholder_color", Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, 0.78))
	field.add_theme_font_size_override("font_size", 15)

static func apply_label(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)

static func apply_muted_label(label: Label) -> void:
	apply_label(label)
	label.add_theme_color_override("font_color", TEXT_MUTED)

static func apply_title(label: Label, size := 30) -> void:
	apply_label(label)
	label.add_theme_font_size_override("font_size", size)

static func apply_rich_text(label: RichTextLabel) -> void:
	label.add_theme_color_override("default_color", TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_font_size_override("bold_font_size", 15)
	label.add_theme_constant_override("line_separation", 4)

static func divider() -> ColorRect:
	var line_node := ColorRect.new()
	line_node.custom_minimum_size = Vector2(0, 1)
	line_node.color = Color(0.78, 0.9, 1.0, 0.16)
	return line_node

static func _play_button_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return
	var stream := load("res://Sounds/Button.mp3")
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = -8.0
	tree.root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
