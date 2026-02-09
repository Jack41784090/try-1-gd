extends Node2D

# Comprehensive test suite for the consideration system

var test_count := 0
var passed_count := 0
var failed_count := 0

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("CONSIDERATION SYSTEM - COMPREHENSIVE TEST SUITE")
	print("=".repeat(80) + "\n")
	
	# Run all test suites
	test_entity_considerations()
	test_context_considerations()
	test_situation_considerations()
	test_action_considerations()
	test_logic_configuration_resources()
	test_complex_scenarios()
	
	# Print final results
	print("\n" + "=".repeat(80))
	print("TEST RESULTS")
	print("=".repeat(80))
	print("Total Tests: %d" % test_count)
	print("Passed: %d" % passed_count)
	print("Failed: %d" % failed_count)
	if failed_count == 0:
		print("\n✓ ALL TESTS PASSED!")
	else:
		print("\n✗ SOME TESTS FAILED!")
	print("=".repeat(80) + "\n")

# ============================================================================
# TEST SUITE 1: Glance-based Entity Property Tests
# ============================================================================

func test_entity_considerations() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 1: Glance-based Entity Property Tests")
	print("-".repeat(80) + "\n")
	
	test_glance_hp_percentage_below()
	test_glance_hp_percentage_above()
	test_glance_hp_absolute_value()
	test_glance_location_detection()

func test_glance_hp_percentage_below() -> void:
	start_test("Glance: HP below 30% (percentage)")
	
	var entity = create_test_entity({
		"hp": 25.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var glance = Glance.new()
	glance.property = SquadBattleTypes.EntityChangeable.HP
	glance.normalize_as_percentage = true
	glance.use_comparison = true
	glance.comparison = CsdrTypes.DETECTION.BELOW
	glance.threshold = 0.3
	
	var consideration = Consideration.new()
	consideration.glances.append(glance)
	consideration.entity_limiter = "self"
	consideration.weight = 50.0
	consideration.op = CsdrTypes.OP.ADD
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 50.0, "Should return weight when HP < 30%")
	end_test()

func test_glance_hp_percentage_above() -> void:
	start_test("Glance: HP above 50% (percentage)")
	
	var entity = create_test_entity({
		"hp": 75.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Middle
	})
	
	var glance = Glance.new()
	glance.property = SquadBattleTypes.EntityChangeable.HP
	glance.normalize_as_percentage = true
	glance.use_comparison = true
	glance.comparison = CsdrTypes.DETECTION.ABOVE
	glance.threshold = 0.5
	
	var consideration = Consideration.new()
	consideration.glances.append(glance)
	consideration.entity_limiter = "self"
	consideration.weight = 10.0
	consideration.op = CsdrTypes.OP.ADD
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 10.0, "Should return weight when HP > 50%")
	end_test()

func test_glance_hp_absolute_value() -> void:
	start_test("Glance: HP equal to 50 (absolute)")
	
	var entity = create_test_entity({
		"hp": 50.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Back
	})
	
	var glance = Glance.new()
	glance.property = SquadBattleTypes.EntityChangeable.HP
	glance.use_comparison = true
	glance.comparison = CsdrTypes.DETECTION.EQUAL
	glance.threshold = 50.0
	
	var consideration = Consideration.new()
	consideration.glances.append(glance)
	consideration.entity_limiter = "self"
	consideration.weight = 25.0
	consideration.op = CsdrTypes.OP.ADD
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 25.0, "Should return weight when HP equals 50")
	end_test()

func test_glance_location_detection() -> void:
	start_test("Glance: Location detection")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Middle
	})
	
	var glance = Glance.new()
	glance.property = SquadBattleTypes.EntityChangeable.LOC
	glance.use_comparison = true
	glance.comparison = CsdrTypes.DETECTION.EQUAL
	glance.threshold = SquadBattleTypes.SquadEntityInSquadLocation.Middle
	
	var consideration = Consideration.new()
	consideration.glances.append(glance)
	consideration.entity_limiter = "self"
	consideration.weight = 1.0
	consideration.op = CsdrTypes.OP.ADD
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 1.0, "Should detect entity at Middle location")
	end_test()

# ============================================================================
# TEST SUITE 2: Glance-based Multi-Entity Tests
# ============================================================================

