class_name SquadData
extends Resource

@export var squad_id: String = ""
@export var squad_name: String = ""
@export var warriors: Array[Warrior] = []
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
var inventory = load("res://src/strategy/core/inventory.gd").new()
var current_activity_type: StrategyTypes.ActivityType = StrategyTypes.ActivityType.REST
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
	if current_tactic == null:
		current_tactic = Tactic.create_balanced()


func _to_string() -> String:
	return "SquadData(warriors=%s, money=%f, karma=%f, food=%d, tools=%d, formation=%s, startingloc=%s)" % [warriors, money, karma, food, travel_tools, formation, starting_location_id]


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
	print(
		"[Squad] Supply demand: %.1f (x%.1f) = %d food from %d warriors" % [
			total_demand,
			multiplier,
			food_cost,
			get_living_warriors().size(),
		],
	)
	return consume_food(food_cost)


func apply_travel_morale_penalty(base_penalty: float = -2.0) -> void:
	for warrior in get_living_warriors():
		var survival = float(warrior.get_attribute(StrategyTypes.WarriorAttribute.SURVIVAL))
		var mitigation = survival / 200.0
		var penalty = base_penalty * (1.0 - mitigation)
		warrior.modify_morale(penalty)
		print(
			"[Squad] Travel morale: %s %.2f (survival %d, mitigated %.0f%%)" % [
				warrior.name,
				penalty,
				int(survival),
				mitigation * 100.0,
			],
		)


func gain_money(amount: float) -> void:
	money = max(0.0, money + amount)


func spend_money(amount: float) -> bool:
	if money >= amount:
		money -= amount
		return true
	return false


func modify_karma(amount: float) -> void:
	karma = clamp(karma + amount, -100.0, 100.0)


func modify_morale(amount: float) -> void:
	Log.trace("Squad", "modify_morale amount=%.2f warrior_count=%d" % [amount, warriors.size()])
	for warrior in warriors:
		if warrior.is_dead:
			continue
		var old_morale := warrior.morale
		warrior.modify_morale(amount)
		Log.trace("Squad", "  warrior=%s morale: %.2f -> %.2f" % [warrior.name, old_morale, warrior.morale])
	# update_aggregate_morale()


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
			total_morale += warrior.morale
			living_count += 1

	if living_count > 0:
		aggregate_morale = total_morale / living_count
	else:
		aggregate_morale = 0.0


func modify_aggregate_morale(mod: float) -> void:
	modify_morale(mod)
	# update_aggregate_morale()


func get_morale() -> float:
	return aggregate_morale


func add_warrior(warrior: Warrior) -> void:
	warriors.append(warrior)
	formation.append(SquadBattleTypes.SquadEntityInSquadLocation.Front)
	# update_aggregate_morale()


func remove_dead_warriors() -> Array[Warrior]:
	# Removes dead warriors from the squad and their formation slots, returns the dead ones
	# e.g., warriors=[Hans(alive), Fritz(dead), Karl(alive)], formation=[Front, Middle, Back]
	#   → new warriors=[Hans, Karl], new formation=[Front, Back], returns [Fritz]
	var dead_warriors: Array[Warrior] = []
	var new_warriors: Array[Warrior] = []
	var new_formation: Array[SquadBattleTypes.SquadEntityInSquadLocation] = []

	for i in range(warriors.size()):
		if warriors[i].is_dead:
			dead_warriors.append(warriors[i])
		else:
			new_warriors.append(warriors[i])
			if i < formation.size():
				new_formation.append(formation[i])
			else:
				new_formation.append(SquadBattleTypes.SquadEntityInSquadLocation.Front)

	warriors = new_warriors
	formation = new_formation
	# update_aggregate_morale()

	return dead_warriors


func get_living_warriors() -> Array[Warrior]:
	var living: Array[Warrior] = []
	for warrior in warriors:
		if not warrior.is_dead:
			living.append(warrior)
	return living


func get_warrior_by_id(warrior_id: String) -> Warrior:
	for warrior in warriors:
		if warrior.id == warrior_id:
			return warrior
	return null


func set_tactic(tactic: Tactic) -> void:
	current_tactic = tactic


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


func attempt_stealth_return_failed(location: Location, destination_id: String, current_hour: int) -> Array[Warrior]:
	# Each warrior rolls stealth vs random(0-100). Warriors who fail leave clues behind.
	# Used when traveling to determine if enemies can track this squad's movement
	# e.g., warrior stealth=60, roll=75 → 75 > 60 → FAILED, leaves clue (failure_margin=15)
	# e.g., warrior stealth=80, roll=50 → 50 < 80 → PASSED, no clue left
	var clues_left: Array[Warrior] = []

	for warrior in get_living_warriors():
		var stealth_value = warrior.get_attribute(StrategyTypes.WarriorAttribute.STEALTH)
		var roll = randi_range(0, 100)

		if roll > stealth_value:
			var failure_margin = roll - stealth_value
			clues_left.append(warrior)

	return clues_left


func get_warriors_by_religion(religion_type: StrategyTypes.Religion) -> Array[Warrior]:
	var matching: Array[Warrior] = []
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
