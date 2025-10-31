extends Activity
class_name DrillActivity

func _init() -> void:
	activity_id = "drill"
	activity_name = "Drill"
	description = "Hone the arts of war. Regular training improves combat readiness at the cost of morale."
	activity_type = StrategyTypes.ActivityType.DRILL
	time_cost = 1
	location_requirements = []
	money_cost = 0.0
	food_cost = 0

func execute(squad: StrategicSquad, world: World, location: Location) -> StrategyTypes.ActivityResult:
	var result = StrategyTypes.ActivityResult.new()
	
	for warrior in squad.warriors:
		if not warrior.is_dead:
			warrior.combat_stats.strength += 1
			warrior.combat_stats.dex += 1
			warrior.modify_morale(-5.0)
	
	squad.modify_morale(-3.0)
	result.modify_squad_stat("morale", -3.0)
	
	result.add_narrative("The squad trains rigorously, improving combat skills but losing some morale.")
	
	if randf() < 0.1:
		result.trigger_event("training_accident")
		result.add_narrative("A training accident occurs!")
	elif randf() < 0.15:
		result.trigger_event("training_breakthrough")
		result.add_narrative("A warrior has a breakthrough in training!")
	
	return result

