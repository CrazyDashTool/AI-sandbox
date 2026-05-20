extends Node

const PROP_CATALOG := preload("res://scripts/PropCatalog.gd")

const WORLD_MEMORY_PATH := "user://world_memory.cfg"
const MAX_KNOWN_PLACES := 12
const DUPLICATE_PLACE_DISTANCE := 6.0
const COLLECT_NEARBY_RADIUS := 18.0
const COLLECT_SOURCE_RADIUS := 28.0
const PLACE_ALIAS_GROUPS := {
	"home": ["home", "house", "дом", "дома", "домой", "хата", "дім", "дому", "додому", "будинок", "будинку"],
	"garage": ["garage", "гараж", "гаража", "гаражу"],
	"base": ["base", "база", "базу", "базе", "базі"],
	"camp": ["camp", "лагерь", "лагерю", "табір", "табору"],
	"dock": ["dock", "pier", "причал", "пирс", "пірс"],
	"bridge": ["bridge", "мост", "міст"],
	"tower": ["tower", "башня", "башню", "вежа", "вежу"],
	"shop": ["shop", "store", "магазин", "крамниця", "крамницю"],
	"farm": ["farm", "ферма", "ферму", "фермі"],
	"beach": ["beach", "shore", "coast", "пляж", "пляжа", "пляжу", "берег", "берега", "берегу", "узбережжя"],
	"point": ["point", "waypoint", "spot", "точка", "точку", "точке", "точці"],
	"zone": ["zone", "area", "зона", "зону", "зоне", "зоні", "ділянка", "ділянку"],
	"center": ["center", "centre", "центр", "центра", "центре", "центрі"],
	"forest": ["forest", "лес", "леса", "лесу", "ліс", "лісу"],
	"hill": ["hill", "mountain", "гора", "гору", "холм", "холму", "горі", "пагорб", "пагорб"],
	"road": ["road", "path", "дорога", "дорогу", "тропа", "тропу", "шлях", "стежка", "стежку"]
}
const ITEM_ALIAS_GROUPS := {
	"Chair": ["chair", "chairs", "стул", "стула", "стулом", "стулья", "стульев", "стілець", "стільці", "стільця"],
	"Table": ["table", "tables", "стол", "стола", "столы", "столов", "стіл", "стола", "столи"],
	"Shelf": ["shelf", "shelves", "полка", "полку", "шкаф", "стеллаж", "полиця", "полицю", "шафа"],
	"Crate": ["crate", "box", "boxes", "ящик", "ящика", "коробка", "коробку", "скриня", "скриню"],
	"Cube": ["cube", "cubes", "куб", "кубик", "куба"],
	"Gemma Token": ["gemma token", "gemma tocken", "gemma", "token", "токен", "джемма"],
	"Sphere": ["sphere", "ball", "шар", "сфера", "мяч"],
	"Cylinder": ["cylinder", "цилиндр"],
	"Cone": ["cone", "конус"],
	"Capsule": ["capsule", "капсула"],
	"Lamp": ["lamp", "лампа", "лампу", "ліхтар", "ліхтарик"],
	"Mirror": ["mirror", "зеркало", "зеркала", "дзеркало", "дзеркала"],
	"Metal pipe": ["metal pipe", "pipe", "труба", "трубу", "трубы", "трубу"],
	"Barrel": ["barrel", "barrels", "бочка", "бочку", "бочки", "діжка", "діжку"],
	"Bench": ["bench", "скамейка", "лавка", "лавочку", "лавка", "лавку"],
	"Board": ["board", "plank", "доска", "доску", "доски", "дошка", "дошку"],
	"Wall": ["wall", "panel", "стена", "стену", "стены", "стіна", "стіну"],
	"Rock": ["rock", "stone", "камень", "камни", "камня", "камінь", "камені"],
	"Tree": ["tree", "дерево", "деревья", "дерева"],
	"Bush": ["bush", "куст", "кусты", "кущ", "кущі"],
	"Beach Blanket": ["beach blanket", "blanket", "pled", "плед", "одеяло", "коврик", "ковдра", "килимок"],
	"Boombox": ["boombox", "music box", "магнитофон", "бумбокс"],
	"Boombox Jaz": ["jazz boombox", "jaz boombox"],
	"Boombox Chiled": ["chill boombox", "chiled boombox"],
	"Boombox Neon": ["neon boombox"],
	"Mini Car": ["car", "machine", "машина", "машину", "авто"],
	"Driver Seat": ["driver seat", "seat", "сиденье", "кресло"],
	"Boat Motor": ["boat motor", "motor", "мотор", "двигатель"],
	"Raft Platform": ["raft", "плот"],
	"Balloon": ["balloon", "шарик", "воздушный шар"]
}
const PLACE_DISPLAY_NAMES := {
	"home": "дом",
	"garage": "гараж",
	"base": "база",
	"camp": "лагерь",
	"dock": "причал",
	"bridge": "мост",
	"tower": "башня",
	"shop": "магазин",
	"farm": "ферма"
}

