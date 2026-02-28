extends Node
## Battle Royale Demo - Production Pipeline Test
##
## Exercises the same classes and execution order as StrategyPresenter,
## but headless. One squad acts as "player" (driven by SquadBrain
## instead of human input), the rest managed by AIFleetManager.
##
## Pipeline per turn (mirrors _execute_activity_obj):
##   1. Player brain decides activity (replaces button press)
##   2. exec_before/exec_activity/exec_after (ActivityRunner)
##   3. AI fleet returns decisions (AIFleetManager)
##   4. Contact tracking (ContactTracker.update_all_contacts)
##   5. Commit AI decisions (AIFleetManager)
##   6. Engagement detection & headless combat
##   7. Advance turn (StrategyEventBus.turn_advanced)

const SCENARIO_PATH := "res://resources/scenarios/combat-test/combat-test-scenario.tres"
const MAX_ROUNDS = 20

var scenario: GameScenario
var actor: ActivityRunner
var player_squad: SquadStrategicData
var player_brain: SquadBrain
var ai_fleet: AIFleetManager
var rng := RandomNumberGenerator.new()


func _ready():
	print("\n" + "=".repeat(80))
	print("AI BATTLE ROYALE — PRODUCTION PIPELINE TEST")
	print("=".repeat(80) + "\n")

	rng.randomize()
	_initialize()
	await _run_simulation()
	_print_final_results()

	await get_tree().create_timer(2.0).timeout
	get_tree().quit()

#region Initialization (mirrors StrategyPresenter.bind_view)

func _initialize():
	var loaded = ResourceLoader.load(SCENARIO_PATH)
	assert(
		loaded is GameScenario,
		"Failed to load GameScenario from %s" % SCENARIO_PATH,
	)
	scenario = loaded as GameScenario

	actor = ActivityRunner.new()
	add_child(actor)
	actor.setup(scenario)

	scenario.initialize()

	# Trigger lazy init — sets player_squad.current_location_id
	# (production code does this via _update_ui reading actor.current_location)
	var _loc = actor.current_location

	player_squad = actor.player_squad

	# Sync AEM's player_squad with runner's so _build_context() uses
	# the same instance (both lazy-create separate duplicates otherwise)
	actor.aem.player_squad = player_squad

	player_squad.engagement_stance = \
	StrategyTypes.EngagementStance.ALWAYS_ENGAGE

	var profile = AIProfileFactory.get_default_squad_profile()
	player_brain = SquadBrain.new(player_squad, profile)

	ai_fleet = AIFleetManager.new()
	add_child(ai_fleet)
	ai_fleet.setup(scenario)

	actor.exec_at(StrategyTypes.TriggerWhen.GAME_START)

	print(
		"[Demo] Player: %s at %s (%d warriors)" % [
			player_squad.squad_name,
			player_squad.current_location_id,
			player_squad.get_living_warriors().size(),
		],
	)
	print("[Demo] AI squads: %d" % ai_fleet.get_ai_squad_count())
	print("[Demo] Locations: %d" % scenario.world.locations.size())
	_print_all_squads()

#endregion

#region Turn Pipeline (mirrors _execute_activity_obj)

func _run_simulation():
	var round_num = 0
	while round_num < MAX_ROUNDS and _count_living_squads() > 1:
		round_num += 1
		print("\n" + "=".repeat(80))
		print(
			"ROUND %d — %d squads alive" % [
				round_num,
				_count_living_squads(),
			],
		)
		print("=".repeat(80))

		actor.exec_at(StrategyTypes.TriggerWhen.TURN_START)
		await _execute_one_turn()
		_print_all_squads()

		await get_tree().create_timer(0.3).timeout


