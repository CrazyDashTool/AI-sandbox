extends RefCounted

class_name ArtMaterials

const SOFT := preload("res://shaders/soft_clay.gdshader")
const GROUND := preload("res://shaders/pastel_ground.gdshader")
const GLASS := preload("res://shaders/liquid_glass_3d.gdshader")

static func soft(color: Color, top := Color(1, 1, 1, 1)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SOFT
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("top_tint", top)
	mat.set_shader_parameter("roughness", 0.86)
	return mat

static func ground() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GROUND
	mat.set_shader_parameter("near_color", Color(0.22, 0.5, 0.17))
	mat.set_shader_parameter("far_color", Color(0.48, 0.76, 0.32))
	return mat

static func glass(color := Color(0.7, 0.92, 1.0, 0.42)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GLASS
	mat.set_shader_parameter("glass_color", color)
	return mat