var spawned_objects: Array[Dictionary] = []
var player_actions: Array[Dictionary] = []
var constructions: Array[Dictionary] = []
var conversation_memory: Array[String] = []
var known_places: Array[Dictionary] = []
var player_speech := ""
var current_music := "none"
var water_present := false
var player_in_water := false
var npc_in_water := false
var weather_state := "clear"
var day_phase := "morning"
var world_hour := 9.0
var object_counter := 0
var last_activity_time := 0.0
var last_player_speech_time := 0.0

func _ready() -> void:
	last_activity_time = _stamp()
	last_player_speech_time = last_activity_time
	load_world_memory()

func register_spawned_object(type_name: String, position: Vector3, spawned_by: String) -> int:
	object_counter += 1
	spawned_objects.append({
		"id": object_counter,
		"type": type_name,
		"position": position,
		"spawned_by": spawned_by,
		"timestamp": _stamp()
	})
	_rebuild_constructions()
	return object_counter

func update_object_position(id: int, position: Vector3) -> void:
	for object in spawned_objects:
		if object.id == id:
			object.position = position
			break
	_rebuild_constructions()

func log_player_action(action: String, details: Dictionary = {}) -> void:
	last_activity_time = _stamp()
	player_actions.append({
		"action": action,
		"timestamp": _stamp(),
		"details": details
	})
	while player_actions.size() > 20:
		player_actions.pop_front()

func set_player_speech(text: String) -> void:
	player_speech = text.strip_edges()
	if player_speech != "":
		last_player_speech_time = _stamp()
		_remember("Player: %s" % player_speech)
		log_player_action("said", {"text": player_speech})
		var remembered_place: Dictionary = learn_place_from_speech(player_speech)
		if not remembered_place.is_empty():
			var pos: Vector3 = remembered_place.position
			_remember("World memory: %s is at %.1f, %.1f, %.1f." % [remembered_place.name, pos.x, pos.y, pos.z])
			log_player_action("remembered_place", {"place": remembered_place.name})

func remember_npc_speech(text: String) -> void:
	if text.strip_edges() != "":
		_remember("NPC: %s" % text.strip_edges())

func remember_npc_intent(text: String) -> void:
	if text.strip_edges() != "":
		_remember("NPC intent: %s" % text.strip_edges())

func set_music(style: String, enabled: bool) -> void:
	var display_style := _music_display_name(style)
	current_music = display_style if enabled else "none"
	log_player_action("music_%s" % ("started" if enabled else "stopped"), {"object": display_style})

func set_water_present(value: bool) -> void:
	water_present = value

func set_water_state(subject: String, value: bool) -> void:
	if subject == "player":
		player_in_water = value
	elif subject == "npc":
		npc_in_water = value

func set_environment_state(weather: String, hour: float, phase: String) -> void:
	weather_state = weather
	world_hour = hour
	day_phase = phase

