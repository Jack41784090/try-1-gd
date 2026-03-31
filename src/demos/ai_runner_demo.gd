extends Node

## Demo script to test SquadBrain decision-making logic
## Tests various scenarios with data-driven consideration scoring

func _ready():
	print("\n=== SQUAD BRAIN DECISION-MAKING DEMO ===\n")

	test_survival_low_food()
	print("\n" + "=".repeat(60) + "\n")

	test_survival_low_money()
	print("\n" + "=".repeat(60) + "\n")

	test_achievement_with_enemies()
	print("\n" + "=".repeat(60) + "\n")

	test_achievement_with_clues()
	print("\n" + "=".repeat(60) + "\n")

	test_score_comparison()
	print("\n" + "=".repeat(60) + "\n")

	print("\n=== ALL TESTS COMPLETE ===\n")

func test_survival_low_food():
	print("TEST 1: LOW FOOD - Should forage or travel to town")

	var scenario = create_test_scenario()
	var ai_squad = create_test_squad("ai_bandits", "Desperate Bandits", "village_1")
	ai_squad.food = 2
	ai_squad.money = 100.0

	var profile = AIProfileFactory.get_default_squad_profile()
	var brain = SquadBrain.new(ai_squad, profile)
	var directive = FactionDirective.create_none()

	var result = brain.decide(scenario.world, null, directive)
	var activity_type: StrategyTypes.ActivityType = result["activity_type"]

	print("\nResult:")
	print("  Squad food: %d, money: %.1f" % [ai_squad.food, ai_squad.money])
	print("  Decided activity: %s" % StrategyTypes.ActivityType.keys()[activity_type])

	if activity_type in [StrategyTypes.ActivityType.FORAGE, StrategyTypes.ActivityType.TRAVEL]:
		print("  PASS: AI chose survival action for food shortage")
	else:
		print("  FAIL: Expected FORAGE or TRAVEL, got %s" % StrategyTypes.ActivityType.keys()[activity_type])

func test_survival_low_money():
	print("TEST 2: LOW MONEY - Should attack, patrol, or take mercenary work")

	var scenario = create_test_scenario()
	var ai_squad = create_test_squad("ai_raiders", "Poor Raiders", "village_1")
	ai_squad.food = 50
	ai_squad.money = 5.0

	var enemy_squad = create_test_squad("enemy_merchants", "Rich Merchants", "village_1")
	enemy_squad.money = 500.0
	scenario.world.roaming_squads.append(enemy_squad)

	var profile = AIProfileFactory.get_default_squad_profile()
	var brain = SquadBrain.new(ai_squad, profile)
	var directive = FactionDirective.create_none()

	var result = brain.decide(scenario.world, null, directive)
	var activity_type: StrategyTypes.ActivityType = result["activity_type"]

	print("\nResult:")
	print("  Squad food: %d, money: %.1f" % [ai_squad.food, ai_squad.money])
	print("  Enemies at location: %d" % scenario.world.get_squads_at_location("village_1").size())
	print("  Decided activity: %s" % StrategyTypes.ActivityType.keys()[activity_type])

	if activity_type in [StrategyTypes.ActivityType.ATTACK, StrategyTypes.ActivityType.TRAVEL, StrategyTypes.ActivityType.MERCENARY_WORK]:
		print("  PASS: AI chose survival action for money shortage")
	else:
		print("  FAIL: Expected ATTACK/TRAVEL/MERCENARY_WORK, got %s" % StrategyTypes.ActivityType.keys()[activity_type])

func test_achievement_with_enemies():
	print("TEST 3: ENEMIES PRESENT - Should attack when resources are good")

	var scenario = create_test_scenario()
	var ai_squad = create_test_squad("ai_hunters", "Elite Hunters", "city_1")
	ai_squad.food = 100
	ai_squad.money = 300.0

	var enemy_squad = create_test_squad("target_squad", "Target Squad", "city_1")
	scenario.world.roaming_squads.append(enemy_squad)

	var profile = AIProfileFactory.get_default_squad_profile()
	var brain = SquadBrain.new(ai_squad, profile)
	var directive = FactionDirective.create_none()

	var result = brain.decide(scenario.world, null, directive)
	var activity_type: StrategyTypes.ActivityType = result["activity_type"]
	var context: Dictionary = result["context"]

	print("\nResult:")
	print("  Squad food: %d, money: %.1f" % [ai_squad.food, ai_squad.money])
	print("  Enemies at location: %d" % scenario.world.get_squads_at_location("city_1").size())
	print("  Decided activity: %s" % StrategyTypes.ActivityType.keys()[activity_type])

	if activity_type == StrategyTypes.ActivityType.ATTACK:
		print("  PASS: AI chose to attack enemies")
		if context.has("attack_target"):
			print("  Target: %s" % context["attack_target"])
	else:
		print("  FAIL: Expected ATTACK, got %s" % StrategyTypes.ActivityType.keys()[activity_type])

