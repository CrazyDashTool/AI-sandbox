extends Node3D

const RAIN_COUNT := 320
const STAR_COUNT := 120
const RAIN_SKY_CHECK_HEIGHT := 80.0

var rain_field: MultiMeshInstance3D
var star_field: MultiMeshInstance3D
var rain_mat: StandardMaterial3D
var lightning: MeshInstance3D
var lightning_light: DirectionalLight3D
var lightning_timer := 0.0
var rain_offsets: Array[Vector3] = []
var rain_speeds: Array[float] = []

func setup() -> void:
	_make_rain()
	_make_stars()
	_make_lightning()

func update_visuals(delta: float, rain_strength: float, cloudiness: float, daylight: float) -> void:
	_update_rain(delta, rain_strength)
	_update_stars(daylight, cloudiness, rain_strength)
	_update_lightning(delta)

func trigger_lightning(strength: float = 1.0) -> void:
	lightning_timer = 0.24
	_build_lightning_mesh(strength)
	lightning.visible = true
	lightning_light.visible = true
	lightning_light.light_energy = 1.1 + strength * 1.6

func _make_rain() -> void:
	rain_field = MultiMeshInstance3D.new()
	rain_field.name = "WeatherRain"
	rain_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := BoxMesh.new()
	box.size = Vector3(0.018, 0.72, 0.018)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = RAIN_COUNT
	multi.visible_instance_count = 0
	rain_field.multimesh = multi
	rain_mat = StandardMaterial3D.new()
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.albedo_color = Color(0.68, 0.82, 1.0, 0.42)
	rain_field.material_override = rain_mat
	add_child(rain_field)
	for i in RAIN_COUNT:
		rain_offsets.append(Vector3(randf_range(-24, 24), randf_range(3, 15), randf_range(-24, 24)))
		rain_speeds.append(randf_range(15, 25))

func _update_rain(delta: float, rain_strength: float) -> void:
	rain_field.visible = rain_strength > 0.004
	if not rain_field.visible:
		rain_field.multimesh.visible_instance_count = 0
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var center := player.global_position if player else Vector3.ZERO
	if player and _is_camera_underwater(player):
		rain_field.multimesh.visible_instance_count = 0
		return
	var visible_strength := smoothstep(0.0, 1.0, rain_strength)
	rain_field.multimesh.visible_instance_count = int(RAIN_COUNT * clamp(visible_strength, 0.0, 1.0))
	rain_mat.albedo_color.a = lerp(0.04, 0.46, visible_strength)
	var basis := Basis.IDENTITY.rotated(Vector3(1, 0, 0), deg_to_rad(8.0 + rain_strength * 8.0))
	var hidden_basis := Basis.IDENTITY.scaled(Vector3.ONE * 0.001)
	var hidden_position := center + Vector3(0.0, -120.0, 0.0)
	var space_state := get_world_3d().direct_space_state if get_world_3d() else null
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	for i in RAIN_COUNT:
		var offset := rain_offsets[i]
		offset.y -= rain_speeds[i] * delta
		if offset.y < -2.0:
			offset = Vector3(randf_range(-24, 24), randf_range(11, 18), randf_range(-24, 24))
		rain_offsets[i] = offset
		var drop_position := center + offset
		if _is_point_underwater(drop_position) or _has_cover_above(drop_position, space_state, exclude):
			rain_field.multimesh.set_instance_transform(i, Transform3D(hidden_basis, hidden_position))
		else:
			rain_field.multimesh.set_instance_transform(i, Transform3D(basis, drop_position))

func _is_camera_underwater(player: Node3D) -> bool:
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	var point := camera.global_position if camera else player.global_position + Vector3.UP * 1.55
	return _is_point_underwater(point)

func _is_point_underwater(point: Vector3) -> bool:
	for area_node in get_tree().get_nodes_in_group("water_area"):
		var area := area_node as Area3D
		if area and _is_point_in_water_xz(area, point):
			var surface_y: float = float(area.get_meta("surface_y", area.global_position.y))
			if point.y < surface_y - 0.04:
				return true
	return false

