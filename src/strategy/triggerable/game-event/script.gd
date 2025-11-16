class_name GameEvent extends Triggerable

@export var event_id: String = ""
@export var event_name: String = ""
@export var chance: float = 100.0
@export var when_to_trigger: StrategyTypes.TriggerWhen = StrategyTypes.TriggerWhen.AFTER_ACTIVITY

var times_triggered: int = 0

func _init() -> void:
	super._init()

func can_trigger(context: Dictionary = {}) -> bool:
	if repeats >= 0 and times_triggered >= repeats:
		return false
	
	if randf() * 100.0 > chance:
		return false
	
	return super.can_trigger(context)

func trigger(_squad: StrategicSquad, _world: World) -> EventResult:
	times_triggered += 1
	trigger_id = event_id
	trigger_name = event_name
	
	execution_started.emit()
	
	var result = execute(_squad, _world)
	
	triggered.emit(result)
	
	if result.auto_resolved and result.event_chain_path.is_empty():
		execution_completed.emit(result)
	
	return result

func execute(_squad: StrategicSquad, _world: World) -> EventResult:
	# Override this in subclasses to implement event logic
	var result = EventResult.new({
		"event_id": event_id,
		"event_name": event_name,
		"event_chain_path": event_chain_path,
		"auto_resolved": event_chain_path.is_empty(),
		"requires_async": not event_chain_path.is_empty()
	})
	return result

func increment_trigger_count() -> void:
	times_triggered += 1

func reset_trigger_count() -> void:
	times_triggered = 0
