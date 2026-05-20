extends Node

class_name PlayerAudio

var step_player: AudioStreamPlayer
var jump_player: AudioStreamPlayer
var land_player: AudioStreamPlayer

func _ready() -> void:
	step_player = _player()
	jump_player = _player()
	land_player = _player()

func _exit_tree() -> void:
	for player in [step_player, jump_player, land_player]:
		if player:
			player.stop()
			player.stream = null

func play_step(running: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var pitch := randf_range(0.86, 1.08) * (1.08 if running else 1.0)
	step_player.stream = _sound(randf_range(78.0, 116.0), 0.075, 0.13 if running else 0.09, 0.86)
	step_player.pitch_scale = pitch
	step_player.play()

func play_jump() -> void:
	if DisplayServer.get_name() == "headless":
		return
	jump_player.stream = _sound(190.0, 0.12, 0.14, 0.35)
	jump_player.pitch_scale = randf_range(0.95, 1.08)
	jump_player.play()

func play_land() -> void:
	if DisplayServer.get_name() == "headless":
		return
	land_player.stream = _sound(72.0, 0.16, 0.18, 0.96)
	land_player.pitch_scale = randf_range(0.82, 1.0)
	land_player.play()

func _player() -> AudioStreamPlayer:
	var node := AudioStreamPlayer.new()
	node.bus = GameState.SFX_BUS
	add_child(node)
	return node

func _sound(freq: float, duration: float, volume: float, noise: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(duration * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var decay := pow(1.0 - float(i) / float(frames), 2.2)
		var wave := sin(t * TAU * freq) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		var sample := int(clamp(wave * decay * volume, -1.0, 1.0) * 32767.0)
		data[i * 2] = sample & 0xff
		data[i * 2 + 1] = (sample >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