func get_idle_seconds() -> float:
	return _stamp() - last_activity_time

func get_seconds_since_player_speech() -> float:
	return _stamp() - last_player_speech_time

func get_conversation_memory(count: int = 12) -> String:
	if conversation_memory.is_empty():
		return "none"
	if count <= 0 or conversation_memory.size() <= count:
		return "\n".join(conversation_memory)
	var start: int = max(0, conversation_memory.size() - count)
	return "\n".join(conversation_memory.slice(start, conversation_memory.size()))

func get_recent_actions(count: int = 5) -> Array[Dictionary]:
	var start: int = max(0, player_actions.size() - count)
	return player_actions.slice(start, player_actions.size())

func get_recent_actions_text(count: int = 5) -> String:
	var pieces: Array[String] = []
	for entry in get_recent_actions(count):
		pieces.append(_action_text(entry))
	return "none" if pieces.is_empty() else ", ".join(pieces)

func get_world_summary() -> String:
	var counts: Dictionary = {}
	for object in spawned_objects:
		counts[object.type] = counts.get(object.type, 0) + 1
	var object_bits: Array[String] = []
	for key in counts.keys():
		object_bits.append("%d %s" % [counts[key], _plural(_object_display_name(str(key)), counts[key])])
	var construction_bits: Array[String] = []
	for i in constructions.size():
		var construction: Dictionary = constructions[i]
		var center: Vector3 = construction.center
		construction_bits.append("Construction #%d (%d objects near %.1f, %.1f, %.1f)" % [i + 1, construction.objects.size(), center.x, center.y, center.z])
	var action_bits: Array[String] = []
	for entry in get_recent_actions(8):
		action_bits.append(_action_text(entry))
	var spawned_text := "nothing yet" if object_bits.is_empty() else ", ".join(object_bits)
	var construction_text := "none" if construction_bits.is_empty() else ", ".join(construction_bits)
	var action_text := "none" if action_bits.is_empty() else ", ".join(action_bits)
	var water_text := "water exists; player %s in water; npc %s in water" % ["is" if player_in_water else "is not", "is" if npc_in_water else "is not"] if water_present else "no water detected"
	var environment_text := "%s, %s, %.2f hours" % [day_phase, weather_state, world_hour]
	return "Player has spawned: %s. There are %d constructions: %s. Known places: %s. Current music: %s. Environment: %s. Water: %s. Recent player actions: %s." % [spawned_text, constructions.size(), construction_text, get_known_places_text(), current_music, environment_text, water_text, action_text]

func learn_place_from_speech(text: String) -> Dictionary:
	var place_name: String = _extract_place_name(text)
	if place_name == "":
		return {}
	var position: Vector3 = _best_memory_position()
	return remember_place(place_name, position)

func remember_place(raw_name: String, position: Vector3) -> Dictionary:
	var base_key: String = _canonical_place_key(raw_name)
	if base_key == "":
		return {}
	var name_key := _place_name_key(raw_name)
	var existing_index := _find_place_slot(base_key, name_key, position)
	var key := base_key
	if existing_index < 0:
		key = _unique_place_key(base_key)
	var display_name: String = PLACE_DISPLAY_NAMES.get(_base_place_key(base_key), raw_name.strip_edges())
	var place := {
		"key": key,
		"base_key": base_key,
		"name_key": name_key,
		"name": display_name,
		"position": position,
		"timestamp": _stamp()
	}
	if existing_index >= 0:
		known_places[existing_index] = place
	else:
		known_places.append(place)
	while known_places.size() > MAX_KNOWN_PLACES:
		known_places.pop_front()
	_save_world_memory()
	return place

func get_known_place_by_index(index: int) -> Dictionary:
	if index < 0 or index >= known_places.size():
		return {}
	return known_places[index]

