# activity.gd
class_name Activity extends Triggerable

@export var result: ActivityResult;
@export var activity_type: StrategyTypes.ActivityType = StrategyTypes.ActivityType.CUSTOM
@export var time_cost: int = 1
# @export var event_chain_path: String = ""


# Optional custom logic override
@export var custom_script: Script = null

func can_execute(squad: StrategicSquad, location: Location) -> bool:
	return true

func trigger(squad: StrategicSquad, world: World) -> ActivityResult:
	# execution_started.emit()
	# triggered.emit(result)
	# if not result.requires_async:
	# 	execution_completed.emit(result)
	return execute(squad, world)

func execute(squad: StrategicSquad, world: World) -> ActivityResult:
	# if custom_script:
	# 	# Call custom script if provided
	# 	if custom_script.has_method("execute_custom"):
	# 		return custom_script.execute_custom(squad, world, result)
	
	return _execute_generic(squad, world)

func _execute_generic(_squad: StrategicSquad, _world: World) -> ActivityResult:
	if not result:
		result = ActivityResult.new({})
	# if not event_chain_path.is_empty():
	# 	result.event_chain_path = event_chain_path
	# 	result.requires_async = true
	return result
