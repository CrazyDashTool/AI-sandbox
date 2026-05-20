extends Node3D

var time := 0.0
var ring: MeshInstance3D
var label: Label3D

func _ready() -> void:
	visible = false
	_build()

func set_active(value: bool) -> void:
	visible = value
	time = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	time += delta
	ring.rotation.y += delta * 1.7
	ring.rotation.z = sin(time * 1.4) * 0.18
	label.text = ["?", "??", "???", "??"][int(time * 2.0) % 4]
	label.position.y = 0.2 + sin(time * 2.6) * 0.045
	for i in get_child_count():
		var child := get_child(i) as Node3D
		child.scale = Vector3.ONE * (1.0 + sin(time * 2.0 + i) * 0.08)

func _build() -> void:
	for i in 5:
		var cloud := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.08 + i * 0.012
		mesh.height = mesh.radius * 2.0
		cloud.mesh = mesh
		cloud.position = Vector3((i - 2) * 0.11, sin(i) * 0.04, 0.0)
		cloud.material_override = _mat(Color(0.62, 0.9, 1.0, 0.58))
		add_child(cloud)
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.21
	ring.mesh = torus
	ring.position.y = -0.02
	ring.material_override = _mat(Color(0.78, 0.96, 1.0, 0.34))
	add_child(ring)
	label = Label3D.new()
	label.font_size = 58
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.92, 1.0, 1.0)
	add_child(label)

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
