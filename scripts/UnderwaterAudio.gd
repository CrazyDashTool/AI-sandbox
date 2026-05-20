extends Node

class_name UnderwaterAudio

const BUS_NAME := "Master"
const MAX_MUFFLE_DB := -8.0
const DRY_CUTOFF := 20500.0
const SHALLOW_CUTOFF := 1650.0
const DEEP_CUTOFF := 520.0

var bus_index := -1
var effect_index := -1
var filter: AudioEffectLowPassFilter
var target_amount := 0.0
var current_amount := 0.0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	bus_index = AudioServer.get_bus_index(BUS_NAME)
	if bus_index < 0:
		set_process(false)
		return
	filter = AudioEffectLowPassFilter.new()
	filter.cutoff_hz = DRY_CUTOFF
	filter.resonance = 0.65
	effect_index = AudioServer.get_bus_effect_count(bus_index)
	AudioServer.add_bus_effect(bus_index, filter, effect_index)
	AudioServer.set_bus_effect_enabled(bus_index, effect_index, false)

func _exit_tree() -> void:
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, GameState.master_volume_db())
	if effect_index >= 0 and effect_index < AudioServer.get_bus_effect_count(bus_index):
		AudioServer.remove_bus_effect(bus_index, effect_index)

func update_from_water(camera: Camera3D, water_state) -> void:
	if not camera or not water_state or not bool(water_state.active):
		target_amount = 0.0
		return
	var depth: float = float(water_state.surface_y) - camera.global_position.y
	target_amount = clamp((depth - 0.05) / 3.6, 0.0, 1.0)

func _process(delta: float) -> void:
	if bus_index < 0 or not filter:
		return
	current_amount = lerp(current_amount, target_amount, min(1.0, delta * 3.8))
	var wet: float = smoothstep(0.0, 1.0, current_amount)
	if effect_index >= 0 and effect_index < AudioServer.get_bus_effect_count(bus_index):
		AudioServer.set_bus_effect_enabled(bus_index, effect_index, wet > 0.01)
	filter.cutoff_hz = lerp(DRY_CUTOFF, lerp(SHALLOW_CUTOFF, DEEP_CUTOFF, wet), wet)
	filter.resonance = lerp(0.65, 1.28, wet)
	AudioServer.set_bus_volume_db(bus_index, GameState.master_volume_db() + MAX_MUFFLE_DB * wet)