func test_context_considerations() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 2: Glance-based Multi-Entity Tests")
	print("-".repeat(80) + "\n")
	
	test_glance_enemy_hp_evaluation()
	test_glance_allies_evaluation()
	test_glance_average_operation()

func test_glance_enemy_hp_evaluation() -> void:
	start_test("Glance: Evaluate enemy HP using entity_limiter")
	
	var ally = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"player_id": 800
	})
	var enemy1 = create_test_entity({
		"hp": 30.0,
		"max_hp": 100.0,
		"player_id": 500
	})
	var enemy2 = create_test_entity({
		"hp": 20.0,
		"max_hp": 100.0,
		"player_id": 501
	})
	
	var context = {
		"entity": ally,
		"our_squad": {1: [ally]},
		"enemy_squad": {1: [enemy1, enemy2]}
	}
	var situation = Situation.new(context)
	
	var glance = Glance.new()
	glance.property = SquadBattleTypes.EntityChangeable.HP
	glance.normalize_as_percentage = true
	glance.use_comparison = true
	glance.comparison = CsdrTypes.DETECTION.BELOW
	glance.threshold = 0.5
	
	var consideration = Consideration.new()
	consideration.glances.append(glance)
	consideration.entity_limiter = "enemies"
	consideration.weight = 10.0
	consideration.op = CsdrTypes.OP.ADD
	
	var score = consideration.score(ally, situation, context)
	
	assert_equal(score, 20.0, "Should sum 2 low HP enemies: 10 + 10")
	end_test()

func test_glance_allies_evaluation() -> void:
	start_test("Glance: Evaluate allies using entity_limiter")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"player_id": 800
	})
	var ally1 = create_test_entity({
		"hp": 50.0,
		"max_hp": 100.0,
		"player_id": 801
	})
	var ally2 = create_test_entity({
		"hp": 75.0,
		"max_hp": 100.0,
		"player_id": 802
	})
	
	var context = {
		"entity": entity,
		"our_squad": {1: [entity, ally1, ally2]},
		"enemy_squad": {}
	}
	var situation = Situation.new(context)
	
	var glance = Glance.new()
	glance.property = SquadBattleTypes.EntityChangeable.HP
	glance.normalize_as_percentage = false
	
	var consideration = Consideration.new()
	consideration.glances.append(glance)
	consideration.entity_limiter = "allies"
	consideration.weight = 1.0
	consideration.op = CsdrTypes.OP.AVG
	
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 75.0, "Should average ally HP: (100 + 50 + 75) / 3 = 75")
	end_test()

func test_glance_average_operation() -> void:
	start_test("Glance: Average operation across multiple entities")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"player_id": 800
	})
	var enemy1 = create_test_entity({
		"hp": 40.0,
		"max_hp": 100.0,
		"player_id": 500
	})
	var enemy2 = create_test_entity({
		"hp": 60.0,
		"max_hp": 100.0,
		"player_id": 501
	})
	
	var context = {
		"entity": entity,
		"our_squad": {1: [entity]},
		"enemy_squad": {1: [enemy1, enemy2]}
	}
	var situation = Situation.new(context)
	
	var glance = Glance.new()
	glance.property = SquadBattleTypes.EntityChangeable.HP
	glance.normalize_as_percentage = true
	
	var consideration = Consideration.new()
	consideration.glances.append(glance)
	consideration.entity_limiter = "enemies"
	consideration.weight = 1.0
	consideration.op = CsdrTypes.OP.AVG
	
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 0.5, "Should average enemy HP: (0.4 + 0.6) / 2 = 0.5")
	end_test()

# ============================================================================
# TEST SUITE 3: Glance Chaining Tests
# ============================================================================

func test_situation_considerations() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 3: Glance Chaining Tests")
	print("-".repeat(80) + "\n")
	
	test_glance_chaining_add()
	test_glance_chaining_avg()
	test_glance_multi_glance_consideration()

func test_glance_chaining_add() -> void:
	start_test("Glance: Chaining with ADD operation")
	
	var entity = create_test_entity({
		"hp": 50.0,
		"org": 30.0
	})
	
	var glance2 = Glance.new()
	glance2.property = SquadBattleTypes.EntityChangeable.ORG
	
	var glance1 = Glance.new()
	glance1.property = SquadBattleTypes.EntityChangeable.HP
	glance1.additional_glance = glance2
	glance1.operation_on_other_glance = CsdrTypes.OP.ADD
	
	var value = glance1.evaluate(entity)
	
	assert_equal(value, 80.0, "Should return HP + ORG = 80")
	end_test()

