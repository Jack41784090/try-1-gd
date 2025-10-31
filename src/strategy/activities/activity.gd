extends Resource
class_name Activity

@export var activity_id: String = ""
@export var activity_name: String = ""
@export var description: String = ""
@export var activity_type: StrategyTypes.ActivityType = StrategyTypes.ActivityType.CUSTOM
@export var time_cost: int = 1
@export var location_requirements: Array[StrategyTypes.LocationType] = []
@export var money_cost: float = 0.0
@export var food_cost: int = 0
@export var travel_tools_cost: int = 0

func can_execute(squad: StrategicSquad, location: Location) -> bool:
	if location_requirements.size() > 0 and not location.type in location_requirements:
		return false
	
	if food_cost > 0 and squad.food < food_cost:
		return false
	
	if money_cost > 0 and squad.money < money_cost:
		return false
	
	if travel_tools_cost > 0 and squad.travel_tools < travel_tools_cost:
		return false
	
	return true

func get_cannot_execute_reason(squad: StrategicSquad, location: Location) -> String:
	if location_requirements.size() > 0 and not location.type in location_requirements:
		return "This activity is not available at this location type."
	
	if food_cost > 0 and squad.food < food_cost:
		return "Not enough food. Need %d, have %d." % [food_cost, squad.food]
	
	if money_cost > 0 and squad.money < money_cost:
		return "Not enough money. Need %.2f, have %.2f." % [money_cost, squad.money]
	
	if travel_tools_cost > 0 and squad.travel_tools < travel_tools_cost:
		return "Not enough travel tools. Need %d, have %d." % [travel_tools_cost, squad.travel_tools]
	
	return ""

func execute(_squad: StrategicSquad, _world: World, _location: Location) -> StrategyTypes.ActivityResult:
	push_error("Activity.execute() must be overridden in subclass")
	return StrategyTypes.ActivityResult.new()

func consume_resources(squad: StrategicSquad) -> bool:
	var can_afford = true
	
	if food_cost > 0:
		can_afford = can_afford and squad.consume_food(food_cost)
	
	if money_cost > 0:
		can_afford = can_afford and squad.spend_money(money_cost)
	
	if travel_tools_cost > 0:
		can_afford = can_afford and squad.consume_travel_tools(travel_tools_cost)
	
	return can_afford

static func create_activity(_activity_type: StrategyTypes.ActivityType) -> Activity:
	match _activity_type:
		StrategyTypes.ActivityType.REST:
			return RestActivity.new()
		StrategyTypes.ActivityType.DRILL:
			return DrillActivity.new()
		StrategyTypes.ActivityType.TRAVEL:
			return TravelActivity.new()
		StrategyTypes.ActivityType.PATROL:
			return PatrolActivity.new()
		StrategyTypes.ActivityType.INVESTIGATE:
			return InvestigateActivity.new()
		StrategyTypes.ActivityType.HOLD_MASS:
			return HoldMassActivity.new()
		_:
			push_error("Unknown activity type: %s" % _activity_type)
			return Activity.new()

