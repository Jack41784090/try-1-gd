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
	print("\n" + "=".repeat(80))
	print("AI STRESS TEST — LARGE WORLD BATTLE ROYALE")
	print("=".repeat(80) + "\n")

	var scenario_path := "res://resources/scenarios/ai-stress-test/ai-stress-test-scenario.tres"
	scenario = load(scenario_path) as GameScenario

	if scenario == null:
		push_error("[DEMO] Failed to load scenario")
		get_tree().quit(1)
		return

	scenario.triggerable_manager = TriggerableManager.new()
	var activities = scenario._load_generic_activities()
	for activity in activities:
		scenario.triggerable_manager.register(activity)
	print("[DEMO] Registered %d activities" % activities.size())

	for squad in scenario.world.roaming_squads:
		if starting_locations.has(squad.squad_id):
			squad.starting_location_id = starting_locations[squad.squad_id]
			squad.set_location(starting_locations[squad.squad_id])
		else:
			push_warning("[DEMO] No starting location for squad: %s" % squad.squad_id)

	print("[DEMO] World: %d locations, %d squads" % [
		scenario.world.locations.size(),
		scenario.world.roaming_squads.size()
	])
	_print_world_map()

	fleet_manager = AIFleetManager.new()
	add_child(fleet_manager)

	fleet_manager.setup(scenario)
	_assign_profiles()

	print("\n[DEMO] Battle Royale: %d squads across %d locations" % [
		fleet_manager.get_ai_squad_count(),
		scenario.world.locations.size()
	])
	_print_squad_status()

	var max_rounds := 50
	var round := 0

	while fleet_manager.get_ai_squad_count() > 1 and round < max_rounds:
		round += 1
		print("\n" + "=".repeat(80))
		print("ROUND %d — %d squads alive" % [round, fleet_manager.get_ai_squad_count()])
		print("=".repeat(80))

		var ai_results = fleet_manager.return_all_ai_turns()

		print("\n  Combats: %d | Movements: %d" % [
			ai_results["combats"].size(),
			ai_results["movements"].size()
		])

		fleet_manager.commit_ai_decisions(ai_results)

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

		scenario.world.turn_count = round

		print("\n--- End of Round %d ---" % round)
		_print_squad_status()

		await get_tree().create_timer(0.3).timeout

	_print_final_results(round, max_rounds)
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()

func _assign_profiles() -> void:
	var profile_base := "res://resources/ai/strategic/profiles/"
	for squad in scenario.world.roaming_squads:
		var profile_name = profile_assignments.get(squad.squad_id, "balanced-roamer")
		var profile_path = profile_base + profile_name + ".tres"
		var profile = AIProfileFactory.get_squad_profile(profile_path)
		if profile and fleet_manager.squad_brains.has(squad.squad_id):
			fleet_manager.squad_brains[squad.squad_id] = SquadBrain.new(squad, profile)
			print("[DEMO] Assigned %s profile to %s" % [profile_name, squad.squad_name])

func _print_world_map() -> void:
	print("\n[WORLD MAP]")
	for location in scenario.world.locations:
		var conn_names: Array[String] = []
		for conn in location.connections.tt:
			var target = scenario.world.get_location_by_id(conn.to_location_id)
			if target:
				conn_names.append(target.location_name)
		var shop_str = " [SHOP]" if location.has_shop() else ""
		print("  %s (%s)%s → %s" % [
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

		print("  [%s] %s (%s) @ %s — W:%d/%d Inj:%d Mor:%d Food:%d Gold:%.0f" % [
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
	print("\n" + "=".repeat(80))
	print("BATTLE ROYALE COMPLETE — %d rounds played" % rounds_played)
	print("=".repeat(80))

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
				print("\nWINNER: %s" % squad.squad_name)
				print("  Location: %s" % squad.current_location_id)
				print("  Warriors: %d alive" % living)
				print("  Morale: %d | Food: %d | Gold: %.0f" % [
					squad.get_morale(), squad.food, squad.money
				])
				break
	elif survivors > 1:
		print("\nTIME LIMIT — %d survivors:" % survivors)
		for squad in scenario.world.roaming_squads:
			var living := 0
			for warrior in squad.warriors:
				if not warrior.is_dead:
					living += 1
			if living > 0:
				print("  %s — W:%d Mor:%d Food:%d Gold:%.0f @ %s" % [
					squad.squad_name, living, squad.get_morale(),
					squad.food, squad.money, squad.current_location_id
				])
	else:
		print("\nALL SQUADS ELIMINATED")
