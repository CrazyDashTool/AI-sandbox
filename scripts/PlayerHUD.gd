extends CanvasLayer

class_name PlayerHUD

const LIQUID_GLASS := preload("res://scripts/LiquidGlass.gd")

var holding_label: Label
var fps_label: Label
var camera_label: Label
var step_pulse: ColorRect

var chat_panel: PanelContainer
var chat_compact: HBoxContainer
var chat_window: VBoxContainer
var compact_badge_panel: PanelContainer
var compact_badge_label: Label
var compact_status_label: Label
var chat_header_status_label: Label
var chat_scroll: ScrollContainer
var chat_messages: VBoxContainer
var typing_label: Label
var chat_input: LineEdit
var chat_tween: Tween

var chat_is_open := false
var latest_npc_speech := ""
var latest_npc_emotion := "neutral"
var npc_thinking := false
var last_message_signature := ""

func _ready() -> void:
	layer = 3
	_build()
	_connect_game_state()
	latest_npc_speech = GameState.last_npc_speech
	latest_npc_emotion = GameState.last_npc_emotion
	npc_thinking = GameState.npc_thinking
	_refresh_chat_state()

func _unhandled_input(event: InputEvent) -> void:
	if chat_is_open and event.is_action_pressed("pause_menu"):
		_close_chat()
		get_viewport().set_input_as_handled()

func update_status(held_name: String) -> void:
	holding_label.text = "Holding: %s" % held_name if held_name != "" else ""
	holding_label.visible = held_name != ""

	fps_label.text = "FPS %d" % Engine.get_frames_per_second()

	var npc := get_tree().get_first_node_in_group("npc")
	if npc:
		if npc.has_method("get_emotion_text"):
			latest_npc_emotion = str(npc.get_emotion_text())
		if npc.has_method("get_last_speech"):
			var polled_speech := str(npc.get_last_speech()).strip_edges()
			if polled_speech != "" and polled_speech != latest_npc_speech:
				_on_npc_spoke(polled_speech, latest_npc_emotion)
	_refresh_chat_state()

func flash_step() -> void:
	step_pulse.modulate.a = 0.55
	create_tween().tween_property(step_pulse, "modulate:a", 0.0, 0.18)

func open_chat() -> void:
	_set_chat_open(true)

func set_npc_camera_view(active: bool) -> void:
	if not camera_label:
		return
	camera_label.visible = active
	camera_label.text = "NPC camera view  P to return"

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_crosshair(root)

	holding_label = _label(root, Vector2(18, -58), Vector2(0, 1))
	holding_label.visible = false

	fps_label = _label(root, Vector2(-128, 14), Vector2(1, 0), HORIZONTAL_ALIGNMENT_RIGHT)
	fps_label.visible = false

	camera_label = _label(root, Vector2(-190, 54), Vector2(1, 0), HORIZONTAL_ALIGNMENT_RIGHT)
	camera_label.visible = false

	step_pulse = ColorRect.new()
	step_pulse.color = Color(LIQUID_GLASS.ACCENT.r, LIQUID_GLASS.ACCENT.g, LIQUID_GLASS.ACCENT.b, 1.0)
	step_pulse.anchor_left = 0.5
	step_pulse.anchor_right = 0.5
	step_pulse.anchor_top = 1.0
	step_pulse.anchor_bottom = 1.0
	step_pulse.offset_left = -34
	step_pulse.offset_right = 34
	step_pulse.offset_top = -78
	step_pulse.offset_bottom = -75
	step_pulse.modulate.a = 0.0
	step_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(step_pulse)

	_build_chat_panel(root)

func _connect_game_state() -> void:
	var spoke_callable := Callable(self, "_on_npc_spoke")
	if not GameState.npc_spoke.is_connected(spoke_callable):
		GameState.npc_spoke.connect(spoke_callable)
	var thinking_callable := Callable(self, "_on_npc_thinking_changed")
	if not GameState.npc_thinking_changed.is_connected(thinking_callable):
		GameState.npc_thinking_changed.connect(thinking_callable)

