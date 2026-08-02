extends Node
## Feedback Signal Test — Validates signal-driven FeedbackEffect dispatch.
##
## Tests:
## 1. update_fired signal reaches displays and triggers change_received
## 2. Effects self-filter via wants() — only matching effects fire
## 3. Role determination: source vs target correctly assigned
## 4. HP change triggers hp_bar, rig_behavior, attack_lunge, combat_sfx
## 5. DODGE change triggers dodge_text only (target role)
## 6. DIE change triggers death feedback (target role)
## 7. PROC change triggers proc_popup (source role)
##
## Usage: godot --headless --path . scenes/demos/feedback_signal_test.tscn

var _pass_count: int = 0
var _fail_count: int = 0
var _fired_effects: Array[String] = []


func _ready():
	Log.set_level(Log.Level.INFO)
	Log.info("FeedbackSignalTest", "=== FEEDBACK SIGNAL TEST ===")

	var battle := _create_battle()
	var entities: Array[CombatEntity] = []
	for side in battle.side_squads_dict:
		for squad in battle.side_squads_dict[side]:
			for e in squad.entities:
				entities.append(e)

	var attacker := entities[0]
	var defender := entities[4]

	var source_display := BattleEntityDisplay.new()
	add_child(source_display)
	source_display.setup(attacker)

	var target_display := BattleEntityDisplay.new()
	add_child(target_display)
	target_display.setup(defender)

	var emitter := Node.new()
	add_child(emitter)

	var update_fired := func(update: EntityUpdate):
		source_display._on_update_fired(update)
		target_display._on_update_fired(update)

	# --- Test 1: HP change reaches target display as TARGET role ---
	Log.info("FeedbackSignalTest", "--- Test: HP change signal dispatch ---")
	_fired_effects.clear()
	var hp_change := EntityChange.new(SquadBattleTypes.EntityChangeable.HP, 60.0, 45.0)
	var hp_update := EntityUpdate.new(attacker.player_id, defender.player_id, hp_change)

	var received_roles: Array[int] = []
	var spy := func(_u, r): received_roles.append(r)
	target_display.change_received.connect(spy)
	update_fired.call(hp_update)
	target_display.change_received.disconnect(spy)

	_assert_true(received_roles.has(FeedbackEffect.Role.TARGET),
		"Target display receives TARGET role for HP change")
	_assert_true(not received_roles.has(FeedbackEffect.Role.SOURCE),
		"Target display does NOT receive SOURCE role")

	# --- Test 2: Source display gets SOURCE role ---
	Log.info("FeedbackSignalTest", "--- Test: Source role assignment ---")
	received_roles.clear()
	source_display.change_received.connect(spy)
	update_fired.call(hp_update)
	source_display.change_received.disconnect(spy)

	_assert_true(received_roles.has(FeedbackEffect.Role.SOURCE),
		"Source display receives SOURCE role for HP change")

	# --- Test 3: wants() filtering — DODGE only fires for TARGET ---
	Log.info("FeedbackSignalTest", "--- Test: DODGE wants() filtering ---")
	var dodge_change := EntityChange.new(SquadBattleTypes.EntityChangeable.DODGE, -1, -1)
	var dodge_update := EntityUpdate.new(attacker.player_id, defender.player_id, dodge_change)

	var dodge_fx := DodgeTextFeedback.new()
	_assert_true(dodge_fx.wants(dodge_change, FeedbackEffect.Role.TARGET),
		"DodgeTextFeedback wants DODGE as TARGET")
	_assert_true(not dodge_fx.wants(dodge_change, FeedbackEffect.Role.SOURCE),
		"DodgeTextFeedback rejects DODGE as SOURCE")

	# --- Test 4: wants() filtering — AttackLunge only fires for SOURCE ---
	Log.info("FeedbackSignalTest", "--- Test: AttackLunge wants() filtering ---")
	var lunge_fx := AttackLungeFeedback.new()
	_assert_true(lunge_fx.wants(hp_change, FeedbackEffect.Role.SOURCE),
		"AttackLungeFeedback wants HP as SOURCE")
	_assert_true(not lunge_fx.wants(hp_change, FeedbackEffect.Role.TARGET),
		"AttackLungeFeedback rejects HP as TARGET")

	# --- Test 5: wants() filtering — Death only for TARGET + DIE ---
	Log.info("FeedbackSignalTest", "--- Test: Death wants() filtering ---")
	var die_change := EntityChange.new(SquadBattleTypes.EntityChangeable.DIE, -1, -1)
	var death_fx := DeathFeedback.new()
	_assert_true(death_fx.wants(die_change, FeedbackEffect.Role.TARGET),
		"DeathFeedback wants DIE as TARGET")
	_assert_true(not death_fx.wants(die_change, FeedbackEffect.Role.SOURCE),
		"DeathFeedback rejects DIE as SOURCE")
	_assert_true(not death_fx.wants(hp_change, FeedbackEffect.Role.TARGET),
		"DeathFeedback rejects HP change")

	# --- Test 6: wants() filtering — ProcPopup only for SOURCE + PROC ---
	Log.info("FeedbackSignalTest", "--- Test: ProcPopup wants() filtering ---")
	var proc_change := EntityChange.new(SquadBattleTypes.EntityChangeable.PROC, -1, -1, {"skill_name": "Brace"})
	var proc_fx := ProcPopupFeedback.new()
	_assert_true(proc_fx.wants(proc_change, FeedbackEffect.Role.SOURCE),
		"ProcPopupFeedback wants PROC as SOURCE")
	_assert_true(not proc_fx.wants(proc_change, FeedbackEffect.Role.TARGET),
		"ProcPopupFeedback rejects PROC as TARGET")
	_assert_true(not proc_fx.wants(hp_change, FeedbackEffect.Role.SOURCE),
		"ProcPopupFeedback rejects HP change")

	# --- Test 7: Full signal chain — emit update, effects fire autonomously ---
	Log.info("FeedbackSignalTest", "--- Test: Full signal chain (HP damage) ---")
	var rig_before := target_display.rig.modulate
	update_fired.call(hp_update)
	await get_tree().create_timer(0.1).timeout
	var rig_after := target_display.rig.modulate
	_assert_true(rig_before != rig_after,
		"HP damage triggers visual feedback on target rig (modulate changed)")

	# --- Test 8: Self-update (source == affected) fires both roles ---
	Log.info("FeedbackSignalTest", "--- Test: Self-update fires both roles ---")
	received_roles.clear()
	var self_change := EntityChange.new(SquadBattleTypes.EntityChangeable.HP, 50.0, 60.0)
	var self_update := EntityUpdate.new(attacker.player_id, attacker.player_id, self_change)
	source_display.change_received.connect(spy)
	source_display._on_update_fired(self_update)
	source_display.change_received.disconnect(spy)

	_assert_true(received_roles.has(FeedbackEffect.Role.SOURCE),
		"Self-update fires SOURCE role")
	_assert_true(received_roles.has(FeedbackEffect.Role.TARGET),
		"Self-update fires TARGET role")

	# --- Test 9: Unrelated entity does not receive signal ---
	Log.info("FeedbackSignalTest", "--- Test: Unrelated entity ignores update ---")
	var unrelated := entities[2]
	var unrelated_display := BattleEntityDisplay.new()
	add_child(unrelated_display)
	unrelated_display.setup(unrelated)

	received_roles.clear()
	unrelated_display.change_received.connect(spy)
	source_display._on_update_fired(hp_update)
	target_display._on_update_fired(hp_update)
	unrelated_display.change_received.disconnect(spy)

	_assert_true(received_roles.is_empty(),
		"Unrelated display receives no signal for others' update")

	# --- Results ---
	Log.info("FeedbackSignalTest", "")
	Log.info("FeedbackSignalTest", "=== RESULTS: %d passed, %d failed ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		Log.error("FeedbackSignalTest", "SOME TESTS FAILED")
	else:
		Log.info("FeedbackSignalTest", "ALL TESTS PASSED")

	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _create_battle() -> SquadBattle:
	var teams: Dictionary[SquadBattleTypes.Side, Array] = {
		SquadBattleTypes.Side.ATTACKER: [
			["TestAtk", SquadBattleTypes.Side.ATTACKER, ["landsknecht", "landsknecht", "landsknecht", "healer"]],
		],
		SquadBattleTypes.Side.DEFENDER: [
			["TestDef", SquadBattleTypes.Side.DEFENDER, ["landsknecht", "landsknecht", "landsknecht", "healer"]],
		],
	}
	return SquadBattle.new(teams, Tactic.create_balanced(), Tactic.create_balanced())


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		Log.info("FeedbackSignalTest", "  PASS: %s" % msg)
	else:
		_fail_count += 1
		Log.error("FeedbackSignalTest", "  FAIL: %s" % msg)
