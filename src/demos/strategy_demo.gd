extends Node

var scenario: GameScenario

func _ready() -> void:
	print("=== Strategy Layer Demo ===")
	setup_scenario()
	run_demo()

func setup_scenario() -> void:
	var world = World.new()
	
	var village = Location.new()
	village.location_id = "village_1"
	village.location_name = "Oakshire Village"
	village.type = StrategyTypes.LocationType.VILLAGE
	village.development = 30
	village.stability = 80.0
	village.set_activity_types([
		StrategyTypes.ActivityType.REST,
		StrategyTypes.ActivityType.DRILL,
		StrategyTypes.ActivityType.TRAVEL,
		StrategyTypes.ActivityType.HOLD_MASS
	])
	village.set_connections(["town_1"])
	
	var town = Location.new()
	town.location_id = "town_1"
	town.location_name = "Riverside Town"
	town.type = StrategyTypes.LocationType.TOWN
	town.development = 60
	town.stability = 90.0
	town.set_activity_types([
		StrategyTypes.ActivityType.REST,
		StrategyTypes.ActivityType.DRILL,
		StrategyTypes.ActivityType.TRAVEL,
		StrategyTypes.ActivityType.PATROL,
		StrategyTypes.ActivityType.INVESTIGATE,
		StrategyTypes.ActivityType.HOLD_MASS
	])
	town.set_connections(["village_1"])
	
	world.add_location(village)
	world.add_location(town)
	
	var squad = StrategicSquad.new()
	squad.squad_id = "player_squad"
	squad.squad_name = "The Condors"
	squad.money = 100.0
	squad.food = 20
	squad.travel_tools = 10
	squad.karma = 0.0
	
	var warrior1 = Warrior.new()
	warrior1.warrior_id = "warrior_1"
	warrior1.warrior_name = "Marcus"
	warrior1.morale = 100.0
	warrior1.religion = StrategyTypes.Religion.CATHOLIC
	warrior1.combat_stats = EntityBaseStats.new()
	warrior1.combat_stats.strength = 10
	warrior1.combat_stats.endurance = 12
	warrior1.equipment_weapon = SquadWeapon.new().unarmed()
	warrior1.equipment_armour = SquadArmour.new()
	
	var warrior2 = Warrior.new()
	warrior2.warrior_id = "warrior_2"
	warrior2.warrior_name = "Helena"
	warrior2.morale = 95.0
	warrior2.religion = StrategyTypes.Religion.PROTESTANT
	warrior2.combat_stats = EntityBaseStats.new()
	warrior2.combat_stats.strength = 8
	warrior2.combat_stats.endurance = 10
	warrior2.equipment_weapon = SquadWeapon.new().unarmed()
	warrior2.equipment_armour = SquadArmour.new()
	
	squad.add_warrior(warrior1)
	squad.add_warrior(warrior2)
	
	scenario = GameScenario.new({
		"world": world,
		"player_squad": squad,
		"starting_location_id": "village_1",
		"factions": [],
		"events": [],
		"endings": []
	})
	
	scenario.activity_executed.connect(_on_activity_executed)
	scenario.turn_advanced.connect(_on_turn_advanced)

func run_demo() -> void:
	print("\n=== Turn 1: Rest ===")
	var rest = RestActivity.new()
	var result1 = scenario.execute_turn(rest)
	print_turn_result(result1)
	
	print("\n=== Turn 2: Drill ===")
	var drill = DrillActivity.new()
	var result2 = scenario.execute_turn(drill)
	print_turn_result(result2)
	
	print("\n=== Turn 3: Hold Mass ===")
	var mass = HoldMassActivity.new()
	var result3 = scenario.execute_turn(mass)
	print_turn_result(result3)
	
	print("\n=== Current Squad Status ===")
	print_squad_status()
	
	print("\n=== Demo Complete ===")

func print_turn_result(result: Dictionary) -> void:
	if result.has("error"):
		print("ERROR: ", result["error"])
		return
	
	print("Activity: ", result["activity"])
	
	var activity_result = result.get("activity_result", {})
	var narrative = activity_result.get("narrative", [])
	for line in narrative:
		print("  > ", line)
	
	var squad_changes = activity_result.get("squad_changes", {})
	if squad_changes.size() > 0:
		print("  Squad changes: ", squad_changes)

func print_squad_status() -> void:
	print("Squad: ", scenario.player_squad.squad_name)
	print("Location: ", scenario.current_location.location_name)
	print("Money: ", scenario.player_squad.money)
	print("Food: ", scenario.player_squad.food)
	print("Morale: ", scenario.player_squad.get_morale())
	print("Karma: ", scenario.player_squad.karma)
	print("Turn: ", scenario.world.turn_count)
	print("\nWarriors:")
	for warrior in scenario.player_squad.warriors:
		print("  - %s (Morale: %.1f, Religion: %s)" % [
			warrior.warrior_name,
			warrior.morale,
			StrategyTypes.Religion.keys()[warrior.religion]
		])

func _on_activity_executed(activity: Activity, _result: StrategyTypes.ActivityResult) -> void:
	print("[EVENT] Activity '%s' completed" % activity.activity_name)

func _on_turn_advanced(turn: int) -> void:
	print("[EVENT] Turn advanced to %d" % turn)
