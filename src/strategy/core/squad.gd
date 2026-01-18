extends Resource
class_name StrategicSquad

@export var squad_id: String = ""
@export var squad_name: String = "Unnamed Squad"
@export var warriors: Array[Warrior] = []
@export var money: float = 100.0
@export var karma: float = 0.0
@export var food: int = 0
@export var travel_tools: int = 5
@export var formation: Array[int] = []
@export var starting_location_id: String = ""

var aggregate_morale: float = 100.0
var current_location_id: String = ""
var current_tactic: Tactic = null

func _init() -> void:
	print(" --- StrategicSquad init --- ")
	warriors.append(Warrior.new())
	update_aggregate_morale()
	current_tactic = Tactic.create_balanced()
	# Initialize current_location_id from starting_location_id if set
	if starting_location_id != "":
		current_location_id = starting_location_id
	print(" \\=> New squad created: ", _to_string())

func _to_string() -> String:
	return "StrategicSquad(id=%s, name=%s, warriors=%s, money=%f, karma=%f, food=%d, tools=%d, formation=%s, startingloc=%s)" % [squad_id, squad_name, warriors, money, karma, food, travel_tools, formation, starting_location_id]

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

func spend_money(amount: float) -> bool:
	if money >= amount:
		money -= amount
		return true
	return false

func modify_karma(amount: float) -> void:
	karma = clamp(karma + amount, -100.0, 100.0)

func modify_morale(amount: float) -> void:
	print("StrategicSquad.modify_morale squad=%s amount=%.2f warrior_count=%d" % [squad_name, amount, warriors.size()])
	for warrior in warriors:
		var old_morale := warrior.morale
		warrior.modify_morale(amount)
		print("  warrior=%s is_dead=%s morale: %.2f -> %.2f" % [warrior.name, str(warrior.is_dead), old_morale, warrior.morale])
	update_aggregate_morale()

func update_aggregate_morale() -> void:
	if warriors.size() == 0:
		aggregate_morale = 0.0
		print("StrategicSquad.update_aggregate_morale squad=%s no_warriors aggregate=0" % squad_name)
		return
	
	var total_morale := 0.0
	var living_count := 0
	
	for warrior in warriors:
		if not warrior.is_dead:
			total_morale += warrior.morale
			living_count += 1
	
	if living_count > 0:
		aggregate_morale = total_morale / living_count
	else:
		aggregate_morale = 0.0
	
	print("StrategicSquad.update_aggregate_morale squad=%s living=%d total=%.2f aggregate=%.2f" % [
		squad_name,
		living_count,
		total_morale,
		aggregate_morale
	])

func modify_aggregate_morale(mod: float) -> void:
	modify_morale(mod)
	update_aggregate_morale()

func get_morale() -> float:
	return aggregate_morale

func add_warrior(warrior: Warrior) -> void:
	warriors.append(warrior)
	formation.append(SquadBattleTypes.SquadEntityInSquadLocation.Front)
	update_aggregate_morale()

func remove_dead_warriors() -> Array[Warrior]:
	var dead_warriors: Array[Warrior] = []
	var new_warriors: Array[Warrior] = []
	var new_formation: Array[int] = []
	
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
	update_aggregate_morale()
	
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

func attempt_stealth_at_location(location: Location, destination_id: String, current_turn: int) -> Array[Clue]:
	var clues_left: Array[Clue] = []
	
	for warrior in get_living_warriors():
		var stealth_value = warrior.get_attribute(StrategyTypes.WarriorAttribute.STEALTH)
		var roll = randi_range(0, 100)
		
		if roll > stealth_value:
			var failure_margin = roll - stealth_value
			var clue_name = Clue.get_random_clue_name(warrior.religion)
			var clue = Clue.create_clue(
				clue_name,
				squad_id,
				warrior.id,
				current_turn,
				failure_margin,
				destination_id
			)
			location.add_clue(clue)
			clues_left.append(clue)
	
	return clues_left

func get_warriors_by_religion(religion_type: StrategyTypes.Religion) -> Array[Warrior]:
	var matching: Array[Warrior] = []
	for warrior in warriors:
		if warrior.check_religion(religion_type):
			matching.append(warrior)
	return matching

func set_location(location_id: String) -> void:
	current_location_id = location_id

func ensure_initialized() -> void:
	if current_location_id == "" and starting_location_id != "":
		current_location_id = starting_location_id

func get_location_id() -> String:
	return current_location_id

func to_combat_squad(team: String = "player") -> Squad:
	push_warning("StrategicSquad.to_combat_squad() - Combat bridge not yet fully implemented")
	
	var entity_configs: Array = []
	var living_warriors = get_living_warriors()
	
	for i in range(living_warriors.size()):
		var warrior = living_warriors[i]
		var starting_loc = formation[i] if i < formation.size() else SquadBattleTypes.SquadEntityInSquadLocation.Front
		
		var entity_config = {
			"player_id": i,
			"name": warrior.name,
			"team": team,
			"stats": warrior.combat_stats,
			"weapon": warrior.equipment_weapon,
			"armour": warrior.equipment_armour,
			"starting_location": starting_loc,
			"logic_type": warrior.logic_type
		}
		entity_configs.append(entity_config)
	
	return Squad.new({
		"entities": entity_configs,
		"name": squad_name,
		"team": team
	})

func from_combat_results(updates: Array[EntityUpdate]) -> void:
	push_warning("StrategicSquad.from_combat_results() - Combat bridge not yet fully implemented")
	
	for update in updates:
		if update.target_id >= 0 and update.target_id < warriors.size():
			warriors[update.target_id].from_combat_result(update)
	
	update_aggregate_morale()
	remove_dead_warriors()

func save_state() -> Dictionary:
	var warrior_data: Array = []
	for warrior in warriors:
		warrior_data.append({
			"id": warrior.id,
			"name": warrior.name,
			"morale": warrior.morale,
			"religion": warrior.religion,
			"attributes": warrior.attributes,
			"is_dead": warrior.is_dead,
			"is_injured": warrior.is_injured
		})
	
	return {
		"squad_id": squad_id,
		"squad_name": squad_name,
		"money": money,
		"karma": karma,
		"food": food,
		"travel_tools": travel_tools,
		"formation": formation,
		"aggregate_morale": aggregate_morale,
		"current_location_id": current_location_id,
		"warriors": warrior_data
	}