func test_glance_chaining_avg() -> void:
	start_test("Glance: Chaining with AVG operation")
	
	var entity = create_test_entity({
		"hp": 80.0,
		"org": 40.0
	})
	
	var glance2 = Glance.new()
	glance2.property = SquadBattleTypes.EntityChangeable.ORG
	
	var glance1 = Glance.new()
	glance1.property = SquadBattleTypes.EntityChangeable.HP
	glance1.additional_glance = glance2
	glance1.operation_on_other_glance = CsdrTypes.OP.AVG
	
	var value = glance1.evaluate(entity)
	
	assert_equal(value, 60.0, "Should return (HP + ORG) / 2 = 60")
	end_test()

func test_glance_multi_glance_consideration() -> void:
	start_test("Consideration: Multiple glances in single consideration")
	
	var entity = create_test_entity({
		"hp": 60.0,
		"max_hp": 100.0,
		"org": 40.0,
		"max_org": 100.0
	})
	
	var hp_glance = Glance.new()
	hp_glance.property = SquadBattleTypes.EntityChangeable.HP
	hp_glance.normalize_as_percentage = true
	
	var org_glance = Glance.new()
	org_glance.property = SquadBattleTypes.EntityChangeable.ORG
	org_glance.normalize_as_percentage = true
	
	var consideration = Consideration.new()
	consideration.glances.append(hp_glance)
	consideration.glances.append(org_glance)
	consideration.entity_limiter = "self"
	consideration.weight = 1.0
	consideration.op = CsdrTypes.OP.AVG
	consideration.average_score_between_glances = true
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 0.5, "Should average normalized HP and ORG")
	end_test()

# ============================================================================
# TEST SUITE 4: Skill-based Consideration Tests
# ============================================================================

func test_action_considerations() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 4: Skill-based Consideration Tests")
	print("-".repeat(80) + "\n")
	
	test_skill_consideration_with_condition()
	test_skill_consideration_no_condition()
	test_skill_selection_logic()

func test_skill_consideration_with_condition() -> void:
	start_test("Consideration: Skill with HP condition")
	
	var entity = create_test_entity({
		"hp": 20.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var heal_skill = Skill.new("Heal", [])
	
	var glance = Glance.new()
	glance.property = SquadBattleTypes.EntityChangeable.HP
	glance.normalize_as_percentage = true
	glance.use_comparison = true
	glance.comparison = CsdrTypes.DETECTION.BELOW
	glance.threshold = 0.3
	
	var consideration = Consideration.new()
	consideration.glances.append(glance)
	consideration.entity_limiter = "self"
	consideration.weight = 50.0
	consideration.op = CsdrTypes.OP.ADD
	consideration.returning = heal_skill
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 50.0, "Should return weight when condition met")
	end_test()

func test_skill_consideration_no_condition() -> void:
	start_test("Consideration: Skill without condition (always valid)")
	
	var entity = create_test_entity({})
	var context = create_basic_context(entity)
	
	var attack_skill = Skill.new("Attack", [])
	
	var consideration = Consideration.new()
	# glances already initialized as empty array
	consideration.entity_limiter = "self"
	consideration.weight = 5.0
	consideration.op = CsdrTypes.OP.ADD
	consideration.returning = attack_skill
	
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 5.0, "Should return the default weight when no glances (no condition)")
	end_test()