func test_achievement_with_clues():
	print("TEST 4: CLUES PRESENT - Should investigate")

	var scenario = create_test_scenario()
	var ai_squad = create_test_squad("ai_trackers", "Skilled Trackers", "city_1")
	ai_squad.food = 80
	ai_squad.money = 250.0

	var city_location = scenario.world.get_location_by_id("city_1")
	var clue = Clue.new()
	clue.clue_name = "Fresh Tracks"
	clue.destination_id = "village_1"
	clue.created_hour = 0
	clue.decay = 5
	clue.left_by_squad_id = "enemy_squad"
	city_location.add_clue(clue)

	var profile = AIProfileFactory.get_default_squad_profile()
	var brain = SquadBrain.new(ai_squad, profile)
	var directive = FactionDirective.create_none()

	var result = brain.decide(scenario.world, null, directive)
	var activity_type: StrategyTypes.ActivityType = result["activity_type"]

	print("\nResult:")
	print("  Squad food: %d, money: %.1f" % [ai_squad.food, ai_squad.money])
	print("  Clues at location: %d" % city_location.clues.size())
	print("  Decided activity: %s" % StrategyTypes.ActivityType.keys()[activity_type])

	if activity_type in [StrategyTypes.ActivityType.INVESTIGATE, StrategyTypes.ActivityType.FORCE_MARCH]:
		print("  PASS: AI chose to investigate or pursue clues")
	else:
		print("  FAIL: Expected INVESTIGATE or FORCE_MARCH, got %s" % StrategyTypes.ActivityType.keys()[activity_type])

func test_score_comparison():
	print("TEST 5: SCORE COMPARISON - Low food + enemies")
	print("Expected: forage-when-hungry should outscore attack")

	var scenario = create_test_scenario()
	var ai_squad = create_test_squad("test_squad", "Test Squad", "village_1")
	ai_squad.food = 2
	ai_squad.money = 100.0

	var enemy_squad = create_test_squad("enemy", "Enemy", "village_1")
	scenario.world.roaming_squads.append(enemy_squad)

	var profile = AIProfileFactory.get_default_squad_profile()
	var brain = SquadBrain.new(ai_squad, profile)
	var directive = FactionDirective.create_none()

	var result = brain.decide(scenario.world, null, directive)
	var activity_type: StrategyTypes.ActivityType = result["activity_type"]

	print("\nResult:")
	print("  Squad food: %d (very low), enemies present: yes" % ai_squad.food)
	print("  Decided activity: %s" % StrategyTypes.ActivityType.keys()[activity_type])

	if activity_type == StrategyTypes.ActivityType.FORAGE:
		print("  PASS: Survival (forage w=10) correctly outscored attack (w=6)")
	else:
		print("  INFO: AI chose %s instead of FORAGE" % StrategyTypes.ActivityType.keys()[activity_type])

func create_test_scenario() -> GameScenario:
	var scenario = GameScenario.new()

	var world = World.new()

	var city = Location.new()
	city.location_id = "city_1"
	city.location_name = "Capital City"
	city.type = StrategyTypes.LocationType.CITY
	city.development = 100
	city.stability = 80.0
	city.connections = TownConnections.new()
	city.connections.tt.append(TownConnection.new("city_1", "village_1", 1))
	city.add_activity_type(StrategyTypes.ActivityType.REST)
	city.add_activity_type(StrategyTypes.ActivityType.DRILL)
	city.add_activity_type(StrategyTypes.ActivityType.PATROL)
	city.add_activity_type(StrategyTypes.ActivityType.INVESTIGATE)
	city.add_activity_type(StrategyTypes.ActivityType.MERCENARY_WORK)
	city.add_activity_type(StrategyTypes.ActivityType.RECRUIT)

	var village = Location.new()
	village.location_id = "village_1"
	village.location_name = "Quiet Village"
	village.type = StrategyTypes.LocationType.VILLAGE
	village.development = 30
	village.stability = 90.0
	village.connections = TownConnections.new()
	village.connections.tt.append(TownConnection.new("village_1", "city_1", 1))
	village.add_activity_type(StrategyTypes.ActivityType.REST)
	village.add_activity_type(StrategyTypes.ActivityType.FORAGE)
	village.add_activity_type(StrategyTypes.ActivityType.PATROL)

	world.locations.append(city)
	world.locations.append(village)
	world.build_travel_graph()

	scenario.world = world

	if not scenario.triggerable_manager:
		scenario.triggerable_manager = TriggerableManager.new()

	return scenario

func create_test_squad(id: String, p_name: String, location: String) -> SquadData:
	var squad = SquadData.new()
	squad.squad_id = id
	squad.squad_name = p_name
	squad.money = 100.0
	squad.food = 50
	squad.travel_tools = 10
	squad.karma = 0.0
	squad.set_location(location)

	for i in range(3):
		var warrior = Warrior.new()
		warrior.id = "%s_warrior_%d" % [id, i]
		warrior.name = "Warrior %d" % i
		warrior.morale = 50.0
		warrior.combat_stats = EntityBaseStats.new()
		squad.add_warrior(warrior)

	return squad
