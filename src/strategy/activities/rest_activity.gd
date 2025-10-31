extends Activity
class_name RestActivity

func _init() -> void:
	activity_id = "rest"
	activity_name = "Rest"
	description = "Make camp and allow the squad to recover from the rigors of the road. Essential for maintaining morale."
	activity_type = StrategyTypes.ActivityType.REST
	time_cost = 1
	location_requirements = []
	food_cost = 0

func execute(squad: StrategicSquad, world: World, location: Location) -> StrategyTypes.ActivityResult:
	var result = StrategyTypes.ActivityResult.new()
	
	var food_needed = squad.warriors.size()
	if not squad.consume_food(food_needed):
		result.add_narrative("Not enough food to rest properly. Squad rests poorly.")
		squad.modify_morale(5.0)
		result.modify_squad_stat("morale", 5.0)
		return result
	
	var morale_boost = 20.0
	squad.modify_morale(morale_boost)
	result.modify_squad_stat("morale", morale_boost)
	
	result.add_narrative("The squad rests and recovers morale. Food consumed: %d" % food_needed)
	
	if randf() < 0.3:
		result.trigger_event("social_gathering")
		result.add_narrative("Social bonds strengthen during rest.")
	
	return result