func test_skill_selection_logic() -> void:
	start_test("SimplifiedSquadLogic: Skill selection with multiple considerations")
	
	var entity = create_test_entity({
		"hp": 25.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var heal_skill = Skill.new("Heal", [])
	var attack_skill = Skill.new("Attack", [])
	
	var low_hp_glance = Glance.new()
	low_hp_glance.property = SquadBattleTypes.EntityChangeable.HP
	low_hp_glance.normalize_as_percentage = true
	low_hp_glance.use_comparison = true
	low_hp_glance.comparison = CsdrTypes.DETECTION.BELOW
	low_hp_glance.threshold = 0.3
	
	var heal_consideration = Consideration.new()
	heal_consideration.name = "Heal when low HP"
	heal_consideration.glances.append(low_hp_glance)
	heal_consideration.entity_limiter = "self"
	heal_consideration.weight = 100.0
	heal_consideration.returning = heal_skill
	heal_consideration.op = CsdrTypes.OP.ADD
	
	var attack_consideration = Consideration.new()
	attack_consideration.name = "Attack"
	attack_consideration.weight = 10.0
	attack_consideration.returning = attack_skill
	attack_consideration.op = CsdrTypes.OP.ADD
	
	var config = SimplifiedLogicConfig.new()
	config.considerations.append(heal_consideration)
	config.considerations.append(attack_consideration)
	
	var context = create_basic_context(entity)
	var logic = SimplifiedSquadLogic.new(context, config)
	var chosen_skill = logic.choose_skill()
	
	assert_equal(chosen_skill.name, "Heal", "Should choose Heal skill due to low HP")
	end_test()

# ============================================================================
# TEST SUITE 5: Logic Configuration Resources
# ============================================================================

func test_logic_configuration_resources() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 5: Logic Configuration Resources")
	print("-".repeat(80) + "\n")
	
	test_load_stay_backline_heal_resource()
	test_create_custom_configuration()

func test_load_stay_backline_heal_resource() -> void:
	start_test("Load stay-backline-heal.tres resource")
	
	var logic_conf = load("res://resources/combat/logic/logic/stay-backline-heal.tres") as SimplifiedLogicConfig
	
	assert_not_null(logic_conf, "Resource should load successfully")
	assert_true(logic_conf.considerations.size() > 0, "Should have considerations")
	end_test()

func test_create_custom_configuration() -> void:
	start_test("Create custom SimplifiedLogicConfig programmatically")
	
	var entity = create_test_entity({
		"hp": 20.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var heal_skill = Skill.new("Heal", [])
	
	var hp_glance = Glance.new()
	hp_glance.property = SquadBattleTypes.EntityChangeable.HP
	hp_glance.normalize_as_percentage = true
	hp_glance.use_comparison = true
	hp_glance.comparison = CsdrTypes.DETECTION.BELOW
	hp_glance.threshold = 0.3
	
	var heal_consideration = Consideration.new()
	heal_consideration.glances.append(hp_glance)
	heal_consideration.entity_limiter = "self"
	heal_consideration.weight = 50.0
	heal_consideration.returning = heal_skill
	heal_consideration.op = CsdrTypes.OP.ADD
	
	var attack_skill = Skill.new("Attack", [])
	var attack_consideration = Consideration.new()
	attack_consideration.weight = 1.0
	attack_consideration.returning = attack_skill
	attack_consideration.op = CsdrTypes.OP.ADD
	
	var config = SimplifiedLogicConfig.new()
	config.considerations.append(heal_consideration)
	config.considerations.append(attack_consideration)
	
	var context = create_basic_context(entity)
	var logic = SimplifiedSquadLogic.new(context, config)
	var chosen_skill = logic.choose_skill()
	
	assert_equal(chosen_skill.name, "Heal", "Should choose Heal when HP low")
	end_test()

# ============================================================================
# TEST SUITE 6: Complex Scenarios
# ============================================================================

func test_complex_scenarios() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 6: Complex Scenarios")
	print("-".repeat(80) + "\n")
	
	test_scenario_low_hp_heal()
	test_scenario_location_based_skills()
	test_scenario_priority_resolution()

func test_scenario_low_hp_heal() -> void:
	start_test("Scenario: Low HP entity should use heal skill")
	
	var entity = create_test_entity({
		"hp": 15.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var config = create_heal_on_low_hp_config()
	var context = create_basic_context(entity)
	var logic = SimplifiedSquadLogic.new(context, config)
	
	var skill = logic.choose_skill()
	
	assert_equal(skill.name, "Heal", "Entity with 15% HP should use heal skill")
	end_test()

func test_scenario_location_based_skills() -> void:
	start_test("Scenario: Location-based skill selection")
	
	var frontline_entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var backline_entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Back
	})
	
	var config = create_location_based_config()
	
	var frontline_context = create_basic_context(frontline_entity)
	var frontline_logic = SimplifiedSquadLogic.new(frontline_context, config)
	var frontline_skill = frontline_logic.choose_skill()
	
	var backline_context = create_basic_context(backline_entity)
	var backline_logic = SimplifiedSquadLogic.new(backline_context, config)
	var backline_skill = backline_logic.choose_skill()
	
	assert_equal(frontline_skill.name, "Attack", "Frontline entity should attack")
	assert_equal(backline_skill.name, "Move Forward", "Backline entity should move forward")
	end_test()

func test_scenario_priority_resolution() -> void:
	start_test("Scenario: Higher weight skill wins")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var attack_skill = Skill.new("Attack", [])
	var attack_consideration = Consideration.new()
	attack_consideration.weight = 10.0
	attack_consideration.returning = attack_skill
	attack_consideration.op = CsdrTypes.OP.ADD
	
	var heal_skill = Skill.new("Heal", [])
	var heal_consideration = Consideration.new()
	heal_consideration.weight = 50.0
	heal_consideration.returning = heal_skill
	heal_consideration.op = CsdrTypes.OP.ADD
	
	var config = SimplifiedLogicConfig.new()
	config.considerations.append(attack_consideration)
	config.considerations.append(heal_consideration)
	
	var context = create_basic_context(entity)
	var logic = SimplifiedSquadLogic.new(context, config)
	var skill = logic.choose_skill()
	
	assert_equal(skill.name, "Heal", "Should choose Heal with weight 50 over Attack with weight 10")
	end_test()

# ============================================================================
# Helper Functions
# ============================================================================

func create_test_entity(config: Dictionary) -> CharacterCombatStat:
	# Create entity with proper stats initialization
	var stats = EntityBaseStats.new()
	stats.endurance = 10.0 # Will give HP = 10*5 + 5*2 = 60
	stats.siz = 5.0
	stats.strength = 5.0
	stats.dex = 5.0
	stats.acr = 5.0
	stats.spd = 5.0
	stats.int_stat = 5.0
	stats.spr = 5.0
	stats.fai = 5.0
	stats.cha = 5.0
	stats.beu = 5.0
	stats.wil = 5.0
	
	var entity_config = EntityConfig.new(
		EntityFactory.EntityClasses.Landsknecht,
		config.get("player_id", 0),
		"Test Entity",
		"test",
		stats,
		config.get("location", SquadBattleTypes.SquadEntityInSquadLocation.Front),
		LogicFactory.LogicAvailable.Frontline,
		null,
		WeaponFactory.WeaponClasses.Unarmed,
		null,
		ArmorFactory.ArmorClasses.Unarmored
	)
	
	if config.has("max_hp"):
		var desired_max = config["max_hp"]
		stats.endurance = (desired_max - 3) / (stats.siz * 10)
	
	if config.has("max_org"):
		var desired_max_org = config["max_org"]
		stats.wil = (desired_max_org - 1) / stats.fai

	var entity = CharacterCombatStat.new(entity_config)
	
	# Override HP if specified (after initialise_changeables is called by constructor)
	if config.has("hp"):
		entity.changeable_stats[SquadBattleTypes.EntityChangeable.HP] = config["hp"]
	if config.has("org"):
		entity.changeable_stats[SquadBattleTypes.EntityChangeable.ORG] = config["org"]
	if config.has("location"):
		entity.changeable_stats[SquadBattleTypes.EntityChangeable.LOC] = config["location"]
	
	return entity

func create_basic_context(entity: CharacterCombatStat) -> Dictionary:
	var our_squad = {}
	# var enemy_squad = {}

	our_squad[entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC)] = [entity]
	return {
		"entity": entity,
		"our_squad": our_squad,
		"enemy_squad": {}
	}

func create_outnumbered_scenario(entity: CharacterCombatStat, ally_count: int, enemy_count: int) -> Dictionary:
	var allies = create_entities_at_location(ally_count, SquadBattleTypes.SquadEntityInSquadLocation.Front)
	var enemies = create_entities_at_location(enemy_count, SquadBattleTypes.SquadEntityInSquadLocation.Front)
	
	return {
		"entity": entity,
		"our_squad": {
			SquadBattleTypes.SquadEntityInSquadLocation.Front: allies
		},
		"enemy_squad": {
			SquadBattleTypes.SquadEntityInSquadLocation.Front: enemies
		}
	}

func create_entities_at_location(count: int, location: int) -> Array:
	var entities = []
	for i in range(count):
		var e = create_test_entity({
			"hp": 100.0,
			"max_hp": 100.0,
			"location": location
		})
		entities.append(e)
	return entities

func create_heal_on_low_hp_config() -> SimplifiedLogicConfig:
	var heal_skill = Skill.new("Heal", [])
	
	var hp_glance = Glance.new()
	hp_glance.property = SquadBattleTypes.EntityChangeable.HP
	hp_glance.normalize_as_percentage = true
	hp_glance.use_comparison = true
	hp_glance.comparison = CsdrTypes.DETECTION.BELOW
	hp_glance.threshold = 0.3
	
	var heal_consideration = Consideration.new()
	heal_consideration.glances.append(hp_glance)
	heal_consideration.entity_limiter = "self"
	heal_consideration.weight = 100.0
	heal_consideration.returning = heal_skill
	heal_consideration.op = CsdrTypes.OP.ADD
	
	var attack_skill = Skill.new("Attack", [])
	var attack_consideration = Consideration.new()
	attack_consideration.weight = 1.0
	attack_consideration.returning = attack_skill
	attack_consideration.op = CsdrTypes.OP.ADD
	
	var config = SimplifiedLogicConfig.new()
	config.considerations.append(heal_consideration)
	config.considerations.append(attack_consideration)
	
	return config

func create_location_based_config() -> SimplifiedLogicConfig:
	var attack_skill = Skill.new("Attack", [])
	
	var at_frontline_glance = Glance.new()
	at_frontline_glance.property = SquadBattleTypes.EntityChangeable.LOC
	at_frontline_glance.use_comparison = true
	at_frontline_glance.comparison = CsdrTypes.DETECTION.EQUAL
	at_frontline_glance.threshold = SquadBattleTypes.SquadEntityInSquadLocation.Front
	
	var attack_consideration = Consideration.new()
	attack_consideration.glances.append(at_frontline_glance)
	attack_consideration.entity_limiter = "self"
	attack_consideration.weight = 10.0
	attack_consideration.returning = attack_skill
	attack_consideration.op = CsdrTypes.OP.ADD
	
	var move_forward_skill = Skill.new("Move Forward", [])
	
	var not_at_frontline_glance = Glance.new()
	not_at_frontline_glance.property = SquadBattleTypes.EntityChangeable.LOC
	not_at_frontline_glance.use_comparison = true
	not_at_frontline_glance.comparison = CsdrTypes.DETECTION.ABOVE
	not_at_frontline_glance.threshold = SquadBattleTypes.SquadEntityInSquadLocation.Front
	
	var move_forward_consideration = Consideration.new()
	move_forward_consideration.glances.append(not_at_frontline_glance)
	move_forward_consideration.entity_limiter = "self"
	move_forward_consideration.weight = 5.0
	move_forward_consideration.returning = move_forward_skill
	move_forward_consideration.op = CsdrTypes.OP.ADD
	
	var config = SimplifiedLogicConfig.new()
	config.considerations.append(attack_consideration)
	config.considerations.append(move_forward_consideration)
	
	return config

# ============================================================================
# Test Assertion Helpers
# ============================================================================

func start_test(test_name: String) -> void:
	test_count += 1
	print("TEST %d: %s" % [test_count, test_name])

func end_test() -> void:
	print("")

func assert_equal(actual, expected, message: String) -> void:
	if actual == expected:
		print("  ✓ PASS: %s" % message)
		passed_count += 1
	else:
		print("  ✗ FAIL: %s" % message)
		print("    Expected: %s" % str(expected))
		print("    Actual: %s" % str(actual))
		failed_count += 1

func assert_not_null(value, message: String) -> void:
	if value != null:
		print("  ✓ PASS: %s" % message)
		passed_count += 1
	else:
		print("  ✗ FAIL: %s (value is null)" % message)
		failed_count += 1

func assert_true(condition: bool, message: String) -> void:
	if condition:
		print("  ✓ PASS: %s" % message)
		passed_count += 1
	else:
		print("  ✗ FAIL: %s (condition is false)" % message)
		failed_count += 1
