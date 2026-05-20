extends CollisionObject3D

class_name MapSeatInteractable

var interaction_kind := "seat"
var display_name := "Seat"

func setup_map_seat(kind: String, label: String, seat_height: float) -> void:
	interaction_kind = kind
	display_name = label
	set_meta("seat_height", seat_height)
	add_to_group("interactive_prop")
	if get_class() == "RigidBody3D":
		set("freeze_mode", RigidBody3D.FREEZE_MODE_STATIC)
		set("freeze", true)
		set("gravity_scale", 0.0)

func can_interact() -> bool:
	return true

func interact_with(user: Node3D) -> bool:
	return use_scene_prop(user)

func use_scene_prop(user: Node3D) -> bool:
	if user and user.has_method("start_prop_interaction"):
		user.start_prop_interaction(interaction_kind, self)
	var actor := "npc" if user and user.is_in_group("npc") else "player"
	WorldContext.log_player_action("%s_sat_on_map_prop" % actor, {"object": display_name})
	return true

func get_interaction_kind() -> String:
	return interaction_kind

func get_display_name() -> String:
	return display_name
