extends Node

## Demo script to test AIRunner decision-making logic
## Tests both SURVIVAL and ACHIEVEMENT modes with various scenarios

func _ready():
	print("\n=== AI RUNNER DECISION-MAKING DEMO ===\n")
	
	test_survival_mode_low_food()
	print("\n" + "=".repeat(60) + "\n")
	
	test_survival_mode_low_money()
	print("\n" + "=".repeat(60) + "\n")
	
	test_achievement_mode_with_enemies()
	print("\n" + "=".repeat(60) + "\n")
	
	test_achievement_mode_with_clues()
	print("\n" + "=".repeat(60) + "\n")
	
	test_survival_urgency_calculation()
	print("\n" + "=".repeat(60) + "\n")
	
	print("\n=== ALL TESTS COMPLETE ===\n")

func test_survival_mode_low_food():
	print("TEST 1: SURVIVAL MODE - Low Food")
	print("Expected: AI should forage or travel to town for supplies")
	
	var scenario = create_test_scenario()
	var ai_squad = create_test_squad("ai_bandits", "Desperate Bandits", "village_1")
	ai_squad.food = 10 # Critical low
	ai_squad.money = 100.0 # Good money
	
	var ai_runner = AIRunner.new()
	ai_runner.setup(scenario, ai_squad)
	
	var context = {}
	var decision = ai_runner.decide_activity(scenario.world, context)
	
	print("\nResult:")
	print("  SquadCombatData food: %d (critical threshold: 20)" % ai_squad.food)
	print("  SquadCombatData money: %.1f" % ai_squad.money)
	print("  Survival urgency: %.2f" % ai_runner.survival_urgency)
	print("  Decision mode: %s" % AIRunner.DecisionMode.keys()[ai_runner.get_decision_mode()])
	print("  Decided activity: %s" % StrategyTypes.ActivityType.keys()[decision])
	
	if decision in [StrategyTypes.ActivityType.FORAGE, StrategyTypes.ActivityType.TRAVEL]:
		print("  ✓ PASS: AI chose survival action for food shortage")
	else:
		print("  ✗ FAIL: Expected FORAGE or TRAVEL, got %s" % StrategyTypes.ActivityType.keys()[decision])

func test_survival_mode_low_money():
	print("TEST 2: SURVIVAL MODE - Low Money")
	print("Expected: AI should attack for loot, patrol, or take mercenary work")
	
	var scenario = create_test_scenario()
	var ai_squad = create_test_squad("ai_raiders", "Poor Raiders", "village_1")
	ai_squad.food = 50 # Good food
	ai_squad.money = 30.0 # Critical low
	
	# Add enemy squad at same location for AI to attack
	var enemy_squad = create_test_squad("enemy_merchants", "Rich Merchants", "village_1")
	enemy_squad.money = 500.0
	scenario.world.roaming_squads.append(enemy_squad)
	
	var ai_runner = AIRunner.new()
	ai_runner.setup(scenario, ai_squad)
	
	var context = {}
	var decision = ai_runner.decide_activity(scenario.world, context)
	
	print("\nResult:")
	print("  SquadCombatData food: %d" % ai_squad.food)
	print("  SquadCombatData money: %.1f (critical threshold: 50)" % ai_squad.money)
	print("  Survival urgency: %.2f" % ai_runner.survival_urgency)
	print("  Decision mode: %s" % AIRunner.DecisionMode.keys()[ai_runner.get_decision_mode()])
	print("  Decided activity: %s" % StrategyTypes.ActivityType.keys()[decision])
	print("  Enemies at location: %d" % scenario.world.get_squads_at_location("village_1").size())
	
	if decision in [StrategyTypes.ActivityType.ATTACK, StrategyTypes.ActivityType.PATROL, StrategyTypes.ActivityType.MERCENARY_WORK]:
		print("  ✓ PASS: AI chose survival action for money shortage")
	else:
		print("  ✗ FAIL: Expected ATTACK/PATROL/MERCENARY_WORK, got %s" % StrategyTypes.ActivityType.keys()[decision])

func test_achievement_mode_with_enemies():
	print("TEST 3: ACHIEVEMENT MODE - Enemies Present")
	print("Expected: AI should attack enemies when resources are good")
	
	var scenario = create_test_scenario()
	var ai_squad = create_test_squad("ai_hunters", "Elite Hunters", "city_1")
	ai_squad.food = 100 # Plenty
	ai_squad.money = 300.0 # Plenty
	
	# Add enemy squad at same location
	var enemy_squad = create_test_squad("target_squad", "Target SquadCombatData", "city_1")
	scenario.world.roaming_squads.append(enemy_squad)
	
	var ai_runner = AIRunner.new()
	ai_runner.setup(scenario, ai_squad)
	
	var context = {}
	var decision = ai_runner.decide_activity(scenario.world, context)
	
	print("\nResult:")
	print("  SquadCombatData food: %d" % ai_squad.food)
	print("  SquadCombatData money: %.1f" % ai_squad.money)
	print("  Survival urgency: %.2f" % ai_runner.survival_urgency)
	print("  Decision mode: %s" % AIRunner.DecisionMode.keys()[ai_runner.get_decision_mode()])
	print("  Decided activity: %s" % StrategyTypes.ActivityType.keys()[decision])
	print("  Enemies at location: %d" % scenario.world.get_squads_at_location("city_1").size())
	
	if decision == StrategyTypes.ActivityType.ATTACK:
		print("  ✓ PASS: AI chose to attack enemies in achievement mode")
		if context.has("attack_target"):
			print("  ✓ Target specified: %s" % context["attack_target"])
	else:
		print("  ✗ FAIL: Expected ATTACK, got %s" % StrategyTypes.ActivityType.keys()[decision])

