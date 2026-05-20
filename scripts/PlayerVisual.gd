extends Node3D

const ART := preload("res://scripts/ArtMaterials.gd")
const VISUAL_LAYER := 1 << 1

func _ready() -> void:
	_add_capsule("Body", Vector3(0, 0.86, 0), 0.28, 1.1, Color(0.18, 0.34, 0.58))
	_add_sphere("Head", Vector3(0, 1.56, -0.02), 0.23, Color(0.22, 0.42, 0.68), Vector3(1.0, 1.08, 0.96))
	_add_capsule("LeftArm", Vector3(-0.34, 0.96, -0.08), 0.06, 0.74, Color(0.18, 0.34, 0.58), Vector3(0, 0, 12))
	_add_capsule("RightArm", Vector3(0.34, 0.96, -0.08), 0.06, 0.74, Color(0.18, 0.34, 0.58), Vector3(0, 0, -12))
	_add_capsule("LeftLeg", Vector3(-0.12, 0.32, 0), 0.08, 0.62, Color(0.08, 0.13, 0.2))
	_add_capsule("RightLeg", Vector3(0.12, 0.32, 0), 0.08, 0.62, Color(0.08, 0.13, 0.2))

func _add_capsule(name_value: String, pos: Vector3, radius: float, height: float, color: Color, rot := Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.name = name_value
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	part.mesh = mesh
	part.position = pos
	part.rotation_degrees = rot
	part.material_override = ART.soft(color, color.lightened(0.2))
	part.layers = VISUAL_LAYER
	add_child(part)

func _add_sphere(name_value: String, pos: Vector3, radius: float, color: Color, scale_value := Vector3.ONE) -> void:
	var part := MeshInstance3D.new()
	part.name = name_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	part.mesh = mesh
	part.position = pos
	part.scale = scale_value
	part.material_override = ART.soft(color, color.lightened(0.22))
	part.layers = VISUAL_LAYER
	add_child(part)
