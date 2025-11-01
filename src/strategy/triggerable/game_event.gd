extends Triggerable
class_name GameEvent

@export var event_id: String = ""
@export var event_name: String = ""
@export var event_chain_path: String = ""
@export var chance: float = 100.0
@export var when_to_trigger: StrategyTypes.TriggerWhen = StrategyTypes.TriggerWhen.AFTER_ACTIVITY
@export var repeats: int = -1
@export var emergency_priority: int = 0

var times_triggered: int = 0

func _init() -> void:
	super._init()

func can_trigger(context: Dictionary = {}) -> bool:
	if repeats >= 0 and times_triggered >= repeats:
		return false
	
	if randf() * 100.0 > chance:
		return false
	
	return super.can_trigger(context)

func trigger(_squad: StrategicSquad, _world: World) -> StrategyTypes.EventResult:
	times_triggered += 1
	trigger_id = event_id
	trigger_name = event_name
	
	execution_started.emit()
	
	var result = execute(_squad, _world)
	
	triggered.emit(result)
	
	if result.auto_resolved and result.event_chain_path.is_empty():
		execution_completed.emit(result)
	
	return result

func execute(_squad: StrategicSquad, _world: World) -> StrategyTypes.EventResult:
	# Override this in subclasses to implement event logic
	var result = StrategyTypes.EventResult.new()
	result.event_id = event_id
	result.event_name = event_name
	result.event_chain_path = event_chain_path
	result.auto_resolved = event_chain_path.is_empty()
	result.requires_async = not event_chain_path.is_empty()
	return result

func increment_trigger_count() -> void:
	times_triggered += 1

func reset_trigger_count() -> void:
	times_triggered = 0
