# activity.gd
class_name Activity extends Triggerable

@export var activity_type: StrategyTypes.ActivityType = StrategyTypes.ActivityType.CUSTOM
@export var time_cost: int = 1
@export var resource_costs: Dictionary[StrategyTypes.SquadProperty, float] = {} # {"food": 5, "money": 10.0}
@export var location_requirements: Array[StrategyTypes.LocationType] = []
@export var base_effects: Dictionary[StrategyTypes.SquadProperty, float] = {} # Squad stat modifications
@export var event_chain_path: String = ""

# Legacy cost fields for compatibility
var food_cost: int:
	get:
		return resource_costs.get("food", 0)
var money_cost: float:
	get:
		return resource_costs.get("money", 0.0)
var travel_tools_cost: int:
	get:
		return resource_costs.get("travel_tools", 0)

# Optional custom logic override
@export var custom_script: Script = null

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

func trigger(squad: StrategicSquad, world: World) -> ActivityResult:
	execution_started.emit()
	var result: ActivityResult = execute(squad, world)
	triggered.emit(result)
	if not result.requires_async:
		execution_completed.emit(result)
	return result

func execute(squad: StrategicSquad, world: World) -> ActivityResult:
	if custom_script:
		# Call custom script if provided
		if custom_script.has_method("execute_custom"):
			return custom_script.execute_custom(squad, world, base_effects)
	
	return _execute_generic(squad, world)

func _execute_generic(_squad: StrategicSquad, _world: World) -> ActivityResult:
	var result = ActivityResult.new({})
	
	# Apply base effects to result
	for squad_property in base_effects:
		result.modify_squad_stat(squad_property, base_effects[squad_property])
	
	# Set event chain path if configured
	if not event_chain_path.is_empty():
		result.event_chain_path = event_chain_path
		result.requires_async = true
	
	return result