func test_achievement_mode_with_clues():
	print("TEST 4: ACHIEVEMENT MODE - Following Clues")
	print("Expected: AI should investigate clues or pursue them")
	
	var scenario = create_test_scenario()
	var ai_squad = create_test_squad("ai_trackers", "Skilled Trackers", "city_1")
	ai_squad.food = 80
	ai_squad.money = 250.0
	
	# Add clues at current location pointing to another location
	var city_location = scenario.world.get_location_by_id("city_1")
	var clue = Clue.new()
	clue.clue_name = "Fresh Tracks"
	clue.destination_id = "village_1"
	clue.created_turn = 0
	clue.decay = 5
	clue.left_by_squad_id = "enemy_squad"
	city_location.add_clue(clue)
	
	var ai_runner = AIRunner.new()
	ai_runner.setup(scenario, ai_squad)
	
	var context = {}
	var decision = ai_runner.decide_activity(scenario.world, context)
	
	print("\nResult:")
	print("  SquadCombatData food: %d" % ai_squad.food)
	print("  SquadCombatData money: %.1f" % ai_squad.money)
	print("  Survival urgency: %.2f" % ai_runner.survival_urgency)
	print("  Decision mode: %s" % AIRunner.DecisionMode.keys()[ai_runner.get_decision_mode()])
	print("  Decided activity: %s" % StrategyTypes.ActivityType.keys()[decision])
	print("  Clues at location: %d" % city_location.clues.size())
	
	if decision in [StrategyTypes.ActivityType.INVESTIGATE, StrategyTypes.ActivityType.FORCE_MARCH]:
		print("  ✓ PASS: AI chose to investigate or pursue clues")
		if decision == StrategyTypes.ActivityType.FORCE_MARCH and context.has("travel_destination"):
			print("  ✓ Pursuing to: %s" % context["travel_destination"])
	else:
		print("  ✗ FAIL: Expected INVESTIGATE or FORCE_MARCH, got %s" % StrategyTypes.ActivityType.keys()[decision])

func test_survival_urgency_calculation():
	print("TEST 5: SURVIVAL URGENCY CALCULATION")
	print("Expected: Various resource levels produce correct urgency values")
	
	var scenario = create_test_scenario()
	var ai_runner = AIRunner.new()
	
	var test_cases = [
		{"food": 100, "money": 300.0, "expected_urgency": "<0.2", "desc": "Comfortable"},
		{"food": 40, "money": 150.0, "expected_urgency": "~0.0", "desc": "At threshold"},
		{"food": 20, "money": 100.0, "expected_urgency": "~0.5", "desc": "Moderate urgency"},
		{"food": 15, "money": 40.0, "expected_urgency": ">0.8", "desc": "High urgency"},
		{"food": 5, "money": 10.0, "expected_urgency": "~1.0", "desc": "Critical"},
	]
	
	print("\nResults:")
	for test_case in test_cases:
		var squad = create_test_squad("test_squad", "Test SquadCombatData", "city_1")
		squad.food = test_case["food"]
		squad.money = test_case["money"]
		
		ai_runner.assigned_squad = squad
		var urgency = ai_runner.calculate_survival_urgency()
		var mode = ai_runner.get_decision_mode()
		
		print("  %s: food=%d, money=%.0f → urgency=%.2f, mode=%s" % [
			test_case["desc"],
			squad.food,
			squad.money,
			urgency,
			AIRunner.DecisionMode.keys()[mode]
		])

func create_test_scenario() -> GameScenario:
	var scenario = GameScenario.new()
	
	# Create world with locations
	var world = World.new()
	
	# City with all activities
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
	
	# Village with basic activities
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
	
	# Initialize triggerable manager
	if not scenario.triggerable_manager:
		scenario.triggerable_manager = TriggerableManager.new()
	
	return scenario

func create_test_squad(id: String, name: String, location: String) -> SquadStrategicData:
	var squad = SquadStrategicData.new()
	squad.squad_id = id
	squad.squad_name = name
	squad.money = 100.0
	squad.food = 50
	squad.travel_tools = 10
	squad.karma = 0.0
	squad.set_location(location)
	
	# Add some warriors
	for i in range(3):
		var warrior = CharacterSocialStats.new()
		warrior.id = "%s_warrior_%d" % [id, i]
		warrior.name = "CharacterSocialStats %d" % i
		warrior.morale = 50.0
		warrior.combat_stats = EntityBaseStats.new()
		squad.add_warrior(warrior)
	
	squad.ensure_initialized()
	return squad
