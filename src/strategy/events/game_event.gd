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

func trigger(_squad: StrategicSquad, _world: World) -> StrategyTypes.EventResult:
	times_triggered += 1
	trigger_id = event_id
	trigger_name = event_name
	
	execution_started.emit()
	
	var result = {
		"event_id": event_id,
		"event_name": event_name,
		# "narrative_text": narrative_text,
		# "requires_async": not result.auto_resolved or not result.dialogue_scene_path.is_empty(),
		# "choices": result.choices,
		# "immediate_effects": result.immediate_effects,
		# "dialogue_scene_path": result.dialogue_scene_path
	}
	
	triggered.emit(result)
	
	if result.auto_resolved and result.dialogue_scene_path.is_empty():
		execution_completed.emit(result)
	
	return result

func increment_trigger_count() -> void:
	times_triggered += 1

func reset_trigger_count() -> void:
	times_triggered = 0
