class_name StrategySquad
extends Resource

signal warriors_changed
signal money_changed
signal tactic_changed

@export var resource: StrategySquadResource;

@export var squad_id: String = ""
@export var squad_name: String = ""
@export var warriors: Array[Character] = []
@export var money: float = 100.0
@export var karma: float = 0.0
@export var food: int = 0
@export var travel_tools: int = 5
@export var formation: Array[SquadBattleTypes.SquadEntityInSquadLocation] = []
@export var starting_location_id: String = ""

var engagement_stance: StrategyTypes.EngagementStance = StrategyTypes.EngagementStance.ENGAGE_WHEN_CONFIRMED
var squad_role: StrategyTypes.SquadRole = StrategyTypes.SquadRole.COMBAT
var cargo: CargoManifest = CargoManifest.new()
var scouting_focus = null
@export var inventory: SquadInventory = SquadInventory.new()
@export var current_activity_type: StrategyTypes.ActivityType = StrategyTypes.ActivityType.REST
var travel_progress_km: float = 0.0
var travel_route: Array[String] = []
var travel_segment_index: int = 0

var aggregate_morale: float:
	get:
		update_aggregate_morale()
		return aggregate_morale
var current_location_id: String = ""
var current_tactic: Tactic = null
var _initialized: bool = false


func _init() -> void:
	pass


func _to_string() -> String:
	return "StrategySquad(warriors=%s, money=%f, karma=%f, food=%d, tools=%d, formation=%s, startingloc=%s)" % [warriors, money, karma, food, travel_tools, formation, starting_location_id]


func consume_food(amount: int) -> bool:
	if food >= amount:
		food -= amount
		return true
	food = 0
	return false


func consume_travel_tools(amount: int) -> bool:
	if travel_tools >= amount:
		travel_tools -= amount
		return true
	travel_tools = 0
	return false


func consume_supplies_by_demand(multiplier: float = 1.0) -> bool:
	# Consumes food based on each warrior's demand attribute, scaled by multiplier
	# Returns true if enough food was available, false if squad ran out
	# e.g., 3 warriors with demand [2, 3, 2], multiplier=1.0 → total=7, food=10 → food=3, returns true
	# e.g., 3 warriors with demand [2, 3, 2], multiplier=1.0 → total=7, food=5 → food=0, returns false
	var total_demand := 0.0
	for warrior in get_living_warriors():
		var demand = warrior.get_demand()
		total_demand += demand.get(StrategyTypes.SquadProperty.FOOD_SUPPLIES, 0.0)
	var food_cost := int(ceil(total_demand * multiplier))
	return consume_food(food_cost)


func apply_travel_morale_penalty(base_penalty: float = -2.0) -> void:
	for warrior in get_living_warriors():
		var survival = float(warrior.get_attribute(StrategyTypes.WarriorAttribute.SURVIVAL))
		var mitigation = survival / 200.0
		var penalty = base_penalty * (1.0 - mitigation)
		warrior.modify_morale(penalty)


func gain_money(amount: float) -> void:
	money = max(0.0, money + amount)
	money_changed.emit()


func spend_money(amount: float) -> bool:
	if money >= amount:
		money -= amount
		money_changed.emit()
		return true
	return false


func modify_karma(amount: float) -> void:
	karma = clamp(karma + amount, -100.0, 100.0)


func update_aggregate_morale() -> void:
	if warriors.size() == 0:
		aggregate_morale = 0.0
		return

	var total_morale := 0.0
	var living_count := 0

	for warrior in warriors:
		if warrior == null:
			continue
		if not warrior.is_dead:
			total_morale += float(warrior.get_stat_value(StatName.I.MORALE))
			living_count += 1

	if living_count > 0:
		aggregate_morale = total_morale / living_count
	else:
		aggregate_morale = 0.0




func get_morale() -> float:
	return aggregate_morale


func add_warrior(warrior: Character) -> void:
	warriors.append(warrior)
	formation.append(SquadBattleTypes.SquadEntityInSquadLocation.Front)
	warriors_changed.emit()
	# update_aggregate_morale()