func _build_chat_panel(root: Control) -> void:
	chat_panel = PanelContainer.new()
	chat_panel.name = "NPCChatPanel"
	chat_panel.visible = false
	chat_panel.modulate.a = 0.0
	chat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_panel.add_theme_stylebox_override("panel", LIQUID_GLASS.panel(1.08, 8))
	_set_chat_offsets(false)
	root.add_child(chat_panel)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	chat_panel.add_child(shell)

	chat_compact = HBoxContainer.new()
	chat_compact.add_theme_constant_override("separation", 10)
	shell.add_child(chat_compact)

	compact_badge_panel = PanelContainer.new()
	compact_badge_panel.custom_minimum_size = Vector2(82, 32)
	compact_badge_panel.add_theme_stylebox_override("panel", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT))
	chat_compact.add_child(compact_badge_panel)

	var badge_center := CenterContainer.new()
	compact_badge_panel.add_child(badge_center)
	compact_badge_label = Label.new()
	compact_badge_label.text = "NPC"
	compact_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compact_badge_label.add_theme_font_size_override("font_size", 13)
	LIQUID_GLASS.apply_label(compact_badge_label)
	badge_center.add_child(compact_badge_label)

	compact_status_label = Label.new()
	compact_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	compact_status_label.clip_text = true
	compact_status_label.add_theme_font_size_override("font_size", 15)
	LIQUID_GLASS.apply_label(compact_status_label)
	chat_compact.add_child(compact_status_label)

	var compact_hint := Label.new()
	compact_hint.text = "T"
	compact_hint.custom_minimum_size = Vector2(28, 32)
	compact_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compact_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	compact_hint.add_theme_stylebox_override("normal", LIQUID_GLASS.surface(0.92, 8))
	compact_hint.add_theme_font_size_override("font_size", 13)
	LIQUID_GLASS.apply_muted_label(compact_hint)
	chat_compact.add_child(compact_hint)

	chat_window = VBoxContainer.new()
	chat_window.visible = false
	chat_window.add_theme_constant_override("separation", 10)
	shell.add_child(chat_window)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	chat_window.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	var title := Label.new()
	title.text = "NPC Chat"
	LIQUID_GLASS.apply_title(title, 20)
	title_box.add_child(title)

	chat_header_status_label = Label.new()
	chat_header_status_label.text = "Ready"
	chat_header_status_label.add_theme_font_size_override("font_size", 13)
	LIQUID_GLASS.apply_muted_label(chat_header_status_label)
	title_box.add_child(chat_header_status_label)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(78, 38)
	LIQUID_GLASS.apply_button(close_button)
	close_button.pressed.connect(_close_chat)
	header.add_child(close_button)

	chat_scroll = ScrollContainer.new()
	chat_scroll.custom_minimum_size = Vector2(0, 126)
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_window.add_child(chat_scroll)

	chat_messages = VBoxContainer.new()
	chat_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_messages.add_theme_constant_override("separation", 8)
	chat_scroll.add_child(chat_messages)

	typing_label = Label.new()
	typing_label.visible = false
	typing_label.text = "NPC is thinking..."
	typing_label.add_theme_stylebox_override("normal", LIQUID_GLASS.surface(0.72, 8))
	typing_label.add_theme_font_size_override("font_size", 13)
	LIQUID_GLASS.apply_muted_label(typing_label)
	chat_window.add_child(typing_label)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 10)
	chat_window.add_child(input_row)

	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Message NPC"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	LIQUID_GLASS.apply_line_edit(chat_input)
	chat_input.text_submitted.connect(_on_chat_submit)
	input_row.add_child(chat_input)

	var send_button := Button.new()
	send_button.text = "Send"
	send_button.custom_minimum_size = Vector2(78, 42)
	LIQUID_GLASS.apply_button(send_button, true)
	send_button.pressed.connect(_submit_chat_from_input)
	input_row.add_child(send_button)

