# activity.gd
class_name Activity extends Triggerable

@export var result: ActivityResult;
@export var activity_type: StrategyTypes.ActivityType = StrategyTypes.ActivityType.CUSTOM
@export var time_cost: int = 1
@export var destination_id: String = ""
@export var min_stability_to_block_attack: float = 80.0
@export var force_march_supply_multiplier: float = 2.0
@export var force_march_clue_multiplier: int = 2

# Optional custom logic override
@export var custom_script: Script = null

func _to_string() -> String:
	return "Activity: %s (Type: %s, Time Cost: %d, %s)" % [trigger_name, StrategyTypes.ActivityType.keys()[activity_type], time_cost, super()]

func can_execute(squad: StrategicSquad, location: Location) -> bool:
	match activity_type:
		StrategyTypes.ActivityType.ATTACK:
			return location.stability < min_stability_to_block_attack
		StrategyTypes.ActivityType.FORCE_MARCH:
			if destination_id.is_empty():
				return false
			if not location.is_connected_to(destination_id):
				return false
			var food_cost = int(1 * force_march_supply_multiplier)
			return squad.food >= food_cost
		_:
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

func _execute_generic(squad: StrategicSquad, world: World) -> ActivityResult:
	assert(result)
	
	match activity_type:
		StrategyTypes.ActivityType.ATTACK:
			return _execute_attack(squad, world)
		StrategyTypes.ActivityType.FORCE_MARCH:
			return _execute_force_march(squad, world)
		_:
			return result

func _execute_attack(squad: StrategicSquad, world: World) -> ActivityResult:
	var enemies_here = world.get_squads_at_location(squad.current_location_id)
	
	if enemies_here.is_empty():
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)
		return result
	
	var target_enemy = enemies_here[0]
	result.requires_combat = true
	result.combat_target_squad_id = target_enemy.squad_id
	result.requires_async = true
	return result

func _execute_force_march(squad: StrategicSquad, world: World) -> ActivityResult:
	var food_cost = int(1 * force_march_supply_multiplier)
	squad.consume_food(food_cost)
	
	var old_location = world.get_location_by_id(squad.current_location_id)
	
	if old_location:
		for i in range(force_march_clue_multiplier):
			var clues = squad.attempt_stealth_at_location(old_location, destination_id, world.turn_count)
			result.clues_left += clues.size()
	
	squad.set_location(destination_id)
	result.location_changed = destination_id
	result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -10.0)
	
	var enemies_at_destination = world.get_squads_at_location(destination_id)
	if not enemies_at_destination.is_empty():
		var target_enemy = enemies_at_destination[0]
		result.requires_combat = true
		result.combat_target_squad_id = target_enemy.squad_id
		result.requires_async = true
	
	return result