func get_known_places_text(limit: int = MAX_KNOWN_PLACES) -> String:
	if known_places.is_empty():
		return "none"
	var pieces: Array[String] = []
	var count: int = min(limit, known_places.size())
	for i in count:
		var place: Dictionary = known_places[i]
		var pos: Vector3 = place.position
		pieces.append("#%d %s at %.1f, %.1f, %.1f; action walk_to_known_place_%d" % [i + 1, place.name, pos.x, pos.y, pos.z, i + 1])
	return "; ".join(pieces)

func get_direct_place_command(text: String) -> Dictionary:
	var normalized: String = _normalize_text(text)
	if not _has_movement_intent(normalized):
		return {}
	var best_command: Dictionary = {}
	var best_score := -INF
	var best_place_order := 999999
	for i in known_places.size():
		var place: Dictionary = known_places[i]
		var match_info := _place_match_info(normalized, place)
		if int(match_info.get("index", -1)) >= 0:
			var score := float(match_info.get("score", 0.0))
			if score > best_score or (is_equal_approx(score, best_score) and i < best_place_order):
				best_score = score
				best_place_order = i
				best_command = {
				"action": "walk_to_known_place_%d" % [i + 1],
				"name": str(place.get("name", "place")),
				"position": place.position
			}
	return best_command

func get_direct_route_command(text: String) -> Dictionary:
	var normalized: String = _normalize_text(text)
	if not _has_movement_intent(normalized) and not _has_route_intent(normalized):
		return {}
	var matches: Array[Dictionary] = []
	for i in known_places.size():
		var place: Dictionary = known_places[i]
		var match_info := _place_match_info(normalized, place)
		var match_index := int(match_info.get("index", -1))
		if match_index >= 0:
			matches.append({
				"match_index": match_index,
				"place_index": i,
				"base_key": str(place.get("base_key", _base_place_key(str(place.get("key", ""))))),
				"name": str(place.get("name", "place")),
				"position": place.position,
				"score": float(match_info.get("score", 0.0)),
				"target_type": "place"
			})
	var player_match_index := _route_player_match_index(normalized)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player_match_index >= 0 and player:
		matches.append({
			"match_index": player_match_index,
			"place_index": -1,
			"base_key": "__player",
			"name": "me",
			"position": player.global_position,
			"score": 120.0,
			"target_type": "player"
		})
	if matches.size() < 2:
		return {}
	matches.sort_custom(_sort_place_matches)
	matches = _filter_route_matches(matches)
	var points: Array[Vector3] = []
	var names: Array[String] = []
	var actions: Array[String] = []
	var used_places: Dictionary = {}
	var follow_player_at_end := false
	for entry in matches:
		var place_index := int(entry.get("place_index", -1))
		if place_index >= 0 and used_places.has(place_index):
			continue
		if place_index >= 0:
			used_places[place_index] = true
		points.append(entry.position)
		names.append(str(entry.get("name", "place")))
		if place_index >= 0:
			actions.append("walk_to_known_place_%d" % [place_index + 1])
		follow_player_at_end = str(entry.get("target_type", "")) == "player"
	if points.size() < 2:
		return {}
	return {
		"points": points,
		"names": names,
		"actions": actions,
		"follow_player_at_end": follow_player_at_end
	}

func get_collect_command(text: String, npc_position: Vector3 = Vector3.ZERO) -> Dictionary:
	var normalized: String = _normalize_text(text)
	if not _has_collect_intent(normalized):
		return {}
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_position := player.global_position if player else npc_position
	var source := _collect_source_from_text(normalized, player_position)
	var item_type := _detect_item_type(normalized)
	var collect_all := _wants_all_items(normalized) or item_type == ""
	var explicit_source := bool(source.get("explicit", false))
	var search_radius := COLLECT_SOURCE_RADIUS if explicit_source else COLLECT_NEARBY_RADIUS
	var description := "items"
	if item_type != "":
		description = item_type if not collect_all else "all %s items" % item_type
	if explicit_source:
		description = "%s from %s" % [description, str(source.get("name", "that place"))]
	return {
		"item_type": item_type,
		"collect_all": collect_all,
		"search_center": source.position,
		"search_radius": search_radius,
		"drop_position": player_position,
		"drop_to_player": player != null,
		"explicit_source": explicit_source,
		"source_name": str(source.get("name", "nearby")),
		"description": description
	}