func _execute_one_turn():
	var directive = FactionDirective.create_none()
	var decision = player_brain.decide(
		scenario.world,
		null,
		directive,
	)
	var activity_type: StrategyTypes.ActivityType = \
	decision["activity_type"]
	var context: Dictionary = decision["context"]

	var activity = actor.get_activity(activity_type)
	if not activity:
		activity = actor.get_activity(StrategyTypes.ActivityType.REST)
	assert(activity != null, "Must have a REST activity")

	if activity_type in [
		StrategyTypes.ActivityType.TRAVEL,
		StrategyTypes.ActivityType.FORCE_MARCH,
	]:
		var destination = context.get("travel_destination", "")
		if not destination.is_empty():
			activity = actor.create_travel_activity(destination)

	print(
		"[Demo] Player chose: %s" % \
		StrategyTypes.ActivityType.keys()[activity_type],
	)

	var player_loc_before = player_squad.current_location_id

	# Phase 1-3: before → activity → after
	# (mirrors _exec_play_animchanges_loop × 3)
	var before_results = actor.exec_before(activity)
	_resolve_combat_from_results(before_results)

	var activity_results = actor.exec_activity(activity)
	_resolve_combat_from_results(activity_results)

	var after_results = actor.exec_after(activity)
	_resolve_combat_from_results(after_results)

	# AI fleet decisions (mirrors presenter post-phase)
	var ai_results = ai_fleet.return_all_ai_turns()
	if ai_results["combats"].size() > 0:
		print(
			"[Demo] AI-vs-AI combats: %d" % \
			ai_results["combats"].size(),
		)
	if ai_results["movements"].size() > 0:
		print(
			"[Demo] AI movements: %d" % \
			ai_results["movements"].size(),
		)

	# Contacts & engagements (mirrors _update_contacts)
	_update_contacts(activity, player_loc_before)

	ai_fleet.commit_ai_decisions(ai_results)

	actor.advance_turn()
	scenario.world.turn_count += 1

	player_squad.consume_supplies_by_demand()

#endregion

#region Contact & Engagement Pipeline (mirrors _update_contacts)

func _update_contacts(
		activity: Activity,
		player_loc_before: String,
):
	var world = scenario.world
	var tracker = world.contact_tracker

	var activity_log: Dictionary = { }
	var edge_log: Dictionary = { }

	activity_log[player_squad.squad_id] = activity.activity_type

	var player_loc_after = player_squad.current_location_id
	if player_loc_before != player_loc_after:
		edge_log[player_squad.squad_id] = {
			"from": player_loc_before,
			"to": player_loc_after,
		}

	ai_fleet.fill_activity_log(activity_log, edge_log)

	var all_squads: Array = [player_squad]
	for sq in world.roaming_squads:
		all_squads.append(sq)

	tracker.update_all_contacts(
		world,
		all_squads,
		activity_log,
		edge_log,
		world.turn_count,
	)

	var location = world.get_location_by_id(
		player_squad.current_location_id,
	)
	if location:
		var clues = location.get_active_clues(world.turn_count)
		for clue in clues:
			for enemy in world.roaming_squads:
				if clue.left_by_squad_id == enemy.squad_id:
					tracker.apply_clue_bonus(
						clue,
						enemy,
						player_squad,
					)

	var engagements = tracker.check_engagements(
		world,
		all_squads,
	)
	for engagement in engagements:
		var atk_id = engagement["attacker_id"]
		var def_id = engagement["defender_id"]
		var involves_player = (
			atk_id == player_squad.squad_id
			or def_id == player_squad.squad_id
		)
		if involves_player:
			_handle_player_engagement(engagement)

#endregion

#region Combat Resolution (mirrors _handle_player_engagement)

func _handle_player_engagement(engagement: Dictionary):
	var eng_type: StrategyTypes.EngagementType = \
	engagement["type"]

	var enemy_id: String
	if engagement["attacker_id"] == player_squad.squad_id:
		enemy_id = engagement["defender_id"]
	else:
		enemy_id = engagement["attacker_id"]

	var enemy_squad = _find_enemy_squad(enemy_id)
	if not enemy_squad:
		return

	print(
		"\n[Demo] ENGAGEMENT: %s vs %s (%s)" % [
			player_squad.squad_name,
			enemy_squad.squad_name,
			StrategyTypes.EngagementType.keys()[eng_type],
		],
	)
	_resolve_headless_combat(
		player_squad,
		enemy_squad,
		eng_type,
	)


func _resolve_combat_from_results(
		results: Array[GenericResult],
) -> void:
	for result in results:
		if not (result is ActivityResult):
			continue
		if not result.requires_combat:
			continue
		var enemy_squad = _find_enemy_squad(
			result.combat_target_squad_id,
		)
		if enemy_squad:
			print(
				"[Demo] Activity combat vs %s" % \
				enemy_squad.squad_name,
			)
			_resolve_headless_combat(
				player_squad,
				enemy_squad,
				StrategyTypes.EngagementType.SET_PIECE,
			)


