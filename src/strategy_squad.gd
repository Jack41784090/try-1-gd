class_name TestStrategySquad
extends Resource

signal warriors_changed
signal money_changed
signal tactic_changed

@export var resource: StrategySquadResource;

@export var squad_id: String = ""
@export var squad_name: String = ""
@export var warriors: Array[TestStrategyEntity] = []
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
		#if not warrior.is_dead:
			#total_morale += warrior.morale
			#living_count += 1

	if living_count > 0:
		aggregate_morale = total_morale / living_count
	else:
		aggregate_morale = 0.0

func get_morale() -> float:
	return aggregate_morale


func add_warrior(warrior: TestStrategyEntity) -> void:
	warriors.append(warrior)
	formation.append(SquadBattleTypes.SquadEntityInSquadLocation.Front)
	warriors_changed.emit()
	# update_aggregate_morale()



func set_tactic(tactic: Tactic) -> void:
	current_tactic = tactic
	tactic_changed.emit()


func get_tactic() -> Tactic:
	if not current_tactic:
		current_tactic = Tactic.create_balanced()
	return current_tactic




func get_warriors_by_religion(religion_type: StrategyTypes.Religion) -> Array[StrategyEntity]:
	var matching: Array[StrategyEntity] = []
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




func is_traveling() -> bool:
	return not travel_route.is_empty()


func clear_travel() -> void:
	travel_route.clear()
	travel_segment_index = 0
	travel_progress_km = 0.0
