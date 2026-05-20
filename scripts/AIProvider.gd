extends RefCounted

class_name AIProvider

static func build_request(prompt: String, image_data: String, response_schema: Dictionary = {}) -> Dictionary:
	var config := GameState.get_brain_config()
	match str(config.provider):
		"openrouter":
			return _openai_request(config, prompt, image_data, "openai")
		"ollama":
			return _ollama_request(config, prompt, image_data)
		"lmstudio":
			return _openai_request(config, prompt, image_data, "openai")
	return _google_request(config, prompt, image_data, response_schema)

static func extract_text(data: Dictionary, parser: String) -> String:
	if parser == "google":
		var candidates: Array = data.get("candidates", [])
		if candidates.is_empty():
			var error_msg: Variant = data.get("error", {})
			if typeof(error_msg) == TYPE_DICTIONARY:
				printerr("[AIProvider] Google API error: %s | Full details: %s" % [str(error_msg.get("message", "unknown")), JSON.stringify(error_msg)])
			var prompt_feedback: Dictionary = data.get("promptFeedback", {})
			if not prompt_feedback.is_empty():
				printerr("[AIProvider] Google API prompt blocked: %s" % JSON.stringify(prompt_feedback))
			if typeof(error_msg) != TYPE_DICTIONARY and prompt_feedback.is_empty():
				printerr("[AIProvider] Google API Error, no candidates returned. Data: %s" % JSON.stringify(data))
			return ""
		var content: Dictionary = candidates[0].get("content", {})
		var parts: Array = content.get("parts", [])
		var pieces: Array[String] = []
		for part in parts:
			if typeof(part) == TYPE_DICTIONARY and part.has("text"):
				pieces.append(str(part.get("text", "")))
		return "\n".join(pieces).strip_edges()
	if parser == "ollama":
		var message: Dictionary = data.get("message", {})
		return str(message.get("content", data.get("response", ""))).strip_edges()
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		var error_msg: Variant = data.get("error", {})
		if typeof(error_msg) == TYPE_DICTIONARY:
			printerr("[AIProvider] OpenAI-style API error: %s | Full details: %s" % [str(error_msg.get("message", "unknown")), JSON.stringify(error_msg)])
		else:
			printerr("[AIProvider] API Error, no choices returned. Data: %s" % JSON.stringify(data))
		return ""
	var message: Dictionary = choices[0].get("message", {})
	return str(message.get("content", "")).strip_edges()

static func _google_request(config: Dictionary, prompt: String, image_data: String, response_schema: Dictionary) -> Dictionary:
	var url := "%s/models/%s:generateContent?key=%s" % [str(config.base_url).trim_suffix("/"), str(config.model).uri_encode(), str(config.api_key).uri_encode()]
	var parts: Array = []
	if image_data != "":
		parts.append({"inline_data": {"mime_type": "image/jpeg", "data": image_data}})
	parts.append({"text": prompt})
	var generation_config := {
		"temperature": 0.25,
		"max_output_tokens": 240,
		"response_mime_type": "application/json"
	}
	if not response_schema.is_empty():
		generation_config["response_schema"] = response_schema
	var payload := {
		"contents": [{"role": "user", "parts": parts}],
		"generationConfig": generation_config
	}
	return {"url": url, "headers": PackedStringArray(["Content-Type: application/json"]), "body": JSON.stringify(payload), "parser": "google"}

static func _openai_request(config: Dictionary, prompt: String, image_data: String, parser: String) -> Dictionary:
	var content: Variant = prompt
	if image_data != "":
		var parts: Array = [{"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,%s" % image_data}}]
		parts.append({"type": "text", "text": prompt})
		content = parts
	var payload := {
		"model": str(config.model),
		"messages": [{"role": "user", "content": content}],
		"temperature": 0.45,
		"response_format": {"type": "json_object"}
	}
	var headers := PackedStringArray(["Content-Type: application/json"])
	if str(config.api_key).strip_edges() != "":
		headers.append("Authorization: Bearer %s" % str(config.api_key).strip_edges())
	if str(config.provider) == "openrouter":
		headers.append("HTTP-Referer: https://ai-sandbox.local")
		headers.append("X-Title: AI Sandbox")
	return {"url": str(config.base_url), "headers": headers, "body": JSON.stringify(payload), "parser": parser}

static func _ollama_request(config: Dictionary, prompt: String, image_data: String) -> Dictionary:
	var message := {"role": "user", "content": prompt}
	if image_data != "":
		message["images"] = [image_data]
	var payload := {
		"model": str(config.model),
		"stream": false,
		"format": "json",
		"messages": [message],
		"options": {"temperature": 0.45}
	}
	return {"url": str(config.base_url), "headers": PackedStringArray(["Content-Type: application/json"]), "body": JSON.stringify(payload), "parser": "ollama"}
