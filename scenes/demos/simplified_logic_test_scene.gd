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
# TEST SUITE 1: EntityConsideration Tests
# ============================================================================

func test_entity_considerations() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 1: EntityConsideration")
	print("-".repeat(80) + "\n")
	
	# Test HP percentage detection
	test_entity_hp_percentage_below()
	test_entity_hp_percentage_above()
	test_entity_hp_absolute_value()
	test_entity_location_detection()

func test_entity_hp_percentage_below() -> void:
	start_test("EntityConsideration: HP below 30% (percentage)")
	
	var entity = create_test_entity({
		"hp": 25.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var consideration = EntityConsideration.new()
	consideration.property = SquadBattleTypes.EntityChangeable.HP
	consideration.detection = CsdrTypes.DETECTION.BELOW
	consideration.value = 0.3
	consideration.percentage = true
	consideration.weight = 50.0
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 50.0, "Should return weight when HP < 30%")
	end_test()

func test_entity_hp_percentage_above() -> void:
	start_test("EntityConsideration: HP above 50% (percentage)")
	
	var entity = create_test_entity({
		"hp": 75.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Middle
	})
	
	var consideration = EntityConsideration.new()
	consideration.property = SquadBattleTypes.EntityChangeable.HP
	consideration.detection = CsdrTypes.DETECTION.ABOVE
	consideration.value = 0.5
	consideration.percentage = true
	consideration.weight = 10.0
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 10.0, "Should return weight when HP > 50%")
	end_test()

func test_entity_hp_absolute_value() -> void:
	start_test("EntityConsideration: HP equal to 50 (absolute)")
	
	var entity = create_test_entity({
		"hp": 50.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Back
	})
	
	var consideration = EntityConsideration.new()
	consideration.property = SquadBattleTypes.EntityChangeable.HP
	consideration.detection = CsdrTypes.DETECTION.EQUAL
	consideration.value = 50.0
	consideration.percentage = false
	consideration.weight = 25.0
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 25.0, "Should return weight when HP equals 50")
	end_test()

func test_entity_location_detection() -> void:
	start_test("EntityConsideration: Location detection")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Middle
	})
	
	var consideration = EntityConsideration.new()
	consideration.property = SquadBattleTypes.EntityChangeable.LOC
	consideration.detection = CsdrTypes.DETECTION.EQUAL
	consideration.value = SquadBattleTypes.SquadEntityInSquadLocation.Middle
	consideration.percentage = false
	consideration.weight = 1.0
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 1.0, "Should detect entity at Middle location")
	end_test()

# ============================================================================
# TEST SUITE 2: ContextConsideration Tests
# ============================================================================

func test_context_considerations() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 2: ContextConsideration")
	print("-".repeat(80) + "\n")
	
	test_context_at_specific_location()
	test_context_at_specific_location_inverted()
	test_context_allies_at_location()

func test_context_at_specific_location() -> void:
	start_test("ContextConsideration: At frontline")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var consideration = ContextConsideration.new()
	consideration.query_type = ContextConsideration.ContextQuery.AT_SPECIFIC_LOCATION
	consideration.target_location = SquadBattleTypes.SquadEntityInSquadLocation.Front
	consideration.weight = 1.0
	consideration.invert = false
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 1.0, "Should return weight when at frontline")
	end_test()

func test_context_at_specific_location_inverted() -> void:
	start_test("ContextConsideration: Not at frontline (inverted)")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Middle
	})
	
	var consideration = ContextConsideration.new()
	consideration.query_type = ContextConsideration.ContextQuery.AT_SPECIFIC_LOCATION
	consideration.target_location = SquadBattleTypes.SquadEntityInSquadLocation.Front
	consideration.weight = 1.0
	consideration.invert = true
	
	var context = create_basic_context(entity)
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 1.0, "Should return weight when NOT at frontline")
	end_test()

func test_context_allies_at_location() -> void:
	start_test("ContextConsideration: Allies at my location")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var ally1 = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var context = {
		"entity": entity,
		"our_squad": {
			SquadBattleTypes.SquadEntityInSquadLocation.Front: [entity, ally1]
		},
		"enemy_squad": {}
	}
	
	var consideration = ContextConsideration.new()
	consideration.query_type = ContextConsideration.ContextQuery.ALLIES_AT_MY_LOCATION
	consideration.weight = 1.0
	
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 1.0, "Should detect allies at same location")
	end_test()

