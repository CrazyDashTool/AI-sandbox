extends Node

const AI_PROVIDER := preload("res://scripts/AIProvider.gd")
const ACTIONS := ["idle", "walk_to_player", "walk_to_construction_1", "walk_to_construction_2", "walk_to_construction_3", "walk_to_known_place_1", "walk_to_known_place_2", "walk_to_known_place_3", "walk_to_known_place_4", "walk_to_known_place_5", "walk_to_known_place_6", "walk_to_known_place_7", "walk_to_known_place_8", "walk_to_known_place_9", "walk_to_known_place_10", "walk_to_known_place_11", "walk_to_known_place_12", "look_at_player", "jump", "run_away", "sit", "sit_on_bench", "sit_on_chair", "relax_on_blanket", "wave", "look_around", "use_weapon", "build_random_prop", "build_and_pin_prop", "move_nearby_item", "pin_nearby_item", "rotate_nearby_item", "throw_nearby_item", "use_nearby_item", "swim_in_water"]
const EMOTIONS := ["neutral", "happy", "surprised", "scared", "curious", "annoyed"]
const VISION_CAPTURE_WIDTH := 1280
const VISION_JPEG_QUALITY := 0.78
const DIRECT_ACTION_DELAY := 0.75

var request: HTTPRequest
var timer: Timer
var npc: Node
var in_flight := false
var retry_reason := ""
var thinking_since := 0.0
var active_parser := "google"
var retrying := false
var vision_viewport: SubViewport
var vision_camera: Camera3D
var direct_command_serial := 0

func _ready() -> void:
	add_to_group("npc_brain")
	request = HTTPRequest.new()
	request.timeout = 0.0
	request.use_threads = true
	add_child(request)
	request.request_completed.connect(_on_request_completed)
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_timer)
	await get_tree().process_frame
	npc = get_parent()
	_setup_vision_camera()
	GameState.chat_sent.connect(_on_player_chat_sent)
	_schedule_next()

func _process(_delta: float) -> void:
	_sync_vision_camera()

func request_think_now(reason := "") -> void:
	if in_flight:
		return
	if not GameState.is_brain_configured():
		printerr("[NPCBrain] Cannot generate request: AI Brain is not configured or disabled.")
		return
	timer.stop()
	_think(reason)

func _think(reason: String) -> void:
	if in_flight:
		return
	if not GameState.is_brain_configured():
		printerr("[NPCBrain] Cannot generate request: AI Brain is not configured or disabled.")
		retrying = false
		_schedule_next()
		return
	in_flight = true
	if not retrying:
		thinking_since = Time.get_ticks_msec() / 1000.0
	if not npc:
		npc = get_parent()
	if npc and npc.has_method("set_thinking"):
		npc.set_thinking(true)
	retry_reason = reason
	var config := GameState.get_brain_config()
	var image_data := _capture_jpeg_base64()
	var prompt := _build_prompt(reason, image_data != "")
	var req := AI_PROVIDER.build_request(prompt, image_data, _decision_schema())
	active_parser = str(req.parser)
	var body_kb := str(req.body).length() / 1024.0
	var image_state := "npc_camera" if image_data != "" else "no"
	print("[NPCBrain] Sending request to %s | provider=%s | parser=%s | image=%s | body=%.1f KB" % [str(req.url).left(80), str(config.provider), active_parser, image_state, body_kb])
	var error := request.request(req.url, req.headers, HTTPClient.METHOD_POST, req.body)
	if error != OK:
		printerr("[NPCBrain] HTTPRequest.request() failed with error code: %d" % error)
		in_flight = false
		_retry_after_error()

