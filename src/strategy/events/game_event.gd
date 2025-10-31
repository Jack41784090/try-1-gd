extends Resource
class_name GameEvent

@export var event_id: String = ""
@export var event_name: String = ""
@export var conditions: Array[TriggerCondition] = []
@export var chance: float = 100.0
@export var when_to_trigger: StrategyTypes.TriggerWhen = StrategyTypes.TriggerWhen.AFTER_ACTIVITY
@export var repeats: int = -1
@export var emergency_priority: int = 0

var times_triggered: int = 0

func check_conditions(context: Dictionary) -> bool:
	for condition in conditions:
		if not condition.evaluate(context):
			return false
	return true

func can_trigger() -> bool:
	if repeats >= 0 and times_triggered >= repeats:
		return false
	
	if randf() * 100.0 > chance:
		return false
	
	return true

func trigger(squad: StrategicSquad, world: World) -> StrategyTypes.EventResult:
	times_triggered += 1
	return fire(squad, world)

func fire(_squad: StrategicSquad, _world: World) -> StrategyTypes.EventResult:
	push_error("GameEvent.fire() must be overridden in subclass")
	var result = StrategyTypes.EventResult.new()
	result.narrative_text = "Event '%s' fired but has no implementation." % event_name
	return result

func increment_trigger_count() -> void:
	times_triggered += 1

func reset_trigger_count() -> void:
	times_triggered = 0

