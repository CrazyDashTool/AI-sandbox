extends CharacterBody3D
const WEAPON_SYSTEM := preload("res://scripts/WeaponSystem.gd")
const ART := preload("res://scripts/ArtMaterials.gd")
const THINKING_VISUAL := preload("res://scripts/NPCThinking.gd")
var emotion := "neutral"
var last_speech := ""
var visual_root: Node3D
var head_node: Node3D
var left_arm: Node3D
var right_arm: Node3D
var body_material: ShaderMaterial
var head_material: ShaderMaterial
var face_label: Label3D
var speech_panel: Sprite3D
var speech_label: Label3D
var thinking_root: Node3D
var speech_tween: Tween
var decision_serial := 0

const SPEECH_MAX_CHARS := 120
const SPEECH_WIDTH := 360
const SPEECH_PIXEL_SIZE := 0.0038
const SPEECH_PANEL_TEXTURE_SIZE := Vector2i(520, 160)
const SPEECH_BEFORE_MOVE_DELAY := 0.75

func _ready() -> void:
	add_to_group("npc")
	_build_visual()
	$Movement.bind_visual(visual_root, head_node, left_arm, right_arm)
func on_brain_decision(decision: Dictionary) -> void:
	decision_serial += 1
	var serial := decision_serial
	var speech := str(decision.get("speech", ""))
	var action := str(decision.get("action", "idle"))
	apply_emotion(str(decision.get("emotion", "neutral")))
	if speech != "":
		show_speech(speech)
	if speech != "" and _should_delay_action(action):
		await get_tree().create_timer(SPEECH_BEFORE_MOVE_DELAY).timeout
		if serial != decision_serial:
			return
	$Movement.perform_action(action, emotion)

func apply_emotion(value: String) -> void:
	emotion = value
	var color := Color(0.52, 0.62, 0.72)
	match emotion:
		"happy":
			color = Color(0.95, 0.82, 0.45)
			face_label.text = ":)"
		"surprised":
			color = Color(0.8, 0.78, 0.95)
			face_label.text = ":O"
		"scared":
			color = Color(0.9, 0.92, 0.94)
			face_label.text = "o_o"
		"curious":
			color = Color(0.46, 0.78, 0.74)
			face_label.text = ":?"
		"annoyed":
			color = Color(0.88, 0.45, 0.42)
			face_label.text = ">:|"
		_:
			face_label.text = ":|"
	body_material.set_shader_parameter("base_color", color)
	body_material.set_shader_parameter("top_tint", color.lightened(0.24))
	head_material.set_shader_parameter("base_color", color.lightened(0.12))
	head_material.set_shader_parameter("top_tint", color.lightened(0.32))

func show_speech(text: String) -> void:
	var clean_text := _format_speech(text)
	last_speech = clean_text
	WorldContext.remember_npc_speech(clean_text)
	GameState.notify_npc_speech(clean_text, emotion)
	speech_label.text = clean_text
	speech_label.modulate.a = 1.0
	speech_panel.modulate.a = 1.0
	speech_panel.visible = true
	speech_label.visible = true
	if speech_tween:
		speech_tween.kill()
	speech_tween = create_tween()
	speech_tween.tween_interval(4.8)
	var tween := speech_tween
	tween.set_parallel(true)
	tween.tween_property(speech_label, "modulate:a", 0.0, 0.45)
	tween.tween_property(speech_panel, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(func() -> void:
		speech_panel.visible = false
		speech_label.visible = false
	)

func _should_delay_action(action: String) -> bool:
	if action.begins_with("walk_to_"):
		return true
	return ["run_away", "swim_in_water"].has(action)

func set_thinking(value: bool) -> void:
	if thinking_root:
		thinking_root.set_active(value)
	GameState.set_npc_thinking(value)

func react_to_hit(object_name: String) -> void:
	$Movement.flinch()
	apply_emotion("surprised")
	var brain := get_node_or_null("Brain")
	if brain and brain.has_method("request_think_now"):
		brain.request_think_now("Player threw %s at NPC" % object_name)

func react_to_weapon(weapon_name: String) -> void:
	$Movement.flinch()
	apply_emotion("scared")
	var brain := get_node_or_null("Brain")
	if brain and brain.has_method("request_think_now"):
		brain.request_think_now("Player used %s near NPC" % weapon_name)

func use_weapon() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	var from := head_node.global_position
	var direction := (player.global_position + Vector3.UP - from).normalized()
	WEAPON_SYSTEM.npc_fire("Metal pipe", from, direction, self)

func get_status_text() -> String:
	return "%s  %s" % [emotion, last_speech]

func get_last_speech() -> String:
	return last_speech

func get_emotion_text() -> String:
	return emotion

func get_movement_status_text() -> String:
	if has_node("Movement") and $Movement.has_method("get_status_text"):
		return $Movement.get_status_text()
	return "unknown"

func get_brain_camera_transform() -> Transform3D:
	if head_node:
		var basis := head_node.global_transform.basis.orthonormalized()
		var origin := head_node.global_position - basis.z * 0.42 + basis.y * 0.04
		return Transform3D(basis, origin)
	return global_transform

func look_at_player_for_vision(seconds: float = 1.8) -> void:
	if has_node("Movement") and $Movement.has_method("look_at_player"):
		$Movement.look_at_player(seconds)

func start_route(points: Array, names: Array = [], follow_player_at_end: bool = false) -> void:
	if has_node("Movement") and $Movement.has_method("start_route"):
		$Movement.start_route(points, names, follow_player_at_end)

func start_collect_task(command: Dictionary) -> void:
	if has_node("Movement") and $Movement.has_method("start_collect_task"):
		$Movement.start_collect_task(command)

func start_prop_interaction(kind: String, prop: Node3D) -> void:
	if has_node("Movement") and $Movement.has_method("start_prop_interaction"):
		$Movement.start_prop_interaction(kind, prop)

func enter_water(surface_y: float, speed: float) -> void:
	$Movement.enter_water(surface_y, speed)

func exit_water() -> void:
	$Movement.exit_water()

func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	body_material = _mat(Color(0.52, 0.62, 0.72))
	head_material = _mat(Color(0.62, 0.72, 0.82))
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.32
	body_mesh.height = 1.35
	body.mesh = body_mesh
	body.position.y = 0.9
	body.material_override = body_material
	visual_root.add_child(body)
	head_node = Node3D.new()
	head_node.position.y = 1.75
	visual_root.add_child(head_node)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	head.mesh = sphere
	head.material_override = head_material
	head_node.add_child(head)
	face_label = Label3D.new()
	face_label.text = ":|"
	face_label.font_size = 58
	face_label.pixel_size = 0.0052
	face_label.outline_size = 8
	face_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.55)
	face_label.position = Vector3(0, 0.02, -0.33)
	face_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	face_label.no_depth_test = true
	head_node.add_child(face_label)
	left_arm = _arm(Vector3(-0.43, 1.05, 0), 9.0)
	right_arm = _arm(Vector3(0.43, 1.05, 0), -9.0)
	_make_speech()
	_make_thinking()

