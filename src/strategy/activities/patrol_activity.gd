extends Activity
class_name PatrolActivity

func _init() -> void:
	activity_id = "patrol"
	activity_name = "Patrol"
	description = "Assert your squad's presence in the local area, deterring banditry and reassuring the populace."
	activity_type = StrategyTypes.ActivityType.PATROL
	time_cost = 2
	location_requirements = [
		StrategyTypes.LocationType.CITY,
		StrategyTypes.LocationType.TOWN,
		StrategyTypes.LocationType.VILLAGE
	]
	money_cost = 0.0
	food_cost = 0

func execute(squad: StrategicSquad, world: World, location: Location) -> StrategyTypes.ActivityResult:
	var result = StrategyTypes.ActivityResult.new()
	
	var stability_increase = 10.0
	location.modify_stability(stability_increase)
	result.add_narrative("Patrolled %s, improving local stability." % location.location_name)
	
	var reputation_gain = 5.0
	squad.modify_karma(reputation_gain)
	result.modify_squad_stat("karma", reputation_gain)
	
	if randf() < 0.25:
		result.trigger_event("local_crime_discovered")
		result.add_narrative("Discovered criminal activity during patrol!")
	elif randf() < 0.15:
		result.trigger_event("hidden_threat_found")
		result.add_narrative("Found signs of a hidden threat!")
	
	return result

