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
		super()
	]

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

	var activity_result: ActivityResult = result
	
	match activity_type:
		StrategyTypes.ActivityType.ATTACK:
			activity_result = _execute_attack(context)
		StrategyTypes.ActivityType.FORCE_MARCH:
			activity_result = _execute_force_march(context)
		StrategyTypes.ActivityType.RECRUIT:
			activity_result = _execute_recruit(context)
		StrategyTypes.ActivityType.TRAVEL:
			activity_result = _execute_travel(context)

		_:
			return [activity_result]

	
	var all_triggered_results: Array[ActivityResult] = [activity_result]
	for chain in trigger_chains:
		var chained_trigger = chain.another_trigger
		var c_chance = chain.chance
		if chained_trigger.can_trigger(context):
			if c_chance == 1.0 or (c_chance < 1.0 and RandomNumberGenerator.new().randf() <= c_chance):
				print("[Activity] Executing chained activity: ", chained_trigger.trigger_name)
				var chained_results = chained_trigger.execute(context)
				all_triggered_results.append(chained_results)
			else:
				print("[Activity] Skipped chained activity (c_chance failed): ", chained_trigger.trigger_name)

	return all_triggered_results


func _execute_attack(context: Dictionary) -> ActivityResult:
	var world = context.get("world") as World
	var squad = context.get("squad") as StrategicSquad

	var enemies_here = world.get_squads_at_location(squad.current_location_id)
	
	if enemies_here.is_empty():
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)
		return result
	
	var target_enemy = enemies_here[0]
	result.requires_combat = true
	result.combat_target_squad_id = target_enemy.squad_id
	result.requires_async = true
	return result

func _execute_travel(context: Dictionary) -> ActivityResult:
	var squad = context.get("squad") as StrategicSquad

	# Simple travel logic: move the squad to a new location
	var consumed = squad.consume_food(1)
	if not consumed:
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)
	squad.set_location(destination_id)
	result.location_changed = destination_id
	
	return result

func _execute_force_march(context: Dictionary) -> ActivityResult:
	var world = context.get("world") as World
	var squad = context.get("squad") as StrategicSquad

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

func _execute_recruit(context: Dictionary) -> ActivityResult:
	var world = context.get("world") as World

	# Simple recruit logic: add a new warrior to the squad
	var recruited_entity = EntityFactory.get_entity(EntityFactory.EntityClasses.Landsknecht)
	var class_id = recruited_entity.class_id

	var new_warrior = WarriorFactory.create_warrior(class_id, recruited_entity.entity_name, StrategyTypes.Religion.CATHOLIC, EntityBaseStats.new())
	new_warrior.name = "Recruit_%d" % world.turn_count
	
	print("[RecruitActivity] Recruited new warrior: %s" % new_warrior.name)
	
	# Append the new recruit to the result
	result.append_new_recruits([new_warrior])
	
	return result
