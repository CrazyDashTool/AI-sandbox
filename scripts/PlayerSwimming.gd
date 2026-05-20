extends RefCounted

class_name PlayerSwimming

var active := false
var surface_y := 0.0

func enter(value: float) -> void:
	active = true
	surface_y = value

func exit() -> void:
	active = false

func apply(player: CharacterBody3D, delta: float, input: Vector2, camera: Camera3D, sprinting: bool, dive_down: bool = false) -> void:
	var basis: Basis = camera.global_transform.basis
	var desired: Vector3 = basis.x * input.x + basis.z * input.y
	if desired.length() > 0.05:
		desired = desired.normalized()
	var speed: float = 4.2 if sprinting else 3.0
	var target: Vector3 = desired * speed
	var depth: float = surface_y - player.global_position.y
	var surface_pull := 0.0
	if depth < 0.8:
		surface_pull = clamp((surface_y - 0.9 - player.global_position.y) * 0.75, -0.35, 0.45)
	elif target.y > -0.15 and not dive_down:
		surface_pull = clamp((surface_y - 2.0 - player.global_position.y) * 0.12, -0.12, 0.22)
	target.y += surface_pull
	if dive_down and GameState.allows_mouse_look():
		target.y -= 3.2
	if Input.is_action_just_pressed("jump") and GameState.allows_mouse_look():
		target.y = max(target.y, 7.2)
		player.velocity.y = max(player.velocity.y, 7.2)
		var forward := -camera.global_transform.basis.z
		forward.y = 0.0
		if forward.length() > 0.05:
			forward = forward.normalized()
			player.velocity.x += forward.x * 1.2
			player.velocity.z += forward.z * 1.2
	player.velocity = player.velocity.lerp(target, min(1.0, delta * 4.2))
