extends Node

var fleet_manager: AIFleetManager
var scenario: GameScenario

var starting_locations := {
	"bandit_squad_1": "forest",
	"mercenary_squad_1": "smolensk",
	"rebel_squad_1": "minsk",
	"raider_squad_1": "road2",
	"cultist_squad_1": "hamlet",
	"outlaw_squad_1": "road1",
	"scout_squad_1": "border_post",
	"militia_squad_1": "market_town",
}

var profile_assignments := {
	"bandit_squad_1": "aggressive-hunter",
	"mercenary_squad_1": "balanced-roamer",
	"rebel_squad_1": "balanced-roamer",
	"raider_squad_1": "aggressive-hunter",
	"cultist_squad_1": "cautious-survivor",
	"outlaw_squad_1": "balanced-roamer",
	"scout_squad_1": "cautious-survivor",
	"militia_squad_1": "balanced-roamer",
}

func _ready():
	Log.info("StressTest", "=== AI STRESS TEST — LARGE WORLD BATTLE ROYALE ===")

	var scenario_path := "res://resources/scenarios/ai-stress-test/ai-stress-test-scenario.tres"
	scenario = load(scenario_path) as GameScenario

	if scenario == null:
		Log.error("StressTest", "Failed to load scenario")
		get_tree().quit(1)
		return

	scenario.triggerable_manager = TriggerableManager.new()
	var activities = scenario._load_generic_activities()
	for activity in activities:
		scenario.triggerable_manager.register(activity)
	Log.debug("StressTest", "Registered %d activities" % activities.size())

	for squad in scenario.world.roaming_squads:
		if starting_locations.has(squad.squad_id):
			squad.starting_location_id = starting_locations[squad.squad_id]
			squad.set_location(starting_locations[squad.squad_id])
		else:
			Log.warn("StressTest", "No starting location for squad: %s" % squad.squad_id)

	Log.info("StressTest", "World: %d locations, %d squads" % [
		scenario.world.locations.size(),
		scenario.world.roaming_squads.size()
	])
	_print_world_map()

	fleet_manager = AIFleetManager.new()
	add_child(fleet_manager)

	fleet_manager.setup(scenario)
	_assign_profiles()

	Log.info("StressTest", "Battle Royale: %d squads across %d locations" % [
		fleet_manager.get_ai_squad_count(),
		scenario.world.locations.size()
	])
	_print_squad_status()

	var max_rounds := 50
	var round := 0

	while fleet_manager.get_ai_squad_count() > 1 and round < max_rounds:
		round += 1
		Log.info("StressTest", "=== ROUND %d — %d squads alive ===" % [round, fleet_manager.get_ai_squad_count()])

		var ai_results = fleet_manager.prepare_ai_turns()
		var entries = _build_karma_sorted_entries(ai_results)

		for entry in entries:
			(entry["executor"] as ActivityExecuteManager).execute_triggerables_at(
				StrategyTypes.TriggerWhen.HOUR_START,
			)

		for phase in ['before', 'activity', 'after']:
			for entry in entries:
				var executor: ActivityExecuteManager = entry["executor"]
				var results: Array[GenericResult] = executor["exec_%s" % phase].call(entry["activity"])
				_resolve_ai_combat_from_results(results, entry["squad_id"])

		fleet_manager.cleanup_defeated_squads()

		var activity_log: Dictionary = {}
		var edge_log: Dictionary = {}
		fleet_manager.fill_activity_log(activity_log, edge_log)
		scenario.world.contact_tracker.update_all_contacts(
			scenario.world,
			scenario.world.roaming_squads,
			activity_log,
			edge_log,
			round
		)

		scenario.world.current_hour = round

		Log.debug("StressTest", "--- End of Round %d ---" % round)
		_print_squad_status()

		await get_tree().create_timer(0.3).timeout

	_print_final_results(round, max_rounds)
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()

func _build_karma_sorted_entries(ai_results: Dictionary) -> Array:
	var entries: Array = []
	var decisions = ai_results["decisions_this_turn"]
	for squad_id in decisions:
		var dec = decisions[squad_id]
		entries.append({
			"squad_id": squad_id,
			"activity": dec["activity"],
			"executor": fleet_manager.squad_executors[squad_id],
			"karma": dec["squad"].karma,
		})
	entries.sort_custom(func(a, b): return a["karma"] > b["karma"])
	return entries


