extends Node3D

class_name ConstructionLink

var anchor: RigidBody3D
var child: RigidBody3D
var relative := Transform3D.IDENTITY

func configure(anchor_body: RigidBody3D, child_body: RigidBody3D) -> void:
	anchor = anchor_body
	child = child_body
	if anchor and child:
		relative = anchor.global_transform.affine_inverse() * child.global_transform
		name = "Weld_%s_to_%s" % [child.name, anchor.name]

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(anchor) or not is_instance_valid(child):
		queue_free()
		return
	if child.freeze:
		return
	child.global_transform = anchor.global_transform * relative
	child.linear_velocity = anchor.linear_velocity
	child.angular_velocity = anchor.angular_velocity
