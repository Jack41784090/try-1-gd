extends Resource
class_name TriggerCondition

enum ConditionType {
	LOCATION,
	LOCATION_TYPE,
	WARRIOR_STATUS,
	SQUAD_STATUS,
	ACTIVITY_TYPE,
	TIME,
	MISSION_STATUS,
	PATH_SEGMENT,
	LOCATION_TRANSITION, # Checks if squad just arrived at/left a location
	COMPOUND
};

@export var condition_type: ConditionType = ConditionType.SQUAD_STATUS
@export var parameters: Dictionary = {}

func _to_string() -> String:
	return "TriggerCondition(type: %s, Parameters: %s)" % [ConditionType.keys()[condition_type], str(parameters)]

func evaluate(context: Dictionary) -> bool:
	match condition_type:
		ConditionType.LOCATION:
			return _check_location(context)
		ConditionType.LOCATION_TYPE:
			return _check_location_type(context)
		ConditionType.WARRIOR_STATUS:
			return _check_warrior_status(context)
		ConditionType.SQUAD_STATUS:
			return _check_squad_status(context)
		ConditionType.ACTIVITY_TYPE:
			return _check_activity(context)
		ConditionType.TIME:
			return _check_time(context)
		ConditionType.MISSION_STATUS:
			return _check_mission(context)
		ConditionType.PATH_SEGMENT:
			return _check_path_segment(context)
		ConditionType.LOCATION_TRANSITION:
			return _check_location_transition(context)
		ConditionType.COMPOUND:
			return _check_compound(context)
		_:
			push_warning("Unknown condition type: %s" % condition_type)
			return false

func _check_location(context: Dictionary) -> bool:
	var location: Location = context.get("location")
	if not location:
		return false
	
	var required_location_id = parameters.get("location_id", "")
	return location.location_id == required_location_id

func _check_location_type(context: Dictionary) -> bool:
	var location: Location = context.get("location")
	if not location:
		return false
	
	var required_type = parameters.get("location_type", StrategyTypes.LocationType.VILLAGE)
	return location.type == required_type

func _check_warrior_status(context: Dictionary) -> bool:
	var squad: SquadStrategicData = context.get("squad")
	if not squad:
		return false
	
	var religion_check = parameters.get("warrior_religion", -1)
	if religion_check >= 0:
		var min_count = parameters.get("warrior_count_min", 1)
		var matching_warriors = squad.get_warriors_by_religion(religion_check)
		if matching_warriors.size() < min_count:
			return false
	
	var morale_min = parameters.get("warrior_morale_min", -999.0)
	var morale_max = parameters.get("warrior_morale_max", 999.0)
	
	for warrior in squad.warriors:
		if warrior.morale < morale_min or warrior.morale > morale_max:
			return false
	
	return true

func _check_squad_status(context: Dictionary) -> bool:
	var squad: SquadStrategicData = context.get("squad")
	if not squad:
		return false
	
	var morale_min = parameters.get("squad_morale_min", -999.0)
	var morale_max = parameters.get("squad_morale_max", 999.0)
	
	if squad.get_morale() < morale_min or squad.get_morale() > morale_max:
		return false
	
	var money_min = parameters.get("money_min", -999.0)
	var money_max = parameters.get("money_max", 999999.0)
	
	if squad.money < money_min or squad.money > money_max:
		return false
	
	var food_min = parameters.get("food_min", -999)
	var food_max = parameters.get("food_max", 999999)
	
	if squad.food < food_min or squad.food > food_max:
		return false
	
	var karma_min = parameters.get("karma_min", -999.0)
	var karma_max = parameters.get("karma_max", 999.0)
	
	if squad.karma < karma_min or squad.karma > karma_max:
		return false
	
	return true

func _check_activity(context: Dictionary) -> bool:
	var activity: Activity = context.get("activity")
	if not activity:
		return false
	
	var required_type = parameters.get("activity_type", StrategyTypes.ActivityType.REST)
	return activity.activity_type == required_type