# ============================================================================
# TEST SUITE 3: SituationConsideration Tests
# ============================================================================

func test_situation_considerations() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 3: SituationConsideration")
	print("-".repeat(80) + "\n")
	
	test_situation_outnumbered()
	test_situation_not_outnumbered()
	test_situation_allies_in_location()
	test_situation_enemies_in_location()

func test_situation_outnumbered() -> void:
	start_test("SituationConsideration: Outnumbered (2:1)")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var context = create_outnumbered_scenario(entity, 2, 6)
	
	var consideration = SituationConsideration.new()
	consideration.comparison_type = SituationConsideration.ComparisonType.OUTNUMBERED
	consideration.threshold = 2.0
	consideration.weight = 100.0
	
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 100.0, "Should detect outnumbered situation")
	end_test()

func test_situation_not_outnumbered() -> void:
	start_test("SituationConsideration: Not outnumbered")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var context = create_outnumbered_scenario(entity, 5, 5)
	
	var consideration = SituationConsideration.new()
	consideration.comparison_type = SituationConsideration.ComparisonType.OUTNUMBERED
	consideration.threshold = 2.0
	consideration.weight = 100.0
	
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 0.0, "Should not detect outnumbered when equal")
	end_test()

func test_situation_allies_in_location() -> void:
	start_test("SituationConsideration: Count allies at frontline")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Middle
	})
	
	var allies = create_entities_at_location(3, SquadBattleTypes.SquadEntityInSquadLocation.Front)
	var context = {
		"entity": entity,
		"our_squad": {
			SquadBattleTypes.SquadEntityInSquadLocation.Front: allies,
			SquadBattleTypes.SquadEntityInSquadLocation.Middle: [entity]
		},
		"enemy_squad": {}
	}
	
	var consideration = SituationConsideration.new()
	consideration.comparison_type = SituationConsideration.ComparisonType.ALLIES_IN_LOCATION
	consideration.target_location = SquadBattleTypes.SquadEntityInSquadLocation.Front
	consideration.weight = 10.0
	
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 30.0, "Should count 3 allies * weight 10 = 30")
	end_test()

func test_situation_enemies_in_location() -> void:
	start_test("SituationConsideration: Count enemies at frontline")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Back
	})
	
	var enemies = create_entities_at_location(5, SquadBattleTypes.SquadEntityInSquadLocation.Front)
	var context = {
		"entity": entity,
		"our_squad": {
			SquadBattleTypes.SquadEntityInSquadLocation.Back: [entity]
		},
		"enemy_squad": {
			SquadBattleTypes.SquadEntityInSquadLocation.Front: enemies
		}
	}
	
	var consideration = SituationConsideration.new()
	consideration.comparison_type = SituationConsideration.ComparisonType.ENEMIES_IN_LOCATION
	consideration.target_location = SquadBattleTypes.SquadEntityInSquadLocation.Front
	consideration.weight = 5.0
	
	var situation = Situation.new(context)
	var score = consideration.score(entity, situation, context)
	
	assert_equal(score, 25.0, "Should count 5 enemies * weight 5 = 25")
	end_test()

# ============================================================================
# TEST SUITE 4: ActionConsideration Tests
# ============================================================================

func test_action_considerations() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 4: ActionConsideration")
	print("-".repeat(80) + "\n")
	
	test_action_no_conditions()
	test_action_with_met_conditions()
	test_action_with_unmet_conditions()
	test_action_with_multiple_conditions()

func test_action_no_conditions() -> void:
	start_test("ActionConsideration: No conditions (always valid)")
	
	var entity = create_test_entity({})
	var context = create_basic_context(entity)
	
	var action_csdr = ActionConsideration.new()
	action_csdr.target_action = SquadBattleTypes.SquadEntityAction.IDLE
	action_csdr.weight = 5.0
	# condition_considerations is already initialized as empty array
	
	var situation = Situation.new(context)
	var score = action_csdr.score(entity, situation, context)
	
	assert_equal(score, 5.0, "Should return weight when no conditions")
	end_test()