func _build_prompt(reason: String, image_available: bool) -> String:
	var recent := WorldContext.get_recent_actions_text(5)
	var speech := WorldContext.player_speech if WorldContext.player_speech != "" else "nothing"
	var known_places := WorldContext.get_known_places_text(12)
	var seconds_since_player_speech := WorldContext.get_seconds_since_player_speech()
	var movement_status := _movement_status_text()
	var image_state := "available from your own eye-level NPC camera" if image_available else "not available"
	if reason != "":
		recent = "%s, %s" % [recent, reason]
	return "You are an NPC living in a 3D sandbox world. Pick one natural in-world reaction.\nReturn exactly one JSON object with keys visual_observation, speech, action, and emotion. Do not include markdown, bullets, labels, analysis, or the prompt text.\nLANGUAGE: reply in the same language as the player. If the player mixes languages, use the language of their latest request.\nVISION FIRST: an image is %s. Treat the image as primary evidence. Use the text world state only as memory/context. If image and text disagree, trust the image. visual_observation must name concrete visible things from the image in 4-16 words, or say \"no image\" if there is no image. Base speech and action on what you visually see whenever the player's message asks about the scene, nearby objects, obstacles, places, or what is in front of you.\nAWARENESS: know what you are doing right now from Movement status. Known places are persistent map memory with coordinates and action ids. If you choose to walk, say the destination before moving. If the player asks for a route, mention the route order in speech.\nCapabilities: %s\nRules: speech is non-empty and 1-3 short sentences. Do not claim you see something unless it is visible in the image or explicitly in recent memory. Weapons are harmless tools here. Nobody can die. If the player asks you to go to a remembered place, choose the matching walk_to_known_place_N action and do not follow the player instead. If the player asks you to look at them or inspect what they show, choose look_at_player. If the player asks you to sit on or use a bench, choose sit_on_bench. If the player asks you to sit on or use a chair, choose sit_on_chair. If the player asks you to lie down, rest on, or use a blanket/pled, choose relax_on_blanket. Do not choose run_away just because the player walks toward you or stands close; choose run_away only after an explicit request for distance or a clear threat.\nValid actions: %s.\nValid emotions: %s.\nKnown places: %s\nMovement status: %s\nTime since player last spoke: %.1f seconds.\nWorld state: %s\nRecent conversation memory: %s\nRecent player actions: %s\nPlayer said: \"%s\"" % [image_state, _capabilities_text(), ", ".join(ACTIONS), ", ".join(EMOTIONS), known_places, movement_status, seconds_since_player_speech, WorldContext.get_world_summary(), _recent_conversation_memory(10), recent, speech]

func _capabilities_text() -> String:
	return "speak, look with your own camera, remember named places, walk to remembered places, follow multi-point routes, stay in place, keep near the player when asked, run away/give space, avoid obstacles, jump while walking, swim/escape water, inspect builds, collect and bring nearby or typed items, sit/use benches and chairs, rest on blankets, build/spawn/pin/rotate/move/throw/use sandbox props."

func _recent_conversation_memory(count: int) -> String:
	var memory := str(WorldContext.get_conversation_memory())
	if memory == "" or memory == "none":
		return "none"
	var lines := memory.split("\n", false)
	if count <= 0 or lines.size() <= count:
		return memory
	var start: int = max(0, lines.size() - count)
	var recent_lines: Array[String] = []
	for i in range(start, lines.size()):
		recent_lines.append(lines[i])
	return "\n".join(recent_lines)

func _movement_status_text() -> String:
	if not npc:
		npc = get_parent()
	if npc and npc.has_method("get_movement_status_text"):
		return npc.get_movement_status_text()
	return "unknown"

func _capture_jpeg_base64() -> String:
	if not _sync_vision_camera():
		return ""
	var texture := vision_viewport.get_texture()
	if not texture:
		return ""
	var image := texture.get_image()
	if not image:
		return ""
	var width: int = max(1, image.get_width())
	var height: int = max(1, image.get_height())
	var target_width: int = VISION_CAPTURE_WIDTH
	var target_height: int = int(float(height) * float(target_width) / float(width))
	image.resize(target_width, target_height, Image.INTERPOLATE_BILINEAR)
	var bytes: PackedByteArray = image.save_jpg_to_buffer(VISION_JPEG_QUALITY)
	return Marshalls.raw_to_base64(bytes)

func _setup_vision_camera() -> void:
	if DisplayServer.get_name() == "headless":
		return
	vision_viewport = SubViewport.new()
	vision_viewport.name = "NPCVisionViewport"
	vision_viewport.size = Vector2i(1280, 720)
	vision_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vision_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vision_viewport.world_3d = get_viewport().world_3d
	add_child(vision_viewport)
	vision_camera = Camera3D.new()
	vision_camera.name = "NPCVisionCamera"
	vision_camera.current = true
	vision_camera.fov = 75.0
	vision_camera.near = 0.05
	vision_camera.far = 120.0
	vision_viewport.add_child(vision_camera)
	_sync_vision_camera()