func load_world_memory() -> void:
	known_places.clear()
	var cfg := ConfigFile.new()
	if cfg.load(WORLD_MEMORY_PATH) != OK:
		return
	for i in MAX_KNOWN_PLACES:
		var section := "place_%d" % i
		if not cfg.has_section(section):
			continue
		var key := str(cfg.get_value(section, "key", "")).strip_edges()
		var name := str(cfg.get_value(section, "name", key)).strip_edges()
		var position := Vector3(
			float(cfg.get_value(section, "x", 0.0)),
			float(cfg.get_value(section, "y", 0.0)),
			float(cfg.get_value(section, "z", 0.0))
		)
		if key != "" and name != "":
			known_places.append({
				"key": key,
				"base_key": str(cfg.get_value(section, "base_key", _base_place_key(key))),
				"name_key": str(cfg.get_value(section, "name_key", _place_name_key(name))),
				"name": name,
				"position": position,
				"timestamp": float(cfg.get_value(section, "timestamp", 0.0))
			})

func _save_world_memory() -> void:
	var cfg := ConfigFile.new()
	for i in known_places.size():
		var place: Dictionary = known_places[i]
		var pos: Vector3 = place.position
		var section := "place_%d" % i
		cfg.set_value(section, "key", str(place.get("key", "")))
		cfg.set_value(section, "base_key", str(place.get("base_key", _base_place_key(str(place.get("key", ""))))))
		cfg.set_value(section, "name_key", str(place.get("name_key", _place_name_key(str(place.get("name", ""))))))
		cfg.set_value(section, "name", str(place.get("name", "")))
		cfg.set_value(section, "x", pos.x)
		cfg.set_value(section, "y", pos.y)
		cfg.set_value(section, "z", pos.z)
		cfg.set_value(section, "timestamp", float(place.get("timestamp", _stamp())))
	cfg.save(WORLD_MEMORY_PATH)

func _find_place_slot(base_key: String, name_key: String, position: Vector3) -> int:
	for i in known_places.size():
		var place: Dictionary = known_places[i]
		var place_key := str(place.get("key", ""))
		var place_base_key := str(place.get("base_key", _base_place_key(place_key)))
		var place_name_key := str(place.get("name_key", _place_name_key(str(place.get("name", "")))))
		if place_name_key != name_key:
			continue
		if place_key == base_key or place_base_key == base_key:
			var known_position: Vector3 = place.position
			if known_position.distance_to(position) <= DUPLICATE_PLACE_DISTANCE:
				return i
	return -1

func _place_name_key(raw_name: String) -> String:
	var normalized := _normalize_text(raw_name)
	var words := normalized.split(" ", false)
	var kept: Array[String] = []
	for word in words:
		var piece := str(word).strip_edges()
		if piece == "" or _is_place_tail_stop_word(piece):
			continue
		if ["new", "the", "my", "a", "an", "новый", "новая", "новое", "мой", "моя", "мое"].has(piece):
			continue
		kept.append(piece)
	return "_".join(kept)

func _unique_place_key(base_key: String) -> String:
	var used: Dictionary = {}
	for place in known_places:
		used[str(place.get("key", ""))] = true
	if not used.has(base_key):
		return base_key
	var suffix := 2
	while used.has("%s_%d" % [base_key, suffix]):
		suffix += 1
	return "%s_%d" % [base_key, suffix]

func _base_place_key(key: String) -> String:
	if PLACE_ALIAS_GROUPS.has(key):
		return key
	for alias_key in PLACE_ALIAS_GROUPS.keys():
		var prefix := "%s_" % str(alias_key)
		if key.begins_with(prefix):
			return str(alias_key)
	return key

