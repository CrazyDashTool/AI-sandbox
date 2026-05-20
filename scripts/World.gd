extends Node3D

const OBJECT_SPAWNER := preload("res://scripts/ObjectSpawner.gd")
const ART := preload("res://scripts/ArtMaterials.gd")
const SKY_SHADER := preload("res://shaders/sky_gradient.gdshader")
const GRASS_FIELD := preload("res://scripts/GrassField.gd")
const WATER_INTERACTION := preload("res://scripts/WaterInteraction.gd")
const MAP_SEAT_INTERACTABLE := preload("res://scripts/MapSeatInteractable.gd")
const WEATHER_CYCLE := preload("res://scripts/WeatherCycle.gd")
const GAME_CONSOLE := preload("res://scripts/GameConsole.gd")

var authored_map := false

func _ready() -> void:
	authored_map = _has_authored_map()
	_make_environment()
	_make_floor()
	_make_grass()
	_make_water_interaction()
	_make_weather_cycle()
	_make_console()
	_make_navigation()
	_make_map_interactables()
	if not authored_map:
		_make_decor()
	var spawner := Node3D.new()
	spawner.name = "ObjectSpawner"
	spawner.set_script(OBJECT_SPAWNER)
	add_child(spawner)

func _make_environment() -> void:
	if _has_child_type(WorldEnvironment) and _has_child_type(DirectionalLight3D):
		return
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.54, 0.66, 0.7)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.03
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_energy = 0.92
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 72.0
	add_child(sun)

func _make_floor() -> void:
	if _has_child_type(StaticBody3D):
		return
	var body := StaticBody3D.new()
	body.name = "SandboxFloor"
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(100.0, 0.2, 100.0)
	mesh.mesh = box
	mesh.position.y = -0.1
	mesh.material_override = ART.ground()
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	shape.position.y = -0.1
	body.add_child(shape)

func _make_grass() -> void:
	if _has_named_child("SimpleGrassTextured") or _has_named_child("GrassField"):
		return
	var grass := GRASS_FIELD.new()
	grass.name = "GrassField"
	add_child(grass)

func _make_water_interaction() -> void:
	if _has_named_child("WaterInteraction"):
		return
	var water := WATER_INTERACTION.new()
	water.name = "WaterInteraction"
	add_child(water)

func _make_weather_cycle() -> void:
	if _has_named_child("WeatherCycle"):
		return
	var weather := WEATHER_CYCLE.new()
	weather.name = "WeatherCycle"
	add_child(weather)

func _make_console() -> void:
	if _has_named_child("GameConsole"):
		return
	var console := GAME_CONSOLE.new()
	console.name = "GameConsole"
	add_child(console)

func _make_navigation() -> void:
	if _has_child_type(NavigationRegion3D):
		return
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var nav := NavigationMesh.new()
	nav.set_vertices(PackedVector3Array([
		Vector3(-48.0, 0.02, -48.0),
		Vector3(48.0, 0.02, -48.0),
		Vector3(48.0, 0.02, 48.0),
		Vector3(-48.0, 0.02, 48.0)
	]))
	nav.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = nav
	add_child(region)

func _make_map_interactables() -> void:
	_tag_map_seats(self)

func _tag_map_seats(node: Node) -> void:
	if node is CollisionObject3D:
		var lower := node.name.to_lower()
		if lower.find("bench") >= 0:
			_setup_map_seat(node as CollisionObject3D, "bench", "Bench", 0.85)
		elif lower.find("chair") >= 0:
			_setup_map_seat(node as CollisionObject3D, "chair", "Chair", 0.68)
		elif lower.find("pled") >= 0 or lower.find("blanket") >= 0:
			_setup_map_seat(node as CollisionObject3D, "blanket", "Beach Blanket", 0.32)
	for child in node.get_children():
		_tag_map_seats(child)

func _setup_map_seat(node: CollisionObject3D, kind: String, label: String, seat_height: float) -> void:
	node.set_script(MAP_SEAT_INTERACTABLE)
	if node.has_method("setup_map_seat"):
		node.setup_map_seat(kind, label, seat_height)

func _make_decor() -> void:
	for pos in [Vector3(-8, 0, -7), Vector3(8, 0, 6), Vector3(-11, 0, 6), Vector3(13, 0, -9), Vector3(-15, 0, -2), Vector3(18, 0, 11), Vector3(-22, 0, 13)]:
		_make_tree(pos)
	for pos in [Vector3(6, 0.25, -6), Vector3(-6, 0.25, 4), Vector3(10, 0.25, -1), Vector3(-13, 0.25, 8), Vector3(14, 0.25, 8)]:
		_make_bush(pos)

func _make_tree(pos: Vector3) -> void:
	var tree := StaticBody3D.new()
	tree.name = "Tree"
	tree.position = pos
	add_child(tree)
	_add_mesh(tree, _cylinder_mesh(0.16, 1.8), Vector3(0, 0.9, 0), Color(0.33, 0.22, 0.12))
	_add_mesh(tree, _sphere_mesh(0.85), Vector3(0, 2.05, 0), Color(0.18, 0.45, 0.22))
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.2
	shape.shape = capsule
	shape.position.y = 1.1
	tree.add_child(shape)

func _make_bush(pos: Vector3) -> void:
	var bush := StaticBody3D.new()
	bush.name = "Bush"
	bush.position = pos
	add_child(bush)
	var mesh := _sphere_mesh(0.65)
	_add_mesh(bush, mesh, Vector3.ZERO, Color(0.13, 0.42, 0.16), Vector3(1.35, 0.7, 1.05))
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	shape.shape = sphere
	bush.add_child(shape)

func _add_mesh(parent: Node, mesh: Mesh, pos: Vector3, color: Color, scale_value := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	instance.material_override = ART.soft(color, color.lightened(0.2))
	parent.add_child(instance)
	return instance

func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh

func _cylinder_mesh(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh

func _has_authored_map() -> bool:
	return _has_child_type(WorldEnvironment) or _has_child_type(DirectionalLight3D) or _has_child_type(StaticBody3D)

func _has_child_type(type: Variant) -> bool:
	for child in get_children():
		if is_instance_of(child, type):
			return true
	return false

func _has_named_child(node_name: String) -> bool:
	return get_node_or_null(node_name) != null
