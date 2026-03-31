extends Node

## Contact system unit tests — spotting, proximity, state transitions, decay, ScoutingFocus

const SCENARIO_PATH := "res://resources/scenarios/goetz-official/scenario.tres"

var test_count := 0
var passed_count := 0
var failed_count := 0

var world: World
var squad_a: SquadData
var squad_b: SquadData

func _ready() -> void:
	Log.set_level(Log.Level.WARN)

	var scenario: GameScenario = load(SCENARIO_PATH).duplicate(true) as GameScenario
	world = scenario.world
	assert(world != null, "World must exist in scenario")
	assert(world.locations.size() >= 2, "Need at least 2 locations")

	squad_a = _make_squad("test_alpha", StrategyTypes.SquadRole.COMBAT, EntityClasses.Types.Landsknecht)
	squad_b = _make_squad("test_bravo", StrategyTypes.SquadRole.MERCHANT, EntityClasses.Types.Crossbowman)

	print("\n" + "=".repeat(70))
	print("CONTACT SYSTEM — UNIT TEST SUITE")
	print("=".repeat(70) + "\n")

	test_contact_state_transitions()
	test_contact_decay()
	test_contact_progress_clamping()
	test_proximity_tiers()
	test_focus_multiplier()
	test_engagement_classification()

	print("\n" + "=".repeat(70))
	print("TEST RESULTS: %d passed, %d failed, %d total" % [passed_count, failed_count, test_count])
	if failed_count == 0:
		print("✓ ALL TESTS PASSED!")
	else:
		print("✗ SOME TESTS FAILED!")
	print("=".repeat(70) + "\n")

	get_tree().quit(0 if failed_count == 0 else 1)


#region Helpers

func check(condition: bool, test_name: String, detail: String = "") -> void:
	test_count += 1
	if condition:
		passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_count += 1
		var msg := "  [FAIL] %s" % test_name
		if detail != "":
			msg += ": %s" % detail
		print(msg)

func _make_warrior(warrior_class: EntityClasses.Types) -> Warrior:
	var w := Warrior.new()
	w.id = "w_%s_%d" % [EntityClasses.Types.keys()[warrior_class], randi()]
	w.name = w.id
	w.class_id = warrior_class
	w.attributes = {"diplomacy": 30, "survival": 30, "perception": 40, "leadership": 50, "stealth": 35}
	return w

func _make_squad(id: String, role: StrategyTypes.SquadRole, warrior_class: EntityClasses.Types) -> SquadData:
	var sd := SquadData.new()
	sd.squad_id = id
	sd.squad_name = id
	sd.squad_role = role
	for i in range(3):
		sd.warriors.append(_make_warrior(warrior_class))
	return sd

func _find_connected_pair() -> Array:
	for loc_a in world.locations:
		for loc_b in world.locations:
			if loc_a != loc_b and loc_a.is_connected_to(loc_b.location_id):
				return [loc_a, loc_b]
	return []

func _find_non_adjacent_pair() -> Array:
	for loc_a in world.locations:
		for loc_b in world.locations:
			if loc_a != loc_b and not loc_a.is_connected_to(loc_b.location_id):
				return [loc_a, loc_b]
	return []

#endregion


#region Test 1: Contact State Transitions

func test_contact_state_transitions() -> void:
	print("\n--- Test 1: Contact State Transitions ---")

	var tracker := ContactTracker.new()
	var contact = tracker.get_or_create_contact("squad_a", "squad_b")

	check(contact != null, "get_or_create_contact returns non-null")
	check(contact.progress == 0.0, "Initial progress is 0.0", "got %.1f" % contact.progress)
	check(contact.get_state() == StrategyTypes.ContactState.NONE, "Initial state is NONE")

	contact.apply_delta(1.0, 1)
	check(contact.get_state() == StrategyTypes.ContactState.SUSPECTED, "Progress 1.0 → SUSPECTED")

	contact.apply_delta(29.0, 2)
	check(contact.get_state() == StrategyTypes.ContactState.TRACKED, "Progress 30.0 → TRACKED", "got %.1f" % contact.progress)

	contact.apply_delta(70.0, 3)
	check(contact.get_state() == StrategyTypes.ContactState.LOCKED, "Progress 100.0 → LOCKED", "got %.1f" % contact.progress)

	var same_contact = tracker.get_or_create_contact("squad_a", "squad_b")
	check(same_contact == contact, "get_or_create_contact returns same instance")

	var reverse = tracker.get_or_create_contact("squad_b", "squad_a")
	check(reverse != contact, "Reverse direction creates separate contact")