func _check_time(context: Dictionary) -> bool:
	var world: World = context.get("world")
	if not world:
		return false
	
	var turn_min = parameters.get("turn_min", 0)
	var turn_max = parameters.get("turn_max", 999999)
	
	return world.turn_count >= turn_min and world.turn_count <= turn_max

func _check_mission(context: Dictionary) -> bool:
	var completed_missions: Array = context.get("completed_missions", [])
	var required_mission_id = parameters.get("mission_id", "")
	var required_status = parameters.get("status", "completed")
	
	if required_status == "completed":
		return required_mission_id in completed_missions
	elif required_status == "not_completed":
		return not (required_mission_id in completed_missions)
	
	return false

func _check_path_segment(context: Dictionary) -> bool:
	var prev_location: Location = context.get("prev_location")
	var current_location: Location = context.get("location")
	
	if not prev_location or not current_location:
		return false
	
	var from_type = parameters.get("from_location_type", -1)
	if from_type >= 0 and prev_location.type != from_type:
		return false
	
	var to_type = parameters.get("to_location_type", -1)
	if to_type >= 0 and current_location.type != to_type:
		return false
	
	return true

func _check_location_transition(context: Dictionary) -> bool:
	## Checks if squad is transitioning to/from a location this turn
	## Parameters:
	##   - transition_type: "arriving" | "leaving" | "any" (default: "arriving")
	##   - location_id: specific location ID to check (optional)
	##   - location_type: LocationType enum value to check (optional)
	##   - require_travel_activity: if true, only triggers on TRAVEL activity (default: true)
	var transition_type = parameters.get("transition_type", "arriving")
	var require_travel = parameters.get("require_travel_activity", true)
	
	# Check if this is a travel activity (if required)
	if require_travel:
		var activity: Activity = context.get("activity")
		if not activity or activity.activity_type != StrategyTypes.ActivityType.TRAVEL:
			return false
	
	# Check for location change flag in context
	var is_location_changing: bool = context.get("is_location_changing", false)
	if not is_location_changing:
		return false
	
	var prev_location: Location = context.get("prev_location")
	var next_location: Location = context.get("next_location") # The location being traveled to
	var current_location: Location = context.get("location") # Current location before change
	
	# Determine which location to check based on transition type
	var check_location: Location = null
	match transition_type:
		"arriving":
			check_location = next_location if next_location else current_location
		"leaving":
			check_location = prev_location if prev_location else current_location
		"any":
			# Check both - if either matches, return true
			var arriving_match = _check_location_match(next_location if next_location else current_location)
			var leaving_match = _check_location_match(prev_location if prev_location else current_location)
			return arriving_match or leaving_match
		_:
			push_warning("Unknown transition_type: %s" % transition_type)
			return false
	
	return _check_location_match(check_location)

func _check_location_match(location: Location) -> bool:
	var required_id = parameters.get("location_id", "")
	if not required_id.is_empty() and location.location_id != required_id:
		return false
	
	var required_type = parameters.get("location_type", -1)
	if required_type >= 0 and location.type != required_type:
		return false
	
	return true

func _check_compound(context: Dictionary) -> bool:
	var operator = parameters.get("operator", "AND")
	var subconditions: Array = parameters.get("subconditions", [])
	
	if subconditions.is_empty():
		return true
	
	match operator:
		"AND":
			for subcond_data in subconditions:
				var subcond = _create_subcondition(subcond_data)
				if not subcond.evaluate(context):
					return false
			return true
		
		"OR":
			for subcond_data in subconditions:
				var subcond = _create_subcondition(subcond_data)
				if subcond.evaluate(context):
					return true
			return false
		
		_:
			push_warning("Unknown operator: %s" % operator)
			return false

func _create_subcondition(data: Variant) -> TriggerCondition:
	if data is TriggerCondition:
		return data
	elif data is Dictionary:
		var subcond = TriggerCondition.new()
		subcond.condition_type = data.get("type", ConditionType.SQUAD_STATUS)
		subcond.parameters = data.get("parameters", {})
		return subcond
	else:
		push_warning("Invalid subcondition data type")
		return TriggerCondition.new()
