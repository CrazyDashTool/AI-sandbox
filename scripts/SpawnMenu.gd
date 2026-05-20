extends CanvasLayer

const LIQUID_GLASS := preload("res://scripts/LiquidGlass.gd")
const PROP_CATALOG := preload("res://scripts/PropCatalog.gd")

var categories := {
	"Basics": ["Cube", "Ball", "Cone", "Board", "Wall", "Rock"],
	"Furniture": ["Chair", "Table", "Bench", "Crate", "Barrel", "Lamp"],
	"Nature": ["Tree", "Bush", "Beach Blanket"],
	"Fun": ["Gemma Token", "Balloon", "Wheel"],
	"Tools": ["Weld Tool", "Float Tool", "Motor Tool", "Driver Tool"],
	"Weapons": ["Metal pipe"]
}

var selected_label: Label
var search_edit: LineEdit
var buttons: Array[Button] = []
var item_rows: Array[Control] = []

func _ready() -> void:
	layer = 4
	visible = false
	_merge_asset_items()
	_build_menu()
	GameState.selected_spawn_changed.connect(_on_selected_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spawn_menu") and not GameState.chat_open and not GameState.api_dialog_open and not GameState.pause_open:
		_toggle()
	elif visible and event.is_action_pressed("pause_menu"):
		close_menu()
		get_viewport().set_input_as_handled()

func close_menu() -> void:
	visible = false
	GameState.set_menu_open(false)

func open_menu() -> void:
	visible = true
	GameState.set_menu_open(true)

func _toggle() -> void:
	if visible:
		close_menu()
	else:
		open_menu()

func _build_menu() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var wash := ColorRect.new()
	wash.color = Color(0.01, 0.015, 0.025, 0.34)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wash)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.02
	panel.anchor_right = 0.43
	panel.anchor_top = 0.035
	panel.anchor_bottom = 0.965
	panel.add_theme_stylebox_override("panel", LIQUID_GLASS.panel(1.04, 8))
	root.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)

	var title := Label.new()
	title.text = "Spawn Menu"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	LIQUID_GLASS.apply_title(title, 24)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(76, 36)
	LIQUID_GLASS.apply_button(close_button)
	close_button.pressed.connect(close_menu)
	header.add_child(close_button)

	selected_label = Label.new()
	selected_label.text = "Selected: none"
	selected_label.custom_minimum_size = Vector2(0, 34)
	selected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_label.add_theme_stylebox_override("normal", LIQUID_GLASS.chip(LIQUID_GLASS.ACCENT))
	LIQUID_GLASS.apply_label(selected_label)
	layout.add_child(selected_label)

	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Search props and tools"
	LIQUID_GLASS.apply_line_edit(search_edit)
	search_edit.text_changed.connect(_filter_items)
	layout.add_child(search_edit)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", LIQUID_GLASS.surface(0.75, 8))
	layout.add_child(tabs)

	for category in categories.keys():
		var scroll := ScrollContainer.new()
		scroll.name = category
		tabs.add_child(scroll)

		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 7)
		scroll.add_child(list)

		for item in categories[category]:
			list.add_child(_item_row(category, item))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	layout.add_child(footer)

	var clear := Button.new()
	clear.text = "Clear Selection"
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	LIQUID_GLASS.apply_button(clear)
	clear.pressed.connect(GameState.clear_selected_spawn_item)
	footer.add_child(clear)

func _item_row(category: String, item: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 42)
	row.add_theme_constant_override("separation", 10)
	row.set_meta("type_name", item)
	row.set_meta("display_name", PROP_CATALOG.display_name(item))
	row.set_meta("category", category)

	var swatch := PanelContainer.new()
	swatch.custom_minimum_size = Vector2(28, 28)
	swatch.add_theme_stylebox_override("panel", LIQUID_GLASS.swatch(_color_for(item)))
	row.add_child(swatch)

	var button := Button.new()
	button.text = PROP_CATALOG.display_name(item)
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.set_meta("type_name", item)
	LIQUID_GLASS.apply_button(button)
	button.pressed.connect(func() -> void:
		GameState.set_selected_spawn_item({"category": category, "type": item})
	)
	row.add_child(button)

	buttons.append(button)
	item_rows.append(row)
	return row

func _filter_items(query: String) -> void:
	var clean := query.strip_edges().to_lower()
	for row in item_rows:
		var display_name := str(row.get_meta("display_name", "")).to_lower()
		var category := str(row.get_meta("category", "")).to_lower()
		row.visible = clean == "" or display_name.find(clean) >= 0 or category.find(clean) >= 0

func _on_selected_changed(item: Dictionary) -> void:
	var selected_type := str(item.get("type", ""))
	for button in buttons:
		button.button_pressed = selected_type != "" and str(button.get_meta("type_name", "")) == selected_type
	selected_label.text = "Selected: %s" % (PROP_CATALOG.display_name(selected_type) if selected_type != "" else "none")

func _color_for(item: String) -> Color:
	var hue := float(abs(item.hash()) % 1000) / 1000.0
	return Color.from_hsv(hue, 0.48, 0.92)

func _merge_asset_items() -> void:
	var defs := PROP_CATALOG.definitions()
	var assets: Array[String] = []
	for item in defs.keys():
		var def: Dictionary = defs[item]
		if def.has("scene") and not _has_category_item(str(item)):
			assets.append(str(item))
	assets.sort()
	if not assets.is_empty():
		categories["Assets"] = assets

func _has_category_item(item: String) -> bool:
	for list in categories.values():
		if list.has(item):
			return true
	return false
