extends Node3D

const ART := preload("res://scripts/ArtMaterials.gd")

var viewport: SubViewport
var mirror_camera: Camera3D
var screen: MeshInstance3D

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(768, 870)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.world_3d = get_viewport().world_3d
	add_child(viewport)
	mirror_camera = Camera3D.new()
	mirror_camera.current = true
	viewport.add_child(mirror_camera)
	screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.7)
	screen.mesh = quad
	screen.position = Vector3(0, 0, -0.062)
	screen.rotation_degrees.y = 180
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = viewport.get_texture()
	mat.roughness = 0.04
	mat.metallic = 0.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	screen.material_override = mat
	add_child(screen)

func _process(_delta: float) -> void:
	var active := get_viewport().get_camera_3d()
	if not active or not is_instance_valid(active):
		return
	var origin := global_transform.origin
	var normal := -global_transform.basis.z.normalized()
	var active_pos := active.global_position
	var reflected_pos := _reflect_point(active_pos, origin, normal)
	var active_target := active_pos - active.global_transform.basis.z
	var reflected_target := _reflect_point(active_target, origin, normal)
	var up := _reflect_vector(active.global_transform.basis.y, normal).normalized()
	mirror_camera.global_position = reflected_pos
	mirror_camera.look_at(reflected_target, up)
	mirror_camera.fov = active.fov
	mirror_camera.near = active.near
	mirror_camera.far = active.far

func _exit_tree() -> void:
	if screen and screen.material_override is StandardMaterial3D:
		screen.material_override.albedo_texture = null
	if viewport:
		viewport.world_3d = null

func _reflect_point(point: Vector3, plane_point: Vector3, normal: Vector3) -> Vector3:
	return point - normal * 2.0 * (point - plane_point).dot(normal)

func _reflect_vector(vector: Vector3, normal: Vector3) -> Vector3:
	return vector - normal * 2.0 * vector.dot(normal)