func get_living_warriors() -> Array[Character]:
	var living: Array[Character] = []
	for warrior in warriors:
		if not warrior.is_dead:
			living.append(warrior)
	return living


func get_warrior_by_id(warrior_id: String) -> Character:
	for warrior in warriors:
		if warrior.id == warrior_id:
			return warrior
	return null


func remove_dead_warriors() -> void:
	var kept: Array[Character] = []
	var removed := false
	for warrior in warriors:
		if warrior.is_dead:
			removed = true
		else:
			kept.append(warrior)
	if removed:
		warriors = kept
		warriors_changed.emit()


func modify_morale(amount: float) -> void:
	for warrior in get_living_warriors():
		warrior.modify_morale(amount)



func set_tactic(tactic: Tactic) -> void:
	current_tactic = tactic
	tactic_changed.emit()


func get_tactic() -> Tactic:
	if not current_tactic:
		current_tactic = Tactic.create_balanced()
	return current_tactic


func get_aggregate_scouting() -> float:
	var total := 0.0
	var living = get_living_warriors()
	if living.is_empty():
		return 0.0
	for warrior in living:
		total += float(warrior.get_attribute(StrategyTypes.WarriorAttribute.PERCEPTION))
	return total / living.size()


func get_aggregate_stealth() -> float:
	var total := 0.0
	var living = get_living_warriors()
	if living.is_empty():
		return 0.0
	for warrior in living:
		total += float(warrior.get_attribute(StrategyTypes.WarriorAttribute.STEALTH))
	return total / living.size()


func get_aggregate_leadership() -> float:
	var living = get_living_warriors()
	if living.is_empty():
		return 0.0
	var total := 0.0
	for warrior in living:
		total += float(warrior.get_attribute(StrategyTypes.WarriorAttribute.LEADERSHIP))
	return total / living.size()


func get_coordination() -> float:
	return clampf(get_aggregate_leadership() / 80.0, 0.0, 0.8)


func attempt_stealth_return_failed(location: Location, destination_id: String, current_hour: int) -> Array[Character]:
	# Each warrior rolls stealth vs random(0-100). Warriors who fail leave clues behind.
	# Used when traveling to determine if enemies can track this squad's movement
	# e.g., warrior stealth=60, roll=75 → 75 > 60 → FAILED, leaves clue (failure_margin=15)
	# e.g., warrior stealth=80, roll=50 → 50 < 80 → PASSED, no clue left
	var clues_left: Array[Character] = []

	for warrior in get_living_warriors():
		var stealth_value = warrior.get_attribute(StrategyTypes.WarriorAttribute.STEALTH)
		var roll = randi_range(0, 100)

		if roll > stealth_value:
			var failure_margin = roll - stealth_value
			clues_left.append(warrior)

	return clues_left


func get_warriors_by_religion(religion_type: StrategyTypes.Religion) -> Array[Character]:
	var matching: Array[Character] = []
	for warrior in warriors:
		if warrior.check_religion(religion_type):
			matching.append(warrior)
	return matching


func set_location(location_id: String) -> void:
	current_location_id = location_id


func is_caravan() -> bool:
	return squad_role == StrategyTypes.SquadRole.MERCHANT


func has_cargo() -> bool:
	return cargo.is_empty()


func get_cargo_value() -> float:
	return cargo.get_total_value()


func has_reached_destination() -> bool:
	return is_caravan() and cargo.has_reached(current_location_id)


func get_location_id() -> String:
	return current_location_id


func get_speed_kmh() -> float:
	var living := get_living_warriors()
	if living.is_empty():
		return 0.0
	var min_speed := INF
	for warrior in living:
		min_speed = min(min_speed, warrior.get_speed_kmh())
	if is_caravan():
		min_speed *= 0.5
	return min_speed


func is_traveling() -> bool:
	return not travel_route.is_empty()


func clear_travel() -> void:
	travel_route.clear()
	travel_segment_index = 0
	travel_progress_km = 0.0