func _best_memory_position() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_position := player.global_position if player else Vector3.ZERO
	var best_position := player_position
	var best_distance := INF
	for construction in constructions:
		var center: Vector3 = construction.center
		var distance := center.distance_to(player_position)
		if distance < best_distance and distance <= 18.0:
			best_distance = distance
			best_position = center
	return best_position

func _extract_place_name(text: String) -> String:
	var normalized := _normalize_text(text)
	for marker in [
		"запомни это место как ",
		"запомни это как ",
		"запомни место как ",
		"запомни это место это ",
		"запомни что это ",
		"назови это место ",
		"назови это ",
		"запам'ятай це місце як ",
		"запам'ятай це як ",
		"запам'ятай місце як ",
		"запам'ятай що це ",
		"запам ятай це місце як ",
		"запам ятай це як ",
		"запам ятай місце як ",
		"запам ятай що це ",
		"назви це місце ",
		"назви це ",
		"remember this place as ",
		"remember this place is ",
		"remember this as ",
		"remember this is ",
		"call this place ",
		"call this "
	]:
		var explicit_name := _tail_after(normalized, marker)
		if explicit_name != "":
			return _trim_place_name(explicit_name, true)
	for marker in [
		"это новый ",
		"это новая ",
		"это новое ",
		"это мой ",
		"это моя ",
		"это мое ",
		"это ",
		"здесь ",
		"тут ",
		"це новий ",
		"це нова ",
		"це нове ",
		"це мій ",
		"це моя ",
		"це моє ",
		"це ",
		"тут ",
		"здесь ",
		"this is the new ",
		"this is new ",
		"this is my ",
		"this is the ",
		"this is ",
		"here is the ",
		"here is "
	]:
		var name := _tail_after(normalized, marker)
		if name == "":
			continue
		var trimmed := _trim_place_name(name, false)
		if trimmed != "" and _has_known_place_alias(trimmed):
			return trimmed
	return ""

func _tail_after(text: String, marker: String) -> String:
	var at := text.find(marker)
	if at < 0:
		return ""
	return text.substr(at + marker.length()).strip_edges()

func _trim_place_name(text: String, allow_unknown: bool) -> String:
	var words := text.split(" ", false)
	var kept: Array[String] = []
	for raw_word in words:
		var word := str(raw_word).strip_edges()
		if word == "":
			continue
		if _is_place_tail_stop_word(word):
			break
		if ["новый", "новая", "новое", "новий", "нова", "нове", "new", "the", "my", "мой", "моя", "мое", "мій", "моя", "моє", "a", "an"].has(word):
			continue
		kept.append(word)
		if kept.size() >= 4:
			break
	var result := " ".join(kept).strip_edges()
	if allow_unknown:
		return result
	return result if _has_known_place_alias(result) else ""

func _is_place_tail_stop_word(word: String) -> bool:
	return ["и", "і", "та", "а", "но", "але", "пока", "тепер", "теперь", "сейчас", "зараз", "я", "мы", "ми", "and", "but", "while", "now", "please"].has(word)

func _canonical_place_key(raw_name: String) -> String:
	var normalized := _normalize_text(raw_name)
	for key in PLACE_ALIAS_GROUPS.keys():
		for alias in PLACE_ALIAS_GROUPS[key]:
			if _has_word(normalized, str(alias)):
				return str(key)
	var words := normalized.split(" ", false)
	if words.is_empty():
		return ""
	var kept: Array[String] = []
	for word in words:
		var piece := str(word).strip_edges()
		if piece == "" or _is_place_tail_stop_word(piece):
			continue
		kept.append(piece)
		if kept.size() >= 3:
			break
	return "_".join(kept)

func _has_known_place_alias(text: String) -> bool:
	var normalized := _normalize_text(text)
	for key in PLACE_ALIAS_GROUPS.keys():
		for alias in PLACE_ALIAS_GROUPS[key]:
			if _has_word(normalized, str(alias)):
				return true
	return false