func _build_crosshair(root: Control) -> void:
	var center := Control.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -13
	center.offset_right = 13
	center.offset_top = -13
	center.offset_bottom = 13
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var color := Color(0.9, 1.0, 0.97, 0.84)
	var horizontal := ColorRect.new()
	horizontal.color = color
	horizontal.anchor_left = 0.5
	horizontal.anchor_right = 0.5
	horizontal.anchor_top = 0.5
	horizontal.anchor_bottom = 0.5
	horizontal.offset_left = -10
	horizontal.offset_right = 10
	horizontal.offset_top = -1
	horizontal.offset_bottom = 1
	horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(horizontal)

	var vertical := ColorRect.new()
	vertical.color = color
	vertical.anchor_left = 0.5
	vertical.anchor_right = 0.5
	vertical.anchor_top = 0.5
	vertical.anchor_bottom = 0.5
	vertical.offset_left = -1
	vertical.offset_right = 1
	vertical.offset_top = -10
	vertical.offset_bottom = 10
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vertical)

	var dot := ColorRect.new()
	dot.color = Color(LIQUID_GLASS.ACCENT.r, LIQUID_GLASS.ACCENT.g, LIQUID_GLASS.ACCENT.b, 0.95)
	dot.anchor_left = 0.5
	dot.anchor_right = 0.5
	dot.anchor_top = 0.5
	dot.anchor_bottom = 0.5
	dot.offset_left = -2
	dot.offset_right = 2
	dot.offset_top = -2
	dot.offset_bottom = 2
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(dot)