func _resolve_headless_combat(
		squad_a: SquadStrategicData,
		squad_b: SquadStrategicData,
		eng_type: StrategyTypes.EngagementType,
):
	var a_living = squad_a.get_living_warriors()
	var b_living = squad_b.get_living_warriors()
	if a_living.is_empty() or b_living.is_empty():
		return

	var a_str := a_living.size() * \
	(squad_a.get_morale() + 50.0) * rng.randf_range(0.7, 1.3)
	var b_str := b_living.size() * \
	(squad_b.get_morale() + 50.0) * rng.randf_range(0.7, 1.3)

	if eng_type == StrategyTypes.EngagementType.AMBUSH:
		a_str *= 1.3

	var winner: SquadStrategicData
	var loser: SquadStrategicData
	if a_str >= b_str:
		winner = squad_a
		loser = squad_b
	else:
		winner = squad_b
		loser = squad_a

	var loser_living = loser.get_living_warriors()
	var casualties = maxi(1, loser_living.size() / 2)
	for i in range(mini(casualties, loser_living.size())):
		loser_living[i].is_dead = true

	var winner_living = winner.get_living_warriors()
	if winner_living.size() > 1 and rng.randf() < 0.4:
		winner_living[0].is_injured = true

	winner.modify_morale(15)
	loser.modify_morale(-20)

	print(
		"[Demo] %s WINS (morale: %.0f), %s loses %d" % [
			winner.squad_name,
			winner.get_morale(),
			loser.squad_name,
			casualties,
		],
	)
	_cleanup_dead_squads()

#endregion

#region Helpers

func _find_enemy_squad(squad_id: String) -> SquadStrategicData:
	for squad in scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad
	return null


func _get_activity(
		activity_type: StrategyTypes.ActivityType,
) -> Activity:
	return actor.get_activity(activity_type)


func _count_living_squads() -> int:
	var count = 0
	if player_squad.get_living_warriors().size() > 0:
		count += 1
	count += ai_fleet.get_ai_squad_count()
	return count


func _cleanup_dead_squads():
	var to_remove: Array[String] = []
	for squad in scenario.world.roaming_squads:
		if squad.get_living_warriors().is_empty():
			to_remove.append(squad.squad_id)
	for squad_id in to_remove:
		scenario.world.remove_roaming_squad(squad_id)
		scenario.world.contact_tracker.clear_contacts_for(
			squad_id,
		)
		if ai_fleet.squad_brains.has(squad_id):
			ai_fleet.squad_brains.erase(squad_id)
			ai_fleet.squad_executors.erase(squad_id)
		print("[Demo] Eliminated: %s" % squad_id)


func _print_all_squads():
	print(
		"\n  %-20s %-15s %-8s %-12s %-6s" % [
			"SQUAD",
			"LOCATION",
			"MORALE",
			"WARRIORS",
			"FOOD",
		],
	)
	print("  " + "-".repeat(65))

	var p_living = player_squad.get_living_warriors().size()
	print(
		"  %-20s %-15s %-8.0f %d/%-9d %-6d [PLAYER]" % [
			player_squad.squad_name,
			player_squad.current_location_id,
			player_squad.get_morale(),
			p_living,
			player_squad.warriors.size(),
			player_squad.food,
		],
	)

	for squad in scenario.world.roaming_squads:
		var living = squad.get_living_warriors().size()
		print(
			"  %-20s %-15s %-8.0f %d/%-9d %-6d" % [
				squad.squad_name,
				squad.current_location_id,
				squad.get_morale(),
				living,
				squad.warriors.size(),
				squad.food,
			],
		)


func _print_final_results():
	print("\n" + "=".repeat(80))
	print(
		"BATTLE ROYALE COMPLETE — Turn %d" % \
		scenario.world.turn_count,
	)
	print("=".repeat(80))

	var survivors: Array[SquadStrategicData] = []
	if player_squad.get_living_warriors().size() > 0:
		survivors.append(player_squad)
	for squad in scenario.world.roaming_squads:
		if squad.get_living_warriors().size() > 0:
			survivors.append(squad)

	if survivors.size() == 1:
		var winner = survivors[0]
		var tag = " [PLAYER]" if winner == player_squad \
		else ""
		print("\nWINNER: %s%s" % [winner.squad_name, tag])
		print("  Location: %s" % winner.current_location_id)
		print("  Morale: %.0f" % winner.get_morale())
		print(
			"  Warriors: %d/%d" % [
				winner.get_living_warriors().size(),
				winner.warriors.size(),
			],
		)
		for w in winner.get_living_warriors():
			print(
				"    - %s (Injured: %s)" % [
					w.name,
					"Yes" if w.is_injured else "No",
				],
			)
	elif survivors.size() > 1:
		print(
			"\nTIME LIMIT — %d survivors:" % \
			survivors.size(),
		)
		for squad in survivors:
			var tag = " [PLAYER]" \
			if squad == player_squad else ""
			print(
				"  - %s (Morale: %.0f, Warriors: %d)%s" % [
					squad.squad_name,
					squad.get_morale(),
					squad.get_living_warriors().size(),
					tag,
				],
			)
	else:
		print("\nALL SQUADS ELIMINATED")

#endregion
