extends CanvasLayer

class_name UnderwaterEffect

const SHADER := preload("res://shaders/underwater_screen.gdshader")

var rect: ColorRect
var material: ShaderMaterial

func _ready() -> void:
	layer = 2
	visible = false
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	material = ShaderMaterial.new()
	material.shader = SHADER
	rect.material = material
	add_child(rect)

func update_from_water(camera: Camera3D, water_state) -> void:
	if not camera or not water_state or not bool(water_state.active):
		visible = false
		return
	var depth: float = float(water_state.surface_y) - camera.global_position.y
	if depth <= 0.05:
		visible = false
		return
	visible = true
	var fade: float = clamp(depth / 5.5, 0.0, 1.0)
	material.set_shader_parameter("depth_fade", fade)
	material.set_shader_parameter("distortion_strength", lerp(0.55, 1.65, fade))
	material.set_shader_parameter("wave_width", lerp(0.7, 1.45, fade))