func _resolve_ai_combat_from_results(
		results: Array[GenericResult],
		squad_id: String,
) -> void:
	for result in results:
		if not (result is ActivityResult):
			continue
		if not result.requires_combat:
			continue
		var target_id = result.combat_target_squad_id
		if target_id.is_empty():
			continue
		var attacker = fleet_manager._find_squad_by_id(squad_id)
		var defender = fleet_manager._find_squad_by_id(target_id)
		if attacker and defender:
			Log.info("StressTest", "AI combat: %s vs %s" % [
				attacker.squad_name,
				defender.squad_name,
			])
			fleet_manager._execute_headless_combat({
				"attacker_id": squad_id,
				"defender_id": target_id,
			})


func _assign_profiles() -> void:
	var profile_base := "res://resources/ai/strategic/profiles/"
	for squad in scenario.world.roaming_squads:
		var profile_name = profile_assignments.get(squad.squad_id, "balanced-roamer")
		var profile_path = profile_base + profile_name + ".tres"
		var profile = AIProfileFactory.get_squad_profile(profile_path)
		if profile and fleet_manager.squad_brains.has(squad.squad_id):
			fleet_manager.squad_brains[squad.squad_id] = SquadBrain.new(squad, profile)
			Log.debug("StressTest", "Assigned %s profile to %s" % [profile_name, squad.squad_name])

func _print_world_map() -> void:
	Log.debug("StressTest", "[WORLD MAP]")
	for location in scenario.world.locations:
		var conn_names: Array[String] = []
		for conn in location.connections.tt:
			var target = scenario.world.get_location_by_id(conn.to_location_id)
			if target:
				conn_names.append(target.location_name)
		var shop_str = " [SHOP]" if location.has_shop() else ""
		Log.debug("StressTest", "  %s (%s)%s → %s" % [
			location.location_name,
			StrategyTypes.LocationType.keys()[location.type],
			shop_str,
			", ".join(conn_names)
		])

func _print_squad_status() -> void:
	for squad in scenario.world.roaming_squads:
		var living := 0
		var injured := 0
		for warrior in squad.warriors:
			if not warrior.is_dead:
				living += 1
				if warrior.is_injured:
					injured += 1

		var location = scenario.world.get_location_by_id(squad.current_location_id)
		var loc_name = location.location_name if location else squad.current_location_id
		var profile_name = profile_assignments.get(squad.squad_id, "?")

		Log.debug("StressTest", "[%s] %s (%s) @ %s — W:%d/%d Inj:%d Mor:%d Food:%d Gold:%.0f" % [
			squad.squad_id.left(8),
			squad.squad_name,
			profile_name.left(3).to_upper(),
			loc_name,
			living,
			squad.warriors.size(),
			injured,
			squad.get_morale(),
			squad.food,
			squad.money
		])

func _print_final_results(rounds_played: int, max_rounds: int) -> void:
	Log.info("StressTest", "=== BATTLE ROYALE COMPLETE — %d rounds played ===" % rounds_played)

	var survivors := 0
	for squad in scenario.world.roaming_squads:
		var living := 0
		for warrior in squad.warriors:
			if not warrior.is_dead:
				living += 1
		if living > 0:
			survivors += 1

	if survivors == 1:
		for squad in scenario.world.roaming_squads:
			var living := 0
			for warrior in squad.warriors:
				if not warrior.is_dead:
					living += 1
			if living > 0:
				Log.info("StressTest", "WINNER: %s" % squad.squad_name)
				Log.info("StressTest", "  Location: %s | Warriors: %d alive | Morale: %d | Food: %d | Gold: %.0f" % [
					squad.current_location_id, living, squad.get_morale(), squad.food, squad.money
				])
				break
	elif survivors > 1:
		Log.info("StressTest", "TIME LIMIT — %d survivors:" % survivors)
		for squad in scenario.world.roaming_squads:
			var living := 0
			for warrior in squad.warriors:
				if not warrior.is_dead:
					living += 1
			if living > 0:
				Log.info("StressTest", "  %s — W:%d Mor:%d Food:%d Gold:%.0f @ %s" % [
					squad.squad_name, living, squad.get_morale(),
					squad.food, squad.money, squad.current_location_id
				])
	else:
		Log.info("StressTest", "ALL SQUADS ELIMINATED")