#endregion


#region Test 2: Contact Decay

func test_contact_decay() -> void:
	print("\n--- Test 2: Contact Decay ---")

	var tracker := ContactTracker.new()
	var contact = tracker.get_or_create_contact("observer", "target")

	contact.apply_delta(50.0, 1)
	check(contact.progress == 50.0, "Set initial progress to 50.0")
	check(contact.get_state() == StrategyTypes.ContactState.TRACKED, "State is TRACKED at 50.0")

	contact.apply_delta(-10.0, 2)
	check(contact.progress == 40.0, "After -10 delta, progress is 40.0", "got %.1f" % contact.progress)
	check(contact.get_state() == StrategyTypes.ContactState.TRACKED, "Still TRACKED at 40.0")

	contact.apply_delta(-15.0, 3)
	check(contact.progress == 25.0, "After another -15 delta, progress is 25.0", "got %.1f" % contact.progress)
	check(contact.get_state() == StrategyTypes.ContactState.SUSPECTED, "Decayed to SUSPECTED at 25.0")

	contact.apply_delta(-25.0, 4)
	check(contact.progress == 0.0, "Fully decayed to 0.0", "got %.1f" % contact.progress)
	check(contact.get_state() == StrategyTypes.ContactState.NONE, "Decayed to NONE")

#endregion


#region Test 3: Contact Progress Clamping

func test_contact_progress_clamping() -> void:
	print("\n--- Test 3: Contact Progress Clamping ---")

	var tracker := ContactTracker.new()
	var contact = tracker.get_or_create_contact("obs", "tgt")

	contact.apply_delta(200.0, 1)
	check(contact.progress == 100.0, "Delta +200 clamps to 100.0", "got %.1f" % contact.progress)
	check(contact.get_state() == StrategyTypes.ContactState.LOCKED, "Clamped at LOCKED")

	contact.apply_delta(-500.0, 2)
	check(contact.progress == 0.0, "Delta -500 clamps to 0.0", "got %.1f" % contact.progress)
	check(contact.get_state() == StrategyTypes.ContactState.NONE, "Clamped at NONE")

#endregion


#region Test 4: Proximity Tiers

func test_proximity_tiers() -> void:
	print("\n--- Test 4: Proximity Tiers ---")

	var tracker := ContactTracker.new()
	var edge_log: Dictionary = {}

	var connected = _find_connected_pair()
	assert(connected.size() == 2, "Need a connected location pair")
	var loc_a: Location = connected[0]
	var loc_b: Location = connected[1]

	var non_adj = _find_non_adjacent_pair()
	assert(non_adj.size() == 2, "Need a non-adjacent location pair")
	var loc_far_a: Location = non_adj[0]
	var loc_far_b: Location = non_adj[1]

	squad_a.current_location_id = loc_a.location_id
	squad_b.current_location_id = loc_a.location_id
	var prox_same = tracker._determine_proximity(squad_a, squad_b, world, edge_log)
	check(prox_same == ContactTracker.SAME_LOCATION_PROXIMITY, "Same location → 1.0", "got %.1f" % prox_same)

	squad_a.current_location_id = loc_a.location_id
	squad_b.current_location_id = loc_b.location_id
	var prox_adj = tracker._determine_proximity(squad_a, squad_b, world, edge_log)
	check(prox_adj == ContactTracker.ADJACENT_PROXIMITY, "Adjacent location → 0.3", "got %.1f" % prox_adj)

	squad_a.current_location_id = loc_far_a.location_id
	squad_b.current_location_id = loc_far_b.location_id
	var prox_far = tracker._determine_proximity(squad_a, squad_b, world, edge_log)
	check(prox_far == 0.0, "Non-adjacent → 0.0", "got %.1f" % prox_far)

	var edge_a := {"from": loc_a.location_id, "to": loc_b.location_id}
	var edge_b := {"from": loc_b.location_id, "to": loc_a.location_id}
	var edge_log_same: Dictionary = {squad_a.squad_id: edge_a, squad_b.squad_id: edge_b}
	squad_a.current_location_id = loc_a.location_id
	squad_b.current_location_id = loc_b.location_id
	var prox_edge = tracker._determine_proximity(squad_a, squad_b, world, edge_log_same)
	check(prox_edge == ContactTracker.SAME_EDGE_PROXIMITY, "Same edge → 0.7", "got %.1f" % prox_edge)

#endregion


#region Test 5: Focus Multiplier

