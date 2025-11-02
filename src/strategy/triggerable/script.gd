class_name Triggerable extends Resource

@export var trigger_id: String = ""
@export var trigger_name: String = ""
@export var description: String = ""
@export var conditions: Array[TriggerCondition] = []
@export var trigger_chains: Array[StrategyTypes.TriggerChain] = []
@export var repeats: int = -1
@export var emergency_priority: int = 0

signal triggered(result: Dictionary)
signal execution_started()
signal execution_completed(result: Dictionary)


func _init() -> void:
	pass


func check_conditions(context: Dictionary) -> bool:
	for condition in conditions:
		if not condition.evaluate(context):
			return false
	return true


func can_trigger(context: Dictionary) -> bool:
	return check_conditions(context)


func trigger(squad: StrategicSquad, world: World) -> GenericResult:
	execution_started.emit()
	var result = execute(squad, world)
	
	var result_dict: Dictionary = {}
	if result is Dictionary:
		result_dict = result
	else:
		result_dict = {"trigger_id": trigger_id, "trigger_name": trigger_name}
	
	triggered.emit(result_dict)

	if not result_dict.get("requires_async", false):
		execution_completed.emit(result_dict)

	return result


func execute(_squad: StrategicSquad, _world: World) -> Variant:
	push_error("Triggerable.execute() must be overridden in subclass")
	return {
		"trigger_id": trigger_id,
		"trigger_name": trigger_name,
		"requires_async": false,
	}


func add_condition(condition: TriggerCondition) -> void:
	conditions.append(condition)
