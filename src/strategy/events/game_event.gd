extends Triggerable
class_name GameEvent

@export var event_id: String = ""
@export var event_name: String = ""
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

func trigger(squad: StrategicSquad, world: World) -> StrategyTypes.EventResult:
	times_triggered += 1
	trigger_id = event_id
	trigger_name = event_name
	
	execution_started.emit()
	var result = fire(squad, world)
	
	var result_dict = {
		"event_id": event_id,
		"narrative_text": result.narrative_text,
		"requires_async": not result.auto_resolved or not result.dialogue_scene_path.is_empty(),
		"choices": result.choices,
		"immediate_effects": result.immediate_effects,
		"dialogue_scene_path": result.dialogue_scene_path
	}
	
	triggered.emit(result_dict)
	
	if result.auto_resolved and result.dialogue_scene_path.is_empty():
		execution_completed.emit(result_dict)
	
	return result

func execute(_squad: StrategicSquad, _world: World) -> StrategyTypes.EventResult:
	return fire(_squad, _world)

func fire(_squad: StrategicSquad, _world: World) -> StrategyTypes.EventResult:
	push_error("GameEvent.fire() must be overridden in subclass")
	var result = StrategyTypes.EventResult.new()
	result.narrative_text = "Event '%s' fired but has no implementation." % event_name
	return result

func increment_trigger_count() -> void:
	times_triggered += 1

func reset_trigger_count() -> void:
	times_triggered = 0
