extends Activity
class_name HoldMassActivity

func _init() -> void:
	activity_id = "hold_mass"
	activity_name = "Hold Mass"
	description = "Lead the squad in prayer and religious observance, reaffirming your faith and steeling your souls."
	activity_type = StrategyTypes.ActivityType.HOLD_MASS
	time_cost = 1
	location_requirements = []
	money_cost = 0.0
	food_cost = 0

func execute(squad: StrategicSquad, _world: World, _location: Location) -> StrategyTypes.ActivityResult:
	var result = StrategyTypes.ActivityResult.new()
	
	var religion_counts: Dictionary = {}
	var living_warriors = squad.get_living_warriors()
	
	for warrior in living_warriors:
		var religion_key = warrior.religion
		religion_counts[religion_key] = religion_counts.get(religion_key, 0) + 1
	
	var dominant_religion = StrategyTypes.Religion.CATHOLIC
	var max_count = 0
	for religion in religion_counts:
		if religion_counts[religion] > max_count:
			max_count = religion_counts[religion]
			dominant_religion = religion
	
	var same_faith_boost = 15.0
	var different_faith_penalty = -5.0
	var karma_gain = 5.0
	
	for warrior in living_warriors:
		if warrior.religion == dominant_religion:
			warrior.modify_morale(same_faith_boost)
		else:
			warrior.modify_morale(different_faith_penalty)
	
	squad.update_aggregate_morale()
	squad.modify_karma(karma_gain)
	result.modify_squad_stat("karma", karma_gain)
	
	# Trigger EventChain for narrative experience
	result.event_chain_path = "res://resources/event_chains/hold_mass_activity_chain.tres"
	
	# TEMP: Guarantee chained events for testing
	result.trigger_event("religious_vision")
	result.trigger_event("faction_attention")
	
	return result