func test_action_with_met_conditions() -> void:
	start_test("ActionConsideration: All conditions met")
	
	var entity = create_test_entity({
		"hp": 20.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var context = create_basic_context(entity)
	
	# Condition: HP below 30%
	var hp_condition = EntityConsideration.new()
	hp_condition.property = SquadBattleTypes.EntityChangeable.HP
	hp_condition.detection = CsdrTypes.DETECTION.BELOW
	hp_condition.value = 0.3
	hp_condition.percentage = true
	hp_condition.weight = 1.0
	
	var action_csdr = ActionConsideration.new()
	action_csdr.target_action = SquadBattleTypes.SquadEntityAction.RETREAT
	action_csdr.weight = 50.0
	action_csdr.condition_considerations.append(hp_condition)
	
	var situation = Situation.new(context)
	var score = action_csdr.score(entity, situation, context)
	
	assert_equal(score, 50.0, "Should return weight when condition met")
	end_test()

func test_action_with_unmet_conditions() -> void:
	start_test("ActionConsideration: Condition not met")
	
	var entity = create_test_entity({
		"hp": 80.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var context = create_basic_context(entity)
	
	# Condition: HP below 30% (will fail)
	var hp_condition = EntityConsideration.new()
	hp_condition.property = SquadBattleTypes.EntityChangeable.HP
	hp_condition.detection = CsdrTypes.DETECTION.BELOW
	hp_condition.value = 0.3
	hp_condition.percentage = true
	hp_condition.weight = 1.0
	
	var action_csdr = ActionConsideration.new()
	action_csdr.target_action = SquadBattleTypes.SquadEntityAction.RETREAT
	action_csdr.weight = 50.0
	action_csdr.condition_considerations.append(hp_condition)
	
	var situation = Situation.new(context)
	var score = action_csdr.score(entity, situation, context)
	
	assert_equal(score, 0.0, "Should return 0 when condition not met")
	end_test()

func test_action_with_multiple_conditions() -> void:
	start_test("ActionConsideration: Multiple conditions (all must pass)")
	
	var entity = create_test_entity({
		"hp": 20.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var context = create_outnumbered_scenario(entity, 2, 6)
	
	# Condition 1: HP below 30%
	var hp_condition = EntityConsideration.new()
	hp_condition.property = SquadBattleTypes.EntityChangeable.HP
	hp_condition.detection = CsdrTypes.DETECTION.BELOW
	hp_condition.value = 0.3
	hp_condition.percentage = true
	hp_condition.weight = 1.0
	
	# Condition 2: Outnumbered
	var outnumber_condition = SituationConsideration.new()
	outnumber_condition.comparison_type = SituationConsideration.ComparisonType.OUTNUMBERED
	outnumber_condition.threshold = 2.0
	outnumber_condition.weight = 1.0
	
	var action_csdr = ActionConsideration.new()
	action_csdr.target_action = SquadBattleTypes.SquadEntityAction.RETREAT
	action_csdr.weight = 100.0
	action_csdr.condition_considerations.append(hp_condition)
	action_csdr.condition_considerations.append(outnumber_condition)
	
	var situation = Situation.new(context)
	var score = action_csdr.score(entity, situation, context)
	
	assert_equal(score, 100.0, "Should return weight when all conditions met")
	end_test()

# ============================================================================
# TEST SUITE 5: Logic Configuration Resources
# ============================================================================

func test_logic_configuration_resources() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 5: Logic Configuration Resources")
	print("-".repeat(80) + "\n")
	
	test_load_frontline_resource()
	test_load_retreat_resource()
	test_create_custom_configuration()

func test_load_frontline_resource() -> void:
	start_test("Load test-frontline.tres resource")
	
	var logic_conf = load("res://resources/combat/logic/logic/test-frontline.tres") as SimplifiedLogicConfig
	
	assert_not_null(logic_conf, "Resource should load successfully")
	assert_true(logic_conf.action_considerations.size() > 0, "Should have action considerations")
	end_test()

func test_load_retreat_resource() -> void:
	start_test("Load example_retreat_if_outnumbered.tres resource")
	
	var retreat_csdr = load("res://resources/combat/considerations/example_retreat_if_outnumbered.tres")
	
	assert_not_null(retreat_csdr, "Resource should load successfully")
	assert_true(retreat_csdr is SituationConsideration, "Should be SituationConsideration")
	end_test()

func test_create_custom_configuration() -> void:
	start_test("Create custom SimplifiedLogicConfig programmatically")
	
	var entity = create_test_entity({
		"hp": 20.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	# Build configuration
	var hp_condition = EntityConsideration.new()
	hp_condition.property = SquadBattleTypes.EntityChangeable.HP
	hp_condition.detection = CsdrTypes.DETECTION.BELOW
	hp_condition.value = 0.3
	hp_condition.percentage = true
	hp_condition.weight = 1.0
	
	var retreat_action = ActionConsideration.new()
	retreat_action.target_action = SquadBattleTypes.SquadEntityAction.RETREAT
	retreat_action.weight = 50.0
	retreat_action.condition_considerations.append(hp_condition)
	
	var idle_action = ActionConsideration.new()
	idle_action.target_action = SquadBattleTypes.SquadEntityAction.IDLE
	idle_action.weight = 1.0
	# idle has no conditions, leave empty
	
	var config = SimplifiedLogicConfig.new()
	config.action_considerations.append(retreat_action)
	config.action_considerations.append(idle_action)
	
	# Test with logic
	var context = create_basic_context(entity)
	var logic = SimplifiedSquadLogic.new(context, config)
	var chosen_action = logic.choose_action()
	
	assert_equal(chosen_action, SquadBattleTypes.SquadEntityAction.RETREAT, 
		"Should choose RETREAT when HP low")
	end_test()

# ============================================================================
# TEST SUITE 6: Complex Scenarios
# ============================================================================

func test_complex_scenarios() -> void:
	print("\n" + "-".repeat(80))
	print("TEST SUITE 6: Complex Scenarios")
	print("-".repeat(80) + "\n")
	
	test_scenario_low_hp_retreat()
	test_scenario_frontline_vs_backline()
	test_scenario_priority_resolution()

func test_scenario_low_hp_retreat() -> void:
	start_test("Scenario: Low HP entity should retreat")
	
	var entity = create_test_entity({
		"hp": 15.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	var config = create_retreat_on_low_hp_config()
	var context = create_basic_context(entity)
	var logic = SimplifiedSquadLogic.new(context, config)
	
	var action = logic.choose_action()
	
	assert_equal(action, SquadBattleTypes.SquadEntityAction.RETREAT, 
		"Entity with 15% HP should retreat")
	end_test()

func test_scenario_frontline_vs_backline() -> void:
	start_test("Scenario: Frontline entity attacks, backline moves forward")
	
	# Frontline entity
	var frontline_entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	# Backline entity
	var backline_entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Back
	})
	
	var config = create_position_based_config()
	
	# Test frontline
	var frontline_context = create_basic_context(frontline_entity)
	var frontline_logic = SimplifiedSquadLogic.new(frontline_context, config)
	var frontline_action = frontline_logic.choose_action()
	
	# Test backline
	var backline_context = create_basic_context(backline_entity)
	var backline_logic = SimplifiedSquadLogic.new(backline_context, config)
	var backline_action = backline_logic.choose_action()
	
	assert_equal(frontline_action, SquadBattleTypes.SquadEntityAction.ATTACK, 
		"Frontline entity should attack")
	assert_equal(backline_action, SquadBattleTypes.SquadEntityAction.FORWARD, 
		"Backline entity should move forward")
	end_test()

func test_scenario_priority_resolution() -> void:
	start_test("Scenario: Higher weight action wins")
	
	var entity = create_test_entity({
		"hp": 100.0,
		"max_hp": 100.0,
		"location": SquadBattleTypes.SquadEntityInSquadLocation.Front
	})
	
	# Create config with multiple valid actions
	var attack_action = ActionConsideration.new()
	attack_action.target_action = SquadBattleTypes.SquadEntityAction.ATTACK
	attack_action.weight = 10.0
	# no conditions
	
	var heal_action = ActionConsideration.new()
	heal_action.target_action = SquadBattleTypes.SquadEntityAction.HEAL
	heal_action.weight = 50.0
	# no conditions
	
	var config = SimplifiedLogicConfig.new()
	config.action_considerations.append(attack_action)
	config.action_considerations.append(heal_action)
	
	var context = create_basic_context(entity)
	var logic = SimplifiedSquadLogic.new(context, config)
	var action = logic.choose_action()
	
	assert_equal(action, SquadBattleTypes.SquadEntityAction.HEAL, 
		"Should choose HEAL with weight 50 over ATTACK with weight 10")
	end_test()

# ============================================================================
# Helper Functions
# ============================================================================

func create_test_entity(config: Dictionary) -> SquadEntity:
	# Create entity with proper stats initialization
	var stats = EntityBaseStats.new()
	stats.endurance = 10.0  # Will give HP = 10*5 + 5*2 = 60
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
	
	# Prepare entity config with proper parameter names
	var entity_config = {
		"player_id": 0,
		"name": "Test Entity",
		"team": "test",
		"stats": stats,
		"weapon": SquadWeapon.new(),
		"armour": SquadArmour.new(),
		"starting_location": config.get("location", SquadBattleTypes.SquadEntityInSquadLocation.Front)
	}
	
	# Note: max_hp is calculated from stats, so if we need specific max_hp:
	if config.has("max_hp"):
		# Adjust endurance to achieve desired max HP
		# HP = endurance * 5 + siz * 2
		# So: endurance = (desired_hp - siz * 2) / 5
		var desired_max = config["max_hp"]
		stats.endurance = (desired_max - stats.siz * 2) / 5.0
	
	var entity = SquadEntity.new(entity_config)
	
	# Override HP if specified (after initialise_changeables is called by constructor)
	if config.has("hp"):
		entity.changeable_stats[SquadBattleTypes.EntityChangeable.HP] = config["hp"]
	
	return entity

func create_basic_context(entity: SquadEntity) -> Dictionary:
	return {
		"entity": entity,
		"our_squad": {},
		"enemy_squad": {}
	}

func create_outnumbered_scenario(entity: SquadEntity, ally_count: int, enemy_count: int) -> Dictionary:
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

func create_retreat_on_low_hp_config() -> SimplifiedLogicConfig:
	var hp_condition = EntityConsideration.new()
	hp_condition.property = SquadBattleTypes.EntityChangeable.HP
	hp_condition.detection = CsdrTypes.DETECTION.BELOW
	hp_condition.value = 0.3
	hp_condition.percentage = true
	hp_condition.weight = 1.0
	
	var retreat_action = ActionConsideration.new()
	retreat_action.target_action = SquadBattleTypes.SquadEntityAction.RETREAT
	retreat_action.weight = 100.0
	retreat_action.condition_considerations.append(hp_condition)
	
	var idle_action = ActionConsideration.new()
	idle_action.target_action = SquadBattleTypes.SquadEntityAction.IDLE
	idle_action.weight = 1.0
	# no conditions
	
	var config = SimplifiedLogicConfig.new()
	config.action_considerations.append(retreat_action)
	config.action_considerations.append(idle_action)
	
	return config

func create_position_based_config() -> SimplifiedLogicConfig:
	# Attack if at frontline
	var at_frontline = ContextConsideration.new()
	at_frontline.query_type = ContextConsideration.ContextQuery.AT_SPECIFIC_LOCATION
	at_frontline.target_location = SquadBattleTypes.SquadEntityInSquadLocation.Front
	at_frontline.weight = 1.0
	
	var attack_action = ActionConsideration.new()
	attack_action.target_action = SquadBattleTypes.SquadEntityAction.ATTACK
	attack_action.weight = 10.0
	attack_action.condition_considerations.append(at_frontline)
	
	# Move forward if not at frontline
	var not_at_frontline = ContextConsideration.new()
	not_at_frontline.query_type = ContextConsideration.ContextQuery.AT_SPECIFIC_LOCATION
	not_at_frontline.target_location = SquadBattleTypes.SquadEntityInSquadLocation.Front
	not_at_frontline.weight = 1.0
	not_at_frontline.invert = true
	
	var forward_action = ActionConsideration.new()
	forward_action.target_action = SquadBattleTypes.SquadEntityAction.FORWARD
	forward_action.weight = 5.0
	forward_action.condition_considerations.append(not_at_frontline)
	
	var config = SimplifiedLogicConfig.new()
	config.action_considerations.append(attack_action)
	config.action_considerations.append(forward_action)
	
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