func _has_movement_intent(normalized: String) -> bool:
	for word in ["иди", "пойди", "сходи", "вернись", "беги", "отправляйся", "двигайся", "йди", "піди", "сходи", "повернись", "біжи", "рухайся", "go", "walk", "run", "return", "move"]:
		if _has_word(normalized, word):
			return true
	return false

func _has_collect_intent(normalized: String) -> bool:
	for word in ["collect", "gather", "bring", "fetch", "deliver", "pickup", "pick up", "собери", "собрать", "собирай", "принеси", "привези", "доставь", "притащи", "подбери", "возьми", "збери", "збирай", "принеси", "привези", "достав", "підбери", "візьми"]:
		if _has_word(normalized, word):
			return true
	return false

func _wants_all_items(normalized: String) -> bool:
	for word in ["all", "every", "everything", "все", "всё", "всех", "каждый", "каждую", "каждое", "усе", "все", "кожен", "кожну", "кожне"]:
		if _has_word(normalized, word):
			return true
	return false

func _has_route_intent(normalized: String) -> bool:
	if normalized.find(">") >= 0:
		return true
	for word in ["route", "patrol", "waypoints", "маршрут", "патруль", "точки", "обойди", "пройди", "маршрут", "патруль", "точки", "обійди", "пройди"]:
		if _has_word(normalized, word):
			return true
	return false

func _place_matches_text(normalized: String, place: Dictionary) -> bool:
	return _place_match_index(normalized, place) >= 0

func _place_match_index(normalized: String, place: Dictionary) -> int:
	return int(_place_match_info(normalized, place).get("index", -1))

func _place_match_info(normalized: String, place: Dictionary) -> Dictionary:
	var best := -1
	var best_score := -INF
	var key := str(place.get("key", ""))
	var base_key := str(place.get("base_key", _base_place_key(key)))
	var display_name := _normalize_text(str(place.get("name", "")))
	for candidate in [display_name, key.replace("_", " "), base_key.replace("_", " ")]:
		var at := _word_index(normalized, str(candidate))
		var score := 80.0 + _match_specificity(str(candidate))
		if at >= 0 and (score > best_score or (is_equal_approx(score, best_score) and (best < 0 or at < best))):
			best = at
			best_score = score
	var alias_key := _base_place_key(base_key)
	if PLACE_ALIAS_GROUPS.has(alias_key):
		for alias in PLACE_ALIAS_GROUPS[alias_key]:
			var at := _word_index(normalized, str(alias))
			var score := 20.0 + _match_specificity(str(alias))
			if at >= 0 and (score > best_score or (is_equal_approx(score, best_score) and (best < 0 or at < best))):
				best = at
				best_score = score
	return {"index": best, "score": best_score}

func _match_specificity(phrase: String) -> float:
	var normalized := _normalize_text(phrase)
	if normalized == "":
		return 0.0
	var words := normalized.split(" ", false)
	return float(words.size()) * 6.0 + float(normalized.length()) * 0.05

func _route_player_match_index(normalized: String) -> int:
	var best := -1
	for phrase in ["to me", "come to me", "player", "me", "ко мне", "к мне", "сюда", "игрок", "ко игроку", "до мене", "сюди", "гравець", "до гравця"]:
		var at := _word_index(normalized, phrase)
		if at >= 0 and (best < 0 or at < best):
			best = at
	return best

func _sort_place_matches(a: Dictionary, b: Dictionary) -> bool:
	var a_index := int(a.get("match_index", 0))
	var b_index := int(b.get("match_index", 0))
	if a_index == b_index:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	return a_index < b_index

