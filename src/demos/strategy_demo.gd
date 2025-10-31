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
	village.set_connections(["road_1"])
	
	var road = Location.new()
	road.location_id = "road_1"
	road.location_name = "Old Trade Road"
	road.type = StrategyTypes.LocationType.ROAD
	road.development = 10
	road.stability = 60.0
	road.set_activity_types([
		StrategyTypes.ActivityType.REST,
		StrategyTypes.ActivityType.TRAVEL
	])
	road.set_connections(["village_1", "town_1"])
	
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
	town.set_connections(["road_1", "city_1"])
	
	var city = Location.new()
	city.location_id = "city_1"
	city.location_name = "Königsberg"
	city.type = StrategyTypes.LocationType.CITY
	city.development = 100
	city.stability = 100.0
	city.set_activity_types([
		StrategyTypes.ActivityType.REST,
		StrategyTypes.ActivityType.DRILL,
		StrategyTypes.ActivityType.PATROL,
		StrategyTypes.ActivityType.INVESTIGATE,
		StrategyTypes.ActivityType.HOLD_MASS
	])
	city.set_connections(["town_1"])
	
	world.add_location(village)
	world.add_location(road)
	world.add_location(town)
	world.add_location(city)
	world.build_travel_graph()
	
	print("=== Travel Graph Built ===")
	print("Path from Village to City: ", world.find_path("village_1", "city_1"))
	print("Travel time: ", world.calculate_travel_time("village_1", "city_1"), " turns")
	print("Reachable from Village (2 hops): ", world.get_reachable_locations("village_1", 2))
	
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
	
	var test_faction = Faction.new()
	test_faction.faction_id = "test_faction"
	test_faction.faction_name = "Test Faction"
	
	var test_mission = Mission.new()
	test_mission.mission_id = "reach_city"
	test_mission.mission_name = "Journey to Königsberg"
	test_mission.description = "Travel to the great city"
	test_mission.is_unlocked = true
	var reach_condition = TriggerCondition.new()
	reach_condition.condition_type = TriggerCondition.ConditionType.LOCATION
	reach_condition.parameters = {"location_id": "city_1"}
	test_mission.add_condition(reach_condition)
	test_mission.set_completion_squad_effect("money", 50.0)
	test_mission.set_completion_world_effect("end_progression", 10.0)
	test_mission.add_completion_triggered_event("city_arrival")
	
	test_faction.add_mission(test_mission)
	
	scenario = GameScenario.new({
		"world": world,
		"player_squad": squad,
		"starting_location_id": "village_1",
		"factions": [test_faction],
		"events": [],
		"endings": []
	})
	
	scenario.activity_executed.connect(_on_activity_executed)
	scenario.mission_completed.connect(_on_mission_completed)
	scenario.turn_advanced.connect(_on_turn_advanced)

func run_demo() -> void:
	print("\n=== Turn 1: Rest ===")
	var rest = RestActivity.new()
	var result1 = scenario.execute_turn(rest)
	print_turn_result(result1)
	
	print("\n=== Turn 2: Travel to Road ===")
	var travel1 = TravelActivity.new()
	travel1.destination_id = "road_1"
	var result2 = scenario.execute_turn(travel1)
	print_turn_result(result2)
	
	print("\n=== Turn 3: Travel to Town ===")
	var travel2 = TravelActivity.new()
	travel2.destination_id = "town_1"
	var result3 = scenario.execute_turn(travel2)
	print_turn_result(result3)
	
	print("\n=== Turn 4: Travel to City (multi-hop) ===")
	var travel3 = TravelActivity.new()
	travel3.destination_id = "city_1"
	var result4 = scenario.execute_turn(travel3)
	print_turn_result(result4)
	
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
	
	var missions_completed = result.get("missions_completed", [])
	if missions_completed.size() > 0:
		print("  ✓ Missions completed: ", missions_completed)

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

func _on_mission_completed(mission: Mission) -> void:
	print("[EVENT] Mission completed: '%s'" % mission.mission_name)

func _on_turn_advanced(turn: int) -> void:
	print("[EVENT] Turn advanced to %d" % turn)