func _sync_vision_camera() -> bool:
	if not vision_viewport or not vision_camera:
		return false
	var main_viewport := get_viewport()
	if not main_viewport:
		return false
	vision_viewport.world_3d = main_viewport.world_3d
	if not npc:
		npc = get_parent()
	if npc and npc.has_method("get_brain_camera_transform"):
		vision_camera.global_transform = npc.get_brain_camera_transform()
	elif npc is Node3D:
		var node := npc as Node3D
		vision_camera.global_transform = node.global_transform
	else:
		return false
	return true

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var elapsed := Time.get_ticks_msec() / 1000.0 - thinking_since
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var body_preview := body.get_string_from_utf8().left(1000) if body.size() > 0 else "<empty>"
		printerr("[NPCBrain] Request FAILED | result=%d | http=%d | elapsed=%.1fs | body=%s" % [result, response_code, elapsed, body_preview])
		in_flight = false
		if _should_retry_request(result, response_code):
			_retry_after_error()
		else:
			retrying = false
			_schedule_cooldown(60.0)
		return
	var body_text := body.get_string_from_utf8()
	var data = JSON.parse_string(body_text)
	if typeof(data) != TYPE_DICTIONARY:
		printerr("[NPCBrain] Response is not valid JSON | elapsed=%.1fs | body=%s" % [elapsed, body_text.left(300)])
		in_flight = false
		retrying = false
		_schedule_cooldown(60.0)
		return
	var text := AI_PROVIDER.extract_text(data, active_parser)
	var decision := _parse_decision(text)
	var used_fallback := false
	if decision.is_empty():
		printerr("[NPCBrain] Could not parse decision from AI response | elapsed=%.1fs | text=%s" % [elapsed, text.left(300)])
		decision = _fallback_decision(text)
		used_fallback = true
	var status := "fallback" if used_fallback else "OK"
	print("[NPCBrain] Response %s | elapsed=%.1fs | action=%s | vision=%s | speech=%s" % [status, elapsed, decision.get("action", "?"), str(decision.get("visual_observation", "")).left(60), str(decision.get("speech", "?")).left(60)])
	await _hold_min(2.1)
	in_flight = false
	retrying = false
	_apply_decision(decision)
	if used_fallback:
		_schedule_cooldown(30.0)
	else:
		_schedule_cooldown(60.0)

func _hold_min(seconds: float) -> void:
	var elapsed := Time.get_ticks_msec() / 1000.0 - thinking_since
	var left := seconds - elapsed
	if left > 0.0:
		await get_tree().create_timer(left).timeout

func _decision_schema() -> Dictionary:
	return {
		"type": "OBJECT",
		"properties": {
			"speech": {
				"type": "STRING",
				"description": "NPC speech, non-empty, one to three short sentences."
			},
			"visual_observation": {
				"type": "STRING",
				"description": "Four to sixteen words naming concrete visible things from the camera image, or no image."
			},
			"action": {
				"type": "STRING",
				"enum": ACTIONS
			},
			"emotion": {
				"type": "STRING",
				"enum": EMOTIONS
			}
		},
		"required": ["visual_observation", "speech", "action", "emotion"],
		"propertyOrdering": ["visual_observation", "speech", "action", "emotion"]
	}

