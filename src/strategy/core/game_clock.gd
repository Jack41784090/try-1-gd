class_name GameClock
extends RefCounted

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
		# StrategyEventBus.strategy_hour_tick.emit(world.current_hour)


func pause() -> void:
	world.is_paused = true
	# StrategyEventBus.pause_state_changed.emit(true)


func unpause() -> void:
	world.is_paused = false
	# StrategyEventBus.pause_state_changed.emit(false)


func toggle_pause() -> void:
	world.is_paused = not world.is_paused
	# StrategyEventBus.pause_state_changed.emit(world.is_paused)


func force_tick() -> void:
	world.current_hour += 1
	# StrategyEventBus.strategy_hour_tick.emit(world.current_hour)


func set_speed(multiplier: float) -> void:
	assert(multiplier > 0.0)
	world.speed_multiplier = multiplier
	# StrategyEventBus.speed_changed.emit(multiplier)