func test_focus_multiplier() -> void:
	print("\n--- Test 5: Focus Multiplier ---")

	var tracker := ContactTracker.new()

	var no_focus_mult := tracker.calculate_focus_multiplier(squad_a, squad_b, null)
	check(no_focus_mult == 1.0, "Null focus → multiplier 1.0", "got %.2f" % no_focus_mult)

	var empty_focus := ScoutingFocus.new()
	var empty_mult := tracker.calculate_focus_multiplier(squad_a, squad_b, empty_focus)
	check(empty_mult == 1.0, "Empty focus → multiplier 1.0", "got %.2f" % empty_mult)

	var role_focus := ScoutingFocus.new()
	role_focus.toggle_role(squad_b.squad_role)
	check(role_focus.matches(squad_b), "Focus matches target by role")

	var boost_mult := tracker.calculate_focus_multiplier(squad_a, squad_b, role_focus)
	check(boost_mult > 1.0, "Matching focus → boost > 1.0", "got %.2f" % boost_mult)

	var other_role: StrategyTypes.SquadRole
	if squad_b.squad_role == StrategyTypes.SquadRole.COMBAT:
		other_role = StrategyTypes.SquadRole.MERCHANT
	else:
		other_role = StrategyTypes.SquadRole.COMBAT
	var mismatch_focus := ScoutingFocus.new()
	mismatch_focus.toggle_role(other_role)
	check(not mismatch_focus.matches(squad_b), "Mismatched focus does not match target")

	var penalty_mult := tracker.calculate_focus_multiplier(squad_a, squad_b, mismatch_focus)
	check(penalty_mult < 1.0, "Non-matching focus → penalty < 1.0", "got %.2f" % penalty_mult)

#endregion


#region Test 6: Engagement Classification

func test_engagement_classification() -> void:
	print("\n--- Test 6: Engagement Classification ---")

	var tracker := ContactTracker.new()

	var connected = _find_connected_pair()
	var shared_loc: Location = connected[0]
	squad_a.current_location_id = shared_loc.location_id
	squad_b.current_location_id = shared_loc.location_id

	var contact_ab = tracker.get_or_create_contact(squad_a.squad_id, squad_b.squad_id)
	var contact_ba = tracker.get_or_create_contact(squad_b.squad_id, squad_a.squad_id)

	contact_ab.apply_delta(100.0, 1)
	contact_ba.apply_delta(0.0, 1)
	check(contact_ab.get_state() == StrategyTypes.ContactState.LOCKED, "A→B is LOCKED")
	check(contact_ba.get_state() == StrategyTypes.ContactState.NONE, "B→A is NONE")

	var all_squads: Array = [squad_a, squad_b]
	var engagements := tracker.check_engagements(world, all_squads)
	check(engagements.size() == 1, "One engagement found", "got %d" % engagements.size())
	if engagements.size() > 0:
		check(engagements[0]["type"] == StrategyTypes.EngagementType.AMBUSH, "LOCKED vs NONE → AMBUSH")
		check(engagements[0]["attacker_id"] == squad_a.squad_id, "Attacker is the LOCKED side")

	var eng_type := tracker.classify_engagement(squad_a.squad_id, squad_b.squad_id)
	check(eng_type == StrategyTypes.EngagementType.AMBUSH, "classify_engagement → AMBUSH")

	contact_ba.apply_delta(100.0, 2)
	check(contact_ba.get_state() == StrategyTypes.ContactState.LOCKED, "B→A now LOCKED")

	var tracker2 := ContactTracker.new()
	var c_ab = tracker2.get_or_create_contact(squad_a.squad_id, squad_b.squad_id)
	var c_ba = tracker2.get_or_create_contact(squad_b.squad_id, squad_a.squad_id)
	c_ab.apply_delta(100.0, 1)
	c_ba.apply_delta(100.0, 1)
	squad_a.current_location_id = shared_loc.location_id
	squad_b.current_location_id = shared_loc.location_id

	var eng2 := tracker2.check_engagements(world, all_squads)
	check(eng2.size() == 1, "One SET_PIECE engagement found", "got %d" % eng2.size())
	if eng2.size() > 0:
		check(eng2[0]["type"] == StrategyTypes.EngagementType.SET_PIECE, "Both LOCKED → SET_PIECE")

	var eng_type2 := tracker2.classify_engagement(squad_a.squad_id, squad_b.squad_id)
	check(eng_type2 == StrategyTypes.EngagementType.SET_PIECE, "classify_engagement → SET_PIECE")

#endregion