func _label(root: Control, pos: Vector2, anchor: Vector2, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = anchor.x
	label.anchor_right = anchor.x
	label.anchor_top = anchor.y
	label.anchor_bottom = anchor.y
	label.offset_left = pos.x
	label.offset_top = pos.y
	label.offset_right = pos.x + 360
	label.offset_bottom = pos.y + 38
	label.add_theme_stylebox_override("normal", LIQUID_GLASS.surface(0.78, 8))
	label.add_theme_font_size_override("font_size", 15)
	LIQUID_GLASS.apply_label(label)
	root.add_child(label)
	return label

func _set_chat_open(value: bool) -> void:
	if not chat_panel:
		return
	if chat_is_open == value:
		if value and chat_input:
			chat_input.grab_focus()
		return

	chat_is_open = value
	GameState.set_chat_open(value)

	if value:
		chat_panel.visible = true
		chat_compact.visible = false
		chat_window.visible = true
		_refresh_chat_state()
		_animate_chat_panel(true, false)
		chat_input.call_deferred("grab_focus")
	else:
		if chat_input:
			chat_input.release_focus()
		chat_window.visible = false
		chat_compact.visible = true
		_refresh_chat_state()
		_animate_chat_panel(false, not _has_compact_content())

func _set_chat_offsets(opened: bool) -> void:
	chat_panel.anchor_left = 0.5
	chat_panel.anchor_right = 0.5
	chat_panel.anchor_top = 1.0
	chat_panel.anchor_bottom = 1.0
	if opened:
		chat_panel.offset_left = -330
		chat_panel.offset_right = 330
		chat_panel.offset_top = -286
		chat_panel.offset_bottom = -20
	else:
		chat_panel.offset_left = -310
		chat_panel.offset_right = 310
		chat_panel.offset_top = -72
		chat_panel.offset_bottom = -20

func _animate_chat_panel(opened: bool, hide_when_done: bool) -> void:
	if chat_tween:
		chat_tween.kill()

	var target_left := -330 if opened else -310
	var target_right := 330 if opened else 310
	var target_top := -286 if opened else -72
	var target_bottom := -20
	var duration := 0.24 if opened else 0.2
	chat_panel.pivot_offset = Vector2((target_right - target_left) * 0.5, target_bottom - target_top)

	if opened and chat_panel.modulate.a <= 0.01:
		chat_panel.scale = Vector2(0.96, 0.96)
	if not opened and hide_when_done:
		chat_panel.scale = Vector2.ONE

	chat_tween = create_tween()
	chat_tween.set_parallel(true)
	chat_tween.tween_property(chat_panel, "offset_left", target_left, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	chat_tween.tween_property(chat_panel, "offset_right", target_right, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	chat_tween.tween_property(chat_panel, "offset_top", target_top, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	chat_tween.tween_property(chat_panel, "offset_bottom", target_bottom, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	chat_tween.tween_property(chat_panel, "scale", Vector2.ONE if opened or not hide_when_done else Vector2(0.96, 0.96), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	chat_tween.tween_property(chat_panel, "modulate:a", 1.0 if opened or not hide_when_done else 0.0, duration)
	if hide_when_done:
		chat_tween.chain().tween_callback(func() -> void:
			if not chat_is_open and not _has_compact_content():
				chat_panel.visible = false
		)

func _refresh_chat_state() -> void:
	if not chat_panel:
		return

	var has_content := _has_compact_content()
	var compact_text := "NPC is thinking..." if npc_thinking else latest_npc_speech
	compact_status_label.text = compact_text
	compact_badge_label.text = "..." if npc_thinking else _pretty_emotion(latest_npc_emotion)
	compact_badge_panel.add_theme_stylebox_override("panel", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT_WARM if npc_thinking else LIQUID_GLASS.ACCENT))

	if chat_header_status_label:
		chat_header_status_label.text = "Thinking..." if npc_thinking else ("Latest: %s" % _pretty_emotion(latest_npc_emotion) if latest_npc_speech != "" else "Ready")
	if typing_label:
		typing_label.visible = npc_thinking

	if not chat_is_open:
		chat_panel.visible = has_content
		if has_content and chat_panel.modulate.a <= 0.01:
			chat_compact.visible = true
			chat_window.visible = false
			_set_chat_offsets(false)
			chat_panel.scale = Vector2(0.97, 0.97)
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(chat_panel, "modulate:a", 1.0, 0.18)
			tween.tween_property(chat_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _has_compact_content() -> bool:
	return npc_thinking or latest_npc_speech.strip_edges() != ""

func _on_chat_submit(_text: String) -> void:
	_submit_chat_from_input()

func _submit_chat_from_input() -> void:
	var clean := chat_input.text.strip_edges()
	if clean == "":
		return
	chat_input.text = ""
	_append_message("You", clean, true)
	WorldContext.set_player_speech(clean)
	GameState.submit_chat(clean)
	chat_input.grab_focus()

func _close_chat() -> void:
	_set_chat_open(false)

func _on_npc_spoke(text: String, emotion_value: String) -> void:
	var clean := text.strip_edges()
	if clean == "":
		return
	latest_npc_speech = clean
	latest_npc_emotion = emotion_value if emotion_value.strip_edges() != "" else "neutral"
	npc_thinking = false
	var signature := "npc:%s" % clean
	if signature != last_message_signature:
		_append_message(_pretty_emotion(latest_npc_emotion), clean, false)
		last_message_signature = signature
	_refresh_chat_state()

func _on_npc_thinking_changed(active: bool) -> void:
	npc_thinking = active
	_refresh_chat_state()

func _append_message(author: String, text: String, from_player: bool) -> void:
	if not chat_messages:
		return

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var leading_spacer := Control.new()
	leading_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var trailing_spacer := Control.new()
	trailing_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", _message_style(from_player))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	bubble.add_child(box)

	var author_label := Label.new()
	author_label.text = author
	author_label.add_theme_font_size_override("font_size", 12)
	LIQUID_GLASS.apply_muted_label(author_label)
	box.add_child(author_label)

	var message_label := Label.new()
	message_label.text = text
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 14)
	LIQUID_GLASS.apply_label(message_label)
	box.add_child(message_label)

	if from_player:
		row.add_child(leading_spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(trailing_spacer)

	chat_messages.add_child(row)
	_trim_chat_messages()
	_pop_message(bubble)
	_scroll_chat_to_bottom()

func _message_style(from_player: bool) -> StyleBoxFlat:
	var box := LIQUID_GLASS.surface(0.88, 8)
	if from_player:
		box.bg_color = Color(LIQUID_GLASS.ACCENT.r, LIQUID_GLASS.ACCENT.g, LIQUID_GLASS.ACCENT.b, 0.18)
		box.border_color = Color(0.68, 1.0, 0.96, 0.28)
	else:
		box.bg_color = Color(0.075, 0.095, 0.13, 0.76)
		box.border_color = Color(0.9, 0.96, 1.0, 0.16)
	return box

func _trim_chat_messages() -> void:
	while chat_messages.get_child_count() > 18:
		var child := chat_messages.get_child(0)
		chat_messages.remove_child(child)
		child.queue_free()

func _pop_message(control: Control) -> void:
	control.modulate.a = 0.0
	control.scale = Vector2(0.98, 0.98)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.18)
	tween.tween_property(control, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _scroll_chat_to_bottom() -> void:
	await get_tree().process_frame
	if chat_scroll and chat_scroll.get_v_scroll_bar():
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)

func _pretty_emotion(value: String) -> String:
	var clean := value.strip_edges()
	if clean == "":
		return "NPC"
	return clean.capitalize()