func _is_point_in_water_xz(area: Area3D, point: Vector3) -> bool:
	var shape_node := _water_box_shape_node(area)
	if not shape_node or not shape_node.shape is BoxShape3D:
		return false
	var local := area.to_local(point)
	var half_size: Vector3 = (shape_node.shape as BoxShape3D).size * 0.5
	return abs(local.x) <= half_size.x and abs(local.z) <= half_size.z

func _water_box_shape_node(area: Area3D) -> CollisionShape3D:
	for child in area.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null

func _has_cover_above(point: Vector3, space_state: PhysicsDirectSpaceState3D, exclude: Array[RID]) -> bool:
	if not space_state:
		return false
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.12, point + Vector3.UP * RAIN_SKY_CHECK_HEIGHT)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	query.exclude = exclude
	return not space_state.intersect_ray(query).is_empty()

func _make_stars() -> void:
	star_field = MultiMeshInstance3D.new()
	star_field.name = "WeatherStars"
	star_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.radial_segments = 6
	sphere.rings = 3
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = sphere
	multi.instance_count = STAR_COUNT
	multi.visible_instance_count = 0
	star_field.multimesh = multi
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.95, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.82, 1.0)
	star_field.material_override = mat
	add_child(star_field)
	for i in STAR_COUNT:
		var yaw := randf_range(0, TAU)
		var pitch := randf_range(deg_to_rad(18), deg_to_rad(78))
		var pos := Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch)) * randf_range(42, 72)
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))

func _update_stars(daylight: float, cloudiness: float, rain_strength: float) -> void:
	var clear_night := (1.0 - daylight) * (1.0 - cloudiness * 0.82) * (1.0 - rain_strength)
	star_field.visible = clear_night > 0.08
	star_field.multimesh.visible_instance_count = int(STAR_COUNT * clamp(clear_night, 0.0, 1.0))
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		star_field.global_position = player.global_position

func _make_lightning() -> void:
	lightning = MeshInstance3D.new()
	lightning.name = "DistantLightning"
	lightning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lightning.visible = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.74, 0.88, 1.0, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(0.58, 0.82, 1.0)
	mat.emission_energy_multiplier = 3.2
	lightning.material_override = mat
	add_child(lightning)
	lightning_light = DirectionalLight3D.new()
	lightning_light.name = "DistantLightningFlash"
	lightning_light.visible = false
	lightning_light.light_color = Color(0.62, 0.78, 1.0)
	lightning_light.shadow_enabled = false
	add_child(lightning_light)

func _build_lightning_mesh(strength: float) -> void:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var center: Vector3 = player.global_position if player else Vector3.ZERO
	var side: float = -1.0 if randf() < 0.5 else 1.0
	var origin: Vector3 = center + Vector3(side * randf_range(46.0, 70.0), randf_range(24.0, 36.0), randf_range(-72.0, -48.0))
	var point: Vector3 = origin
	var branches: int = randi_range(5, 8)
	for i in branches:
		var next: Vector3 = point + Vector3(randf_range(-4.5, 4.5), -randf_range(3.8, 6.2), randf_range(-2.2, 2.2))
		mesh.surface_add_vertex(point)
		mesh.surface_add_vertex(next)
		if randf() < 0.38:
			var branch: Vector3 = next + Vector3(randf_range(-7.0, 7.0), -randf_range(1.5, 4.0), randf_range(-3.0, 3.0))
			mesh.surface_add_vertex(next)
			mesh.surface_add_vertex(branch)
		point = next
	mesh.surface_end()
	lightning.mesh = mesh
	lightning_light.global_rotation = Vector3(deg_to_rad(-62.0), deg_to_rad(side * 35.0), 0.0)
	lightning_light.light_energy = 1.1 + strength * 1.6

func _update_lightning(delta: float) -> void:
	if lightning_timer <= 0.0:
		if lightning:
			lightning.visible = false
		if lightning_light:
			lightning_light.visible = false
		return
	lightning_timer = max(0.0, lightning_timer - delta)
	var pulse: float = sin(lightning_timer * 72.0) * 0.5 + 0.5
	var fade: float = clamp(lightning_timer / 0.24, 0.0, 1.0)
	lightning.visible = pulse > 0.22
	lightning_light.light_energy = fade * (0.8 + pulse * 2.2)