func _filter_route_matches(matches: Array[Dictionary]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for entry in matches:
		var should_add := true
		for i in filtered.size():
			var existing: Dictionary = filtered[i]
			var same_slot := int(existing.get("match_index", -1)) == int(entry.get("match_index", -2))
			var same_base := str(existing.get("base_key", "")) == str(entry.get("base_key", "_"))
			if same_slot and same_base:
				if float(entry.get("score", 0.0)) > float(existing.get("score", 0.0)):
					filtered[i] = entry
				should_add = false
				break
		if should_add:
			filtered.append(entry)
	return filtered

func _collect_source_from_text(normalized: String, fallback_position: Vector3) -> Dictionary:
	if _mentions_island_center(normalized):
		return {
			"name": "center of the island",
			"position": _island_center_position(),
			"explicit": true
		}
	for place in known_places:
		if _place_matches_text(normalized, place):
			return {
				"name": str(place.get("name", "place")),
				"position": place.position,
				"explicit": true
			}
	return {
		"name": "nearby area",
		"position": fallback_position,
		"explicit": false
	}

func _mentions_island_center(normalized: String) -> bool:
	for phrase in ["center of island", "center of the island", "island center", "центр острова", "центра острова", "центре острова", "центр остров", "центр острова", "центрі острова", "центр острову"]:
		if normalized.find(_normalize_text(phrase)) >= 0:
			return true
	return false

func _island_center_position() -> Vector3:
	return Vector3.ZERO

func _detect_item_type(normalized: String) -> String:
	for type_name in ITEM_ALIAS_GROUPS.keys():
		for alias in ITEM_ALIAS_GROUPS[type_name]:
			if _has_word(normalized, str(alias)):
				return str(type_name)
	var defs := PROP_CATALOG.definitions()
	for type_name in defs.keys():
		if _has_word(normalized, str(type_name)):
			return str(type_name)
	return ""

func _normalize_text(text: String) -> String:
	var normalized := text.to_lower()
	for token in [".", ",", "!", "?", ":", ";", "\"", "'", "«", "»", "(", ")", "[", "]", "{", "}", "\n", "\t", "-", "—"]:
		normalized = normalized.replace(token, " ")
	while normalized.find("  ") >= 0:
		normalized = normalized.replace("  ", " ")
	return normalized.strip_edges()

func _has_word(text: String, word: String) -> bool:
	return _word_index(text, word) >= 0

func _word_index(text: String, word: String) -> int:
	var clean_word := _normalize_text(word)
	if clean_word == "":
		return -1
	return (" %s " % text).find(" %s " % clean_word)

func _remember(line: String) -> void:
	conversation_memory.append(line)
	while conversation_memory.size() > 60:
		conversation_memory.pop_front()

func _rebuild_constructions() -> void:
	constructions.clear()
	var visited: Dictionary = {}
	for object in spawned_objects:
		if visited.has(object.id):
			continue
		var cluster: Array[Dictionary] = []
		for other in spawned_objects:
			var p1: Vector3 = object.position
			var p2: Vector3 = other.position
			if p1.distance_to(p2) <= 3.0:
				cluster.append(other)
		if cluster.size() >= 3:
			var center: Vector3 = Vector3.ZERO
			for item in cluster:
				visited[item.id] = true
				center += item.position
			center /= float(cluster.size())
			constructions.append({"objects": cluster, "center": center})

func _action_text(entry: Dictionary) -> String:
	var action: String = str(entry.get("action", "did something"))
	var details: Dictionary = entry.get("details", {})
	if details.has("object"):
		return "%s %s" % [action, _object_display_name(str(details.object))]
	if details.has("place"):
		return "%s %s" % [action, details.place]
	if details.has("text"):
		return "said \"%s\"" % details.text
	return action

func _plural(name: String, count: int) -> String:
	return name if count == 1 else "%ss" % name

func _object_display_name(type_name: String) -> String:
	return PROP_CATALOG.display_name(type_name)

func _music_display_name(style: String) -> String:
	match style:
		"Jaz":
			return "Jazz"
		"Chiled":
			return "Chill"
	return style

func _stamp() -> float:
	return Time.get_ticks_msec() / 1000.0
