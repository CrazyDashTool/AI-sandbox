extends RefCounted

class_name PropCatalog

static func definitions() -> Dictionary:
	var defs := {
		"Ball": {"shape": "sphere", "size": Vector3(0.8, 0.8, 0.8), "color": Color(0.95, 0.35, 0.35), "lift": 0.5, "scene": "res://assets/props/Ball/Ball.tscn", "bounce": 0.9, "friction": 0.35},
		"Balloon": {"shape": "sphere", "size": Vector3(0.9, 1.2, 0.9), "color": Color(1.0, 0.45, 0.78), "lift": 0.75, "scene": "res://assets/props/Ballon/Ballon.tscn", "gravity": 0.0, "mass": 0.22, "impact": "balloon"},
		"Barrel": {"shape": "cylinder", "size": Vector3(0.9, 1.25, 0.9), "color": Color(0.56, 0.42, 0.28), "lift": 0.7, "scene": "res://assets/props/Barrel/Barrel.tscn", "impact": "metal", "mass": 1.5},
		"Bench": {"shape": "box", "size": Vector3(1.8, 0.22, 0.55), "color": Color(0.48, 0.32, 0.2), "lift": 0.45, "scene": "res://assets/props/Bench/Bench.tscn", "impact": "wood", "interaction": "bench", "mass": 1.2},
		"Board": {"shape": "box", "size": Vector3(2.2, 0.16, 0.48), "color": Color(0.48, 0.32, 0.18), "lift": 0.2, "scene": "res://assets/props/Board/Board.tscn", "impact": "board", "mass": 0.9},
		"Bush": {"shape": "sphere", "size": Vector3(1.3, 0.8, 1.2), "color": Color(0.18, 0.48, 0.16), "lift": 0.38, "scene": "res://assets/props/Bush/Bush.tscn", "mass": 0.55, "impact": "wood"},
		"Chair": {"shape": "box", "size": Vector3(0.8, 0.25, 0.8), "color": Color(0.48, 0.32, 0.24), "lift": 0.55, "scene": "res://assets/props/Chair/Chair.tscn", "impact": "wood", "interaction": "chair", "seat_height": 0.68, "mass": 0.8},
		"Cone": {"shape": "cone", "size": Vector3(1, 1.3, 1), "color": Color(0.9, 0.48, 0.42), "lift": 0.7, "scene": "res://assets/props/Cone/Cone.tscn"},
		"Crate": {"shape": "box", "size": Vector3(1.1, 1.1, 1.1), "color": Color(0.55, 0.36, 0.18), "lift": 0.6, "scene": "res://assets/props/Create/Create.tscn", "impact": "wood", "mass": 1.1},
		"Cube": {"shape": "box", "size": Vector3(1, 1, 1), "color": Color(0.62, 0.72, 0.95), "lift": 0.55, "scene": "res://assets/props/Cube/Cube.tscn"},
		"Gemma Token": {"shape": "cylinder", "size": Vector3(0.75, 0.14, 0.75), "color": Color(0.95, 0.78, 0.26), "lift": 0.18, "scene": "res://assets/props/Gemma/Gemma.tscn", "mass": 0.45, "impact": "metal"},
		"Lamp": {"shape": "cylinder", "size": Vector3(0.35, 1.5, 0.35), "color": Color(0.95, 0.84, 0.52), "lift": 0.8, "scene": "res://assets/props/Lamp/Lamp.tscn", "impact": "metal", "mass": 0.8},
		"Metal pipe": {"shape": "cylinder", "size": Vector3(0.16, 1.45, 0.16), "color": Color(0.62, 0.66, 0.7), "lift": 0.35, "scene": "res://assets/props/MetalPipe/Pipe.tscn", "rotation": Vector3(90, 0, 0), "mass": 1.2, "impact": "metal"},
		"Beach Blanket": {"shape": "box", "size": Vector3(2.2, 0.06, 1.15), "color": Color(0.38, 0.64, 0.95), "lift": 0.07, "scene": "res://assets/props/pled/Pled.tscn", "mass": 0.35, "impact": "board", "interaction": "blanket", "random_color": "blanket"},
		"Rock": {"shape": "sphere", "size": Vector3(1.2, 0.55, 1.2), "color": Color(0.48, 0.5, 0.56), "lift": 0.35, "scene": "res://assets/props/Rock/Rock.tscn", "impact": "rock", "mass": 1.4},
		"Table": {"shape": "box", "size": Vector3(1.5, 0.22, 1.0), "color": Color(0.44, 0.28, 0.18), "lift": 0.75, "scene": "res://assets/props/Table/Table.tscn", "impact": "wood", "mass": 1.1},
		"Tree": {"shape": "cylinder", "size": Vector3(0.7, 1.8, 0.7), "color": Color(0.2, 0.45, 0.18), "lift": 0.95, "scene": "res://assets/props/Tree/Tree.tscn", "mass": 2.0, "impact": "wood"},
		"Wall": {"shape": "box", "size": Vector3(2.5, 2.0, 0.18), "color": Color(0.64, 0.66, 0.68), "lift": 1.05, "scene": "res://assets/props/Wall/Wall.tscn", "impact": "concrete", "mass": 2.4},
		"Wheel": {"shape": "cylinder", "size": Vector3(1.0, 0.35, 1.0), "color": Color(0.1, 0.1, 0.12), "lift": 0.6, "scene": "res://assets/props/Wheel/Wheel.tscn", "rotation": Vector3(90, 0, 0), "impact": "wood", "mass": 0.8}
	}
	_merge_asset_defs(defs)
	return defs

static func display_name(type_name: String) -> String:
	match type_name:
		"Boombox Jaz":
			return "Boombox Jazz"
		"Boombox Chiled":
			return "Boombox Chill"
		"Gemma Token":
			return "Gemma Tocken"
		"Metal pipe":
			return "Metal Pipe"
	return type_name

static func _merge_asset_defs(defs: Dictionary) -> void:
	var dir := DirAccess.open("res://assets/props")
	if not dir:
		return
	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir() and not folder.begins_with("."):
			var type_name := _type_name_from_folder(folder)
			var scene_path := _first_scene("res://assets/props/%s" % folder)
			if scene_path != "":
				if not defs.has(type_name):
					var hue := float(abs(type_name.hash()) % 1000) / 1000.0
					defs[type_name] = {"shape": "box", "size": Vector3.ONE, "color": Color.from_hsv(hue, 0.35, 0.85), "lift": 0.6, "scene": scene_path}
				elif not defs[type_name].has("scene"):
					defs[type_name]["scene"] = scene_path
		folder = dir.get_next()
	dir.list_dir_end()

static func _first_scene(folder_path: String) -> String:
	var dir := DirAccess.open(folder_path)
	if not dir:
		return ""
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.get_extension().to_lower() == "tscn":
			dir.list_dir_end()
			return "%s/%s" % [folder_path, file]
		file = dir.get_next()
	dir.list_dir_end()
	return ""

static func _type_name_from_folder(folder: String) -> String:
	match folder:
		"Create":
			return "Crate"
		"Ballon":
			return "Balloon"
		"MetalPipe":
			return "Metal pipe"
		"Gemma":
			return "Gemma Token"
		"pled":
			return "Beach Blanket"
	return folder
