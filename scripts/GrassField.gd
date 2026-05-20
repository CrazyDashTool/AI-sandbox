extends MultiMeshInstance3D

const GRASS_SHADER := preload("res://addons/simplegrasstextured/shaders/grass.gdshader")
const GRASS_TEXTURE := preload("res://addons/simplegrasstextured/textures/grassbushcc008.png")
const GRASS_MESH := preload("res://addons/simplegrasstextured/default_mesh.tres")

@export var field_size := 92.0
@export var count := 3200

func _ready() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = GRASS_MESH
	multimesh.instance_count = count
	for i in count:
		var x := randf_range(-field_size * 0.5, field_size * 0.5)
		var z := randf_range(-field_size * 0.5, field_size * 0.5)
		var scale := randf_range(0.45, 1.05)
		var basis := Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * scale)
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, 0.03, z)))
	material_override = _grass_material()

func _grass_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	mat.set_shader_parameter("albedo", Color(0.35, 0.64, 0.2))
	mat.set_shader_parameter("texture_albedo", GRASS_TEXTURE)
	mat.set_shader_parameter("texture_frames", Vector2(1, 1))
	mat.set_shader_parameter("alpha_scissor_threshold", 0.45)
	mat.set_shader_parameter("roughness", 1.0)
	mat.set_shader_parameter("grass_strength", 0.16)
	mat.set_shader_parameter("scale_h", 0.52)
	mat.set_shader_parameter("scale_w", 0.62)
	mat.set_shader_parameter("grass_size_y", 0.48)
	mat.set_shader_parameter("optimization_by_distance", true)
	mat.set_shader_parameter("optimization_dist_min", 20.0)
	mat.set_shader_parameter("optimization_dist_max", 58.0)
	return mat
