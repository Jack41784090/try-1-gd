class_name Activity
extends Triggerable

static var _registry

@export var result: ActivityResult
@export var activity_type: StrategyTypes.ActivityType = StrategyTypes.ActivityType.CUSTOM
@export var time_cost: int = 1
@export var destination_id: String = ""
@export var min_stability_to_block_attack: float = 80.0
@export var force_march_supply_multiplier: float = 2.0
@export var force_march_clue_multiplier: int = 2

@export var custom_script: Script = null
var ultimate_destination_id: String = ""


static func _get_registry():
	if _registry == null:
		_registry = ActivityRegistry.new()
	return _registry


func _to_string() -> String:
	return "Activity(Name: %s, Type: %s, Time Cost: %d, Destination: %s, Min Stability to Block Attack: %.1f, Force March Supply Multiplier: %.1f, Force March Clue Multiplier: %d, Custom Script: %s, Result: %s, %s)" % [
		trigger_name,
		StrategyTypes.ActivityType.keys()[activity_type],
		time_cost,
		destination_id,
		min_stability_to_block_attack,
		force_march_supply_multiplier,
		force_march_clue_multiplier,
		"custom_script" if custom_script else "None",
		result,
		super(),
	]


func can_execute(squad: SquadData, location: Location) -> bool:
	var handler = _get_registry().get_handler(activity_type)
	if handler:
		return handler.can_execute(self, squad, location)
	return true


func trigger(context: Dictionary) -> Array[ActivityResult]:
	# execution_started.emit()
	# triggered.emit(result)
	# if not result.requires_async:
	# 	execution_completed.emit(result)
	return execute(context)


func execute(context: Dictionary) -> Array[ActivityResult]:
	# if custom_script:
	# 	# Call custom script if provided
	# 	if custom_script.has_method("execute_custom"):
	# 		return custom_script.execute_custom(squad, world, result)
	return _execute_generic(context)


func _execute_generic(context: Dictionary) -> Array[ActivityResult]:
	assert(result)

	var saved_result := result
	result = saved_result.duplicate(true)
	var activity_result: ActivityResult = result

	var handler = _get_registry().get_handler(activity_type)
	if handler:
		activity_result = handler.execute(context, result)

	result = saved_result

	var all_triggered_results: Array[ActivityResult] = [activity_result]
	for chain in trigger_chains:
		var chained_trigger = chain.another_trigger
		var c_chance = chain.chance
		if chained_trigger.can_trigger(context):
			if c_chance == 1.0 or (c_chance < 1.0 and RandomNumberGenerator.new().randf() <= c_chance):
				Log.debug("Activity", "Executing chained activity: %s" % chained_trigger.trigger_name)
				var chained_results = chained_trigger.execute(context)
				if chained_results is Array:
					for cr in chained_results:
						if cr is ActivityResult:
							all_triggered_results.append(cr)
				else:
					if chained_results is ActivityResult:
						all_triggered_results.append(chained_results)
			else:
				Log.debug("Activity", "Skipped chained activity (chance failed): %s" % chained_trigger.trigger_name)

	return all_triggered_results