func _parse_decision(text: String) -> Dictionary:
	var cleaned := text.replace("```json", "").replace("```", "").strip_edges()
	var parsed = JSON.parse_string(cleaned)
	if typeof(parsed) != TYPE_DICTIONARY:
		var object_text := _extract_first_json_object(cleaned)
		if object_text != "":
			parsed = JSON.parse_string(object_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var action := str(parsed.get("action", "idle"))
	var emotion := str(parsed.get("emotion", "neutral"))
	var visual_observation := _clean_visual_observation(parsed.get("visual_observation", ""))
	if not ACTIONS.has(action):
		action = "idle"
	if not EMOTIONS.has(emotion):
		emotion = "neutral"
	return {"visual_observation": visual_observation, "speech": _clean_speech(parsed.get("speech", "")), "action": action, "emotion": emotion}

func _clean_visual_observation(value: Variant) -> String:
	var observation := str(value).strip_edges().replace("\n", " ")
	while observation.find("  ") >= 0:
		observation = observation.replace("  ", " ")
	if observation.length() > 120:
		observation = observation.left(120).strip_edges()
	return observation if observation != "" else "no visual observation"

func _extract_first_json_object(text: String) -> String:
	var start := -1
	var depth := 0
	var in_string := false
	var escaped := false
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		if start == -1:
			if ch == "{":
				start = i
				depth = 1
			continue
		if in_string:
			if escaped:
				escaped = false
			elif ch == "\\":
				escaped = true
			elif ch == "\"":
				in_string = false
			continue
		if ch == "\"":
			in_string = true
		elif ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				return text.substr(start, i - start + 1)
	return ""

func _clean_speech(value: Variant) -> String:
	var speech := str(value).strip_edges().replace("\n", " ")
	while speech.find("  ") >= 0:
		speech = speech.replace("  ", " ")
	if speech.length() > 180:
		speech = speech.left(180).strip_edges()
	return speech if speech != "" else "I need a moment to think."

func _fallback_decision(raw_text: String) -> Dictionary:
	var speech := "I got a little scrambled, but I am still here."
	if raw_text.strip_edges() == "":
		speech = "I need a moment to think."
	return {"visual_observation": "no reliable visual observation", "speech": speech, "action": "look_around", "emotion": "curious"}

func _should_retry_request(result: int, response_code: int) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS:
		return true
	if response_code == 408 or response_code == 409 or response_code == 425 or response_code == 429:
		return true
	return response_code >= 500

func _apply_decision(decision: Dictionary) -> void:
	if npc and npc.has_method("set_thinking"):
		npc.set_thinking(false)
	if npc and npc.has_method("on_brain_decision"):
		npc.on_brain_decision(decision)

func _on_player_chat_sent(text: String) -> void:
	direct_command_serial += 1
	var prop_interaction_action := _direct_prop_interaction_action(text)
	if prop_interaction_action != "":
		_apply_prop_interaction_command(prop_interaction_action)
		return
	if _is_flee_request(text):
		_apply_flee_command()
		return
	var collect_command: Dictionary = WorldContext.get_collect_command(text, _npc_position())
	if not collect_command.is_empty():
		_apply_collect_command(collect_command)
		return
	var route_command: Dictionary = WorldContext.get_direct_route_command(text)
	if not route_command.is_empty():
		_apply_route_command(route_command)
		return
	var place_command: Dictionary = WorldContext.get_direct_place_command(text)
	if not place_command.is_empty():
		_apply_direct_place_command(place_command)
		return
	if _is_stay_request(text):
		_apply_stay_command()
		return
	if _is_look_request(text):
		_apply_look_command(text)
		return
	request_think_now("Player said: %s" % text)

func _npc_position() -> Vector3:
	if npc and npc is Node3D:
		return (npc as Node3D).global_position
	return Vector3.ZERO

func _begin_direct_command() -> int:
	direct_command_serial += 1
	timer.stop()
	_cancel_active_request()
	retrying = false
	if npc and npc.has_method("set_thinking"):
		npc.set_thinking(false)
	return direct_command_serial

func _wait_before_direct_movement(token: int) -> bool:
	await get_tree().create_timer(DIRECT_ACTION_DELAY).timeout
	return token == direct_command_serial

func _apply_direct_place_command(command: Dictionary) -> void:
	_begin_direct_command()
	var place_name := str(command.get("name", "место"))
	WorldContext.remember_npc_intent("Go to %s using %s." % [place_name, str(command.get("action", "idle"))])
	_apply_decision({
		"speech": _direct_speech("go_place", place_name),
		"action": str(command.get("action", "idle")),
		"emotion": "neutral"
	})
	_schedule_cooldown(12.0)

func _apply_route_command(command: Dictionary) -> void:
	var token := _begin_direct_command()
	var names: Array = command.get("names", [])
	var route_text := "the route"
	if not names.is_empty():
		route_text = " -> ".join(names)
	WorldContext.remember_npc_intent("Follow route %s." % route_text)
	_apply_decision({
		"speech": _direct_speech("route", route_text),
		"action": "idle",
		"emotion": "neutral"
	})
	if not (await _wait_before_direct_movement(token)):
		return
	if npc and npc.has_method("start_route"):
		npc.start_route(command.get("points", []), command.get("names", []), bool(command.get("follow_player_at_end", false)))
	_schedule_cooldown(12.0)

func _apply_collect_command(command: Dictionary) -> void:
	var token := _begin_direct_command()
	var description := str(command.get("description", "items"))
	WorldContext.remember_npc_intent("Collect and bring %s." % description)
	_apply_decision({
		"speech": _direct_speech("collect", description),
		"action": "idle",
		"emotion": "curious"
	})
	if not (await _wait_before_direct_movement(token)):
		return
	if npc and npc.has_method("start_collect_task"):
		npc.start_collect_task(command)
	_schedule_cooldown(12.0)

func _apply_stay_command() -> void:
	_begin_direct_command()
	WorldContext.remember_npc_intent("Stay at the current position.")
	_apply_decision({
		"speech": _direct_speech("stay"),
		"action": "idle",
		"emotion": "neutral"
	})
	_schedule_cooldown(12.0)

func _apply_look_command(text: String) -> void:
	var token := _begin_direct_command()
	WorldContext.remember_npc_intent("Look at the player before answering.")
	_apply_decision({
		"speech": _direct_speech("look"),
		"action": "look_at_player",
		"emotion": "curious"
	})
	await get_tree().create_timer(0.45).timeout
	if token != direct_command_serial:
		return
	request_think_now("Player asked NPC to look at them before answering: %s" % text)

func _apply_prop_interaction_command(action: String) -> void:
	_begin_direct_command()
	var kind := "bench"
	if action == "relax_on_blanket":
		kind = "blanket"
	elif action == "sit_on_chair":
		kind = "chair"
	var speech := _direct_speech(kind)
	WorldContext.remember_npc_intent("Use %s." % kind)
	_apply_decision({
		"speech": speech,
		"action": action,
		"emotion": "curious" if action == "relax_on_blanket" else "happy"
	})
	_schedule_cooldown(12.0)

func _apply_flee_command() -> void:
	_begin_direct_command()
	WorldContext.remember_npc_intent("Move away from the player and keep distance.")
	_apply_decision({
		"speech": _direct_speech("flee"),
		"action": "run_away",
		"emotion": "scared"
	})
	_schedule_cooldown(12.0)

func _direct_speech(kind: String, detail: String = "") -> String:
	var lang := _detect_player_language(WorldContext.player_speech)
	match lang:
		"uk":
			match kind:
				"go_place":
					return "Іду до %s." % detail
				"route":
					return "Зрозумів, пройду маршрут: %s." % detail
				"collect":
					return "Зрозумів, принесу %s." % detail
				"stay":
					return "Залишаюся тут."
				"look":
					return "Дивлюся."
				"bench":
					return "Добре, скористаюся лавкою."
				"blanket":
					return "Добре, відпочину на ковдрі."
				"flee":
					return "Добре, відійду і дам тобі простір."
		"ru":
			match kind:
				"go_place":
					return "Иду к %s." % detail
				"route":
					return "Понял, пройду маршрут: %s." % detail
				"collect":
					return "Понял, принесу %s." % detail
				"stay":
					return "Останусь здесь."
				"look":
					return "Смотрю."
				"bench":
					return "Хорошо, воспользуюсь лавкой."
				"blanket":
					return "Хорошо, отдохну на пледе."
				"flee":
					return "Хорошо, отойду и дам тебе место."
	match kind:
		"go_place":
			return "I am going to %s." % detail
		"route":
			return "Okay, I will follow %s." % detail
		"collect":
			return "Okay, I will bring %s." % detail
		"stay":
			return "I will stay here."
		"look":
			return "I am looking."
		"bench":
			return "Okay, I will use the bench."
		"chair":
			return "Okay, I will use the chair."
		"blanket":
			return "Okay, I will rest on the blanket."
		"flee":
			return "Okay, I will give you space."
	return "Okay."

func _detect_player_language(text: String) -> String:
	var normalized := text.to_lower()
	if _contains_any(normalized, ["і", "ї", "є", "ґ", "зрозум", "будь ласка", "до мене", "сюди", "йди", "піди", "збери", "місце", "дім", "будинок"]):
		return "uk"
	for i in normalized.length():
		var code := normalized.unicode_at(i)
		if code >= 0x0400 and code <= 0x04FF:
			return "ru"
	return "en"

func _cancel_active_request() -> void:
	if in_flight:
		request.cancel_request()
		in_flight = false

func _is_look_request(text: String) -> bool:
	var normalized := _normalize_command(text)
	for phrase in ["look at me", "look here", "look this", "turn to me", "watch me", "take a screenshot", "screenshot", "посмотри", "смотри", "взгляни", "глянь", "поверни голову", "сделай скрин", "скриншот", "подивись", "дивись", "глянь", "поверни голову", "зроби скрин", "скриншот"]:
		if normalized.find(phrase) >= 0:
			return true
	return false

func _is_stay_request(text: String) -> bool:
	var normalized := _normalize_command(text)
	for phrase in ["stay here", "stand still", "wait here", "dont follow", "don't follow", "stop following", "стой", "останься", "жди здесь", "не ходи", "не иди", "не следуй", "стой тут", "стій", "залишайся", "чекай тут", "не йди", "не ходи", "не слідуй", "стій тут"]:
		if normalized.find(phrase) >= 0:
			return true
	return false

func _is_flee_request(text: String) -> bool:
	var normalized := _normalize_command(text)
	if _contains_any(normalized, ["dont go away", "don't go away", "dont run", "don't run", "не уходи", "не убегай", "не отходи", "не йди", "не тікай", "не відходь"]):
		return false
	return _contains_any(normalized, ["go away", "run away", "move away", "step back", "leave me", "give me space", "отойди", "уйди", "убегай", "отбеги", "не подходи", "держись дальше", "дай место", "відійди", "йди геть", "тікай", "відбіжи", "не підходь", "тримайся далі", "дай місце", "дай простір"])

func _direct_prop_interaction_action(text: String) -> String:
	var normalized_for_chair := _normalize_command(text)
	var wants_chair_direct := _contains_any(normalized_for_chair, ["chair", "stul", "stool", "стул", "стульчик", "стулья", "стілець", "стільчик"])
	var wants_sit_direct := _contains_any(normalized_for_chair, ["sit", "seat", "use", "сяд", "посид", "присяд", "использ", "використ"])
	if wants_chair_direct and wants_sit_direct:
		return "sit_on_chair"
	var normalized := _normalize_command(text)
	var wants_bench := _contains_any(normalized, ["bench", "lavoch", "skame", "лавоч", "скамей", "скаме", "лавк", "лавоч"])
	var wants_blanket := _contains_any(normalized, ["blanket", "pled", "beach mat", "плед", "одеял", "коврик", "ковдр", "килимок"])
	var wants_sit := _contains_any(normalized, ["sit", "seat", "use", "сяд", "посид", "присяд", "использ", "сядь", "посидь", "присядь", "використ"])
	var wants_rest := _contains_any(normalized, ["lie", "lay", "rest", "relax", "use", "ляг", "полеж", "отдох", "использ", "ляж", "полеж", "відпоч", "використ"])
	if wants_bench and wants_sit:
		return "sit_on_bench"
	if wants_blanket and wants_rest:
		return "relax_on_blanket"
	return ""

func _contains_any(text: String, phrases: Array) -> bool:
	for phrase in phrases:
		if text.find(str(phrase)) >= 0:
			return true
	return false

func _normalize_command(text: String) -> String:
	var normalized := text.to_lower()
	for token in [".", ",", "!", "?", ":", ";", "\"", "'", "«", "»", "(", ")", "[", "]", "{", "}", "\n", "\t", "-", "—"]:
		normalized = normalized.replace(token, " ")
	while normalized.find("  ") >= 0:
		normalized = normalized.replace("  ", " ")
	return normalized.strip_edges()

func _api_error() -> void:
	_retry_after_error()

func _retry_after_error() -> void:
	if not GameState.is_brain_configured():
		retrying = false
		if npc and npc.has_method("set_thinking"):
			npc.set_thinking(false)
		return
	retrying = true
	print("[NPCBrain] Will retry in 3 seconds...")
	if npc and npc.has_method("set_thinking"):
		npc.set_thinking(true)
	timer.start(3.0)

func _schedule_next() -> void:
	if npc and npc.has_method("set_thinking"):
		npc.set_thinking(false)
	var wait: float = max(2.0, 60.0 - WorldContext.get_idle_seconds())
	timer.start(wait)

func _schedule_cooldown(seconds: float) -> void:
	if npc and npc.has_method("set_thinking"):
		npc.set_thinking(false)
	timer.start(max(2.0, seconds))

func _on_timer() -> void:
	if in_flight:
		timer.start(1.0)
	elif retrying:
		_think(retry_reason)
	elif WorldContext.get_idle_seconds() >= 60.0:
		_think("The player has been idle for a minute. Decide what to do on your own.")
	else:
		_schedule_next()
