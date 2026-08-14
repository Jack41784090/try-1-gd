class_name ClockSystem
extends Node

var _accumulator: float = 0.0
var is_paused: bool = false:
	set(_p):
		is_paused = _p	
		pause_state_changed.emit(is_paused)
var current_hour: int = 0:
	set(_p):
		current_hour = _p	
		hour_changed.emit(current_hour)
@export var hours_per_second := 1.0:
	set(v):
		hours_per_second = v
		speed_changed.emit(v)

signal hour_changed(hour_now: int)
signal pause_state_changed(paused: bool)
signal speed_changed(speed: float)

func _enter_tree() -> void:
	LogGd.pr("entered tree")
	assert(get_parent().name == &"Systems")

func _process(delta: float) -> void:
	if not is_paused:
		_accumulator += delta * hours_per_second
		while _accumulator >= 1.0:
			_accumulator -= 1.0
			current_hour += 1

func pause() -> void:
	is_paused = true

func unpause() -> void:
	is_paused = false

func toggle_pause() -> void:
	is_paused = not is_paused

func force_tick() -> void:
	current_hour += 1

func set_speed(hps: float) -> void:
	assert(hps > 0.0)
	hours_per_second = hps
