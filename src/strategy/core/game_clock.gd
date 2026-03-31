class_name GameClock
extends RefCounted

signal hour_ticked(hour: int)

var world: World
var _accumulator: float = 0.0

const BASE_HOURS_PER_SECOND := 1.0


func _init(_world: World) -> void:
	world = _world


func process(delta: float) -> void:
	if world.is_paused:
		return
	_accumulator += delta * world.speed_multiplier * BASE_HOURS_PER_SECOND
	while _accumulator >= 1.0:
		_accumulator -= 1.0
		world.current_hour += 1
		hour_ticked.emit(world.current_hour)


func pause() -> void:
	world.is_paused = true


func unpause() -> void:
	world.is_paused = false


func toggle_pause() -> void:
	world.is_paused = not world.is_paused


func set_speed(multiplier: float) -> void:
	assert(multiplier > 0.0)
	world.speed_multiplier = multiplier
