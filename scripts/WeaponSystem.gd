extends RefCounted

class_name WeaponSystem

const IMPACTS := [
	"res://Sounds/MetalSound1.mp3",
	"res://Sounds/MetalSound2.mp3",
	"res://Sounds/MetalSound3.mp3",
	"res://Sounds/MetalSound4.mp3"
]

static func is_weapon(name: String) -> bool:
	return name == "Metal pipe"

static func use_weapon(name: String, camera: Camera3D, user: Node3D, held: CollisionObject3D) -> void:
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z.normalized()
	_hit_scan(name, origin, direction, user, held, 2.7, 6.0, 1)

static func npc_fire(name: String, from: Vector3, direction: Vector3, user: Node3D) -> void:
	_hit_scan(name, from, direction.normalized(), user, null, 2.5, 4.0, 1)

static func _hit_scan(name: String, origin: Vector3, direction: Vector3, user: Node3D, held: CollisionObject3D, distance: float, impulse: float, shot_count: int) -> void:
	var world := user.get_world_3d()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance)
	query.exclude = []
	if user is CollisionObject3D:
		query.exclude.append(user.get_rid())
	if held:
		query.exclude.append(held.get_rid())
	var hit := world.direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if hit else origin + direction * distance
	_beam(user, origin, end, false)
	_impact_sound(user, end)
	if hit:
		var collider: Object = hit.collider
		if collider is RigidBody3D:
			collider.apply_impulse(direction * impulse / float(shot_count), hit.position - collider.global_position)
		if collider.has_method("react_to_weapon"):
			collider.react_to_weapon(name)

static func _beam(user: Node, start: Vector3, end: Vector3, warm: bool) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(end)
	mesh.surface_end()
	var beam := MeshInstance3D.new()
	beam.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.72, 0.34, 0.85) if warm else Color(0.55, 0.9, 1.0, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = mat
	user.get_tree().current_scene.add_child(beam)
	var tween := beam.create_tween()
	tween.tween_property(beam, "transparency", 1.0, 0.12)
	tween.tween_callback(beam.queue_free)

static func _impact_sound(user: Node, position: Vector3) -> void:
	var stream := load(IMPACTS.pick_random())
	if not stream:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = GameState.SFX_BUS
	player.global_position = position
	player.volume_db = -5.0
	player.pitch_scale = randf_range(0.9, 1.1)
	user.get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
