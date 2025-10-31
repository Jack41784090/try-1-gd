extends Activity
class_name InvestigateActivity

func _init() -> void:
	activity_id = "investigate"
	activity_name = "Investigate"
	description = "Spend time gathering information, following leads, or looking into strange occurrences. Key to uncovering plots and mitigating future crises."
	activity_type = StrategyTypes.ActivityType.INVESTIGATE
	time_cost = 2
	location_requirements = [
		StrategyTypes.LocationType.CITY,
		StrategyTypes.LocationType.TOWN,
		StrategyTypes.LocationType.FORT
	]
	money_cost = 10.0
	food_cost = 0

func execute(squad: StrategicSquad, world: World, location: Location) -> StrategyTypes.ActivityResult:
	var result = StrategyTypes.ActivityResult.new()
	
	if not squad.spend_money(money_cost):
		result.add_narrative("Not enough money to investigate. Need %.2f gold." % money_cost)
		return result
	
	result.modify_squad_stat("money", -money_cost)
	result.add_narrative("Spent %.2f gold investigating in %s." % [money_cost, location.location_name])
	
	var success_chance = 0.6
	var avg_perception = 0.0
	var living_warriors = squad.get_living_warriors()
	
	for warrior in living_warriors:
		avg_perception += warrior.get_attribute(StrategyTypes.WarriorAttribute.PERCEPTION)
	
	if living_warriors.size() > 0:
		avg_perception /= living_warriors.size()
		success_chance += avg_perception / 100.0
	
	if randf() < success_chance:
		result.add_narrative("Investigation successful! Uncovered valuable information.")
		if randf() < 0.4:
			result.trigger_event("mission_unlocked")
			result.add_narrative("A new mission opportunity revealed!")
		elif randf() < 0.3:
			result.trigger_event("location_discovered")
			result.add_narrative("Discovered a hidden location!")
	else:
		result.add_narrative("Investigation yielded no useful results.")
		if randf() < 0.2:
			result.trigger_event("investigation_backfire")
			result.add_narrative("The investigation attracted unwanted attention!")
	
	return result