func _arm(pos: Vector3, z_rot: float) -> Node3D:
	var arm := Node3D.new()
	arm.position = pos
	visual_root.add_child(arm)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.06
	cylinder.bottom_radius = 0.06
	cylinder.height = 0.8
	mesh.mesh = cylinder
	mesh.rotation_degrees.z = z_rot
	mesh.position.y = -0.25
	mesh.material_override = body_material
	arm.add_child(mesh)
	return arm

func _make_speech() -> void:
	speech_panel = Sprite3D.new()
	speech_panel.texture = _speech_panel_texture()
	speech_panel.pixel_size = SPEECH_PIXEL_SIZE
	speech_panel.position = Vector3(0, 2.78, 0)
	speech_panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech_panel.no_depth_test = true
	speech_panel.fixed_size = false
	speech_panel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	speech_panel.visible = false
	visual_root.add_child(speech_panel)
	speech_label = Label3D.new()
	speech_label.font_size = 22
	speech_label.pixel_size = SPEECH_PIXEL_SIZE
	speech_label.width = SPEECH_WIDTH
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech_label.modulate = Color(0.97, 0.99, 1.0, 1.0)
	speech_label.outline_size = 7
	speech_label.outline_modulate = Color(0.02, 0.03, 0.04, 0.82)
	speech_label.position = Vector3(-float(SPEECH_WIDTH) * SPEECH_PIXEL_SIZE * 0.5, 2.835, 0.01)
	speech_label.visible = false
	speech_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech_label.no_depth_test = true
	speech_label.fixed_size = false
	visual_root.add_child(speech_label)

func _speech_panel_texture() -> ImageTexture:
	var image := Image.create(SPEECH_PANEL_TEXTURE_SIZE.x, SPEECH_PANEL_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	var radius := 28.0
	var border := 3.0
	var size := Vector2(SPEECH_PANEL_TEXTURE_SIZE)
	for y in SPEECH_PANEL_TEXTURE_SIZE.y:
		for x in SPEECH_PANEL_TEXTURE_SIZE.x:
			var p := Vector2(x, y)
			var inner := Vector2(
				clamp(p.x, radius, size.x - radius),
				clamp(p.y, radius, size.y - radius)
			)
			var distance: float = p.distance_to(inner)
			if distance <= radius:
				var edge: float = clamp((radius - distance) / 3.0, 0.0, 1.0)
				var is_border := distance > radius - border or x < border or y < border or x > size.x - border or y > size.y - border
				var color := Color(0.045, 0.065, 0.085, 0.76 * edge)
				if is_border:
					color = Color(0.65, 0.95, 0.92, 0.34 * edge)
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _format_speech(text: String) -> String:
	var clean := text.strip_edges().replace("\n", " ")
	while clean.find("  ") >= 0:
		clean = clean.replace("  ", " ")
	if clean.length() > SPEECH_MAX_CHARS:
		clean = clean.left(SPEECH_MAX_CHARS - 3).strip_edges() + "..."
	return clean

func _make_thinking() -> void:
	thinking_root = THINKING_VISUAL.new()
	thinking_root.position = Vector3(0, 2.45, 0)
	visual_root.add_child(thinking_root)

func _mat(color: Color) -> ShaderMaterial:
	return ART.soft(color, color.lightened(0.24))
