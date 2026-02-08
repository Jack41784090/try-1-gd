extends Node

## Battle Royale Demo - Load existing scenario and let AI squads fight
## Tests headless combat and AI fleet management

func _ready():
	print("\n" + "=".repeat(80))
	print("AI BATTLE ROYALE DEMO - HEADLESS COMBAT TEST")
	print("=".repeat(80) + "\n")
	
	# Load existing combat-test scenario
	var scenario_path := "res://resources/scenarios/combat-test/combat-test-scenario.tres"
	var scenario = load(scenario_path) as GameScenario
	scenario.initialize()
	
	if scenario == null:
		push_error("[DEMO] Failed to load scenario from %s" % scenario_path)
		get_tree().quit(1)
		return
	
	# Initialize triggerable manager and register all activities
	if scenario.triggerable_manager == null:
		scenario.triggerable_manager = TriggerableManager.new()
	
	
	print("[DEMO] Loaded scenario: %s" % scenario_path)
	print("[DEMO] World has %d locations" % scenario.world.locations.size())
	print("[DEMO] World has %d roaming squads" % scenario.world.roaming_squads.size())
	
	# Mark all squads as AI-controlled for battle royale
	# for squad in scenario.world.roaming_squads:
	# 	squad.is_player_squad = false
	
	# Create and setup fleet manager
	var fleet_manager = AIFleetManager.new()
	add_child(fleet_manager)
	fleet_manager.setup(scenario)
	
	print("\n[DEMO] Battle Royale initialized with %d squads" % fleet_manager.get_ai_squad_count())
	_print_squad_status(scenario)
	
	# Run simulation for multiple rounds
	var max_rounds = 20
	var round = 0
	
	while fleet_manager.get_ai_squad_count() > 1 and round < max_rounds:
		round += 1
		print("\n" + "=".repeat(80))
		print("ROUND %d - %d squads remaining" % [round, fleet_manager.get_ai_squad_count()])
		print("=".repeat(80))
		
		# Get AI decisions
		var ai_results = fleet_manager.return_all_ai_turns()
		
		print("\n[DEMO] Turn results:")
		print("  - Combats: %d" % ai_results["combats"].size())
		print("  - Movements: %d" % ai_results["movements"].size())
		
		# Commit the decisions
		fleet_manager.commit_ai_decisions(ai_results)
		
	# Advance world turn counter
		print("\n[DEMO] End of round %d status:" % round)
		_print_squad_status(scenario)
		
		# Brief pause for readability
		await get_tree().create_timer(0.5).timeout
	
	# Final results
	print("\n" + "=".repeat(80))
	print("BATTLE ROYALE COMPLETE")
	print("=".repeat(80))
	
	var survivors = fleet_manager.get_ai_squad_count()
	if survivors == 1:
		for squad in scenario.world.roaming_squads:
			var living_count = 0
			for warrior in squad.warriors:
				if warrior != null and not warrior.is_dead:
					living_count += 1
			
			if living_count > 0:
				print("\n🏆 WINNER: %s" % squad.squad_name)
				print("   Location: %s" % squad.current_location_id)
				print("   Morale: %d" % squad.get_morale())
				print("   Money: %d" % squad.money)
				print("   Food: %d" % squad.food)
				print("\n   Warriors:")
				for warrior: Warrior in squad.warriors:
					if warrior != null and not warrior.is_dead:
						print("     - %s (Injured: %s)" % [
							warrior.name,
							# warrior.,
							"Yes" if warrior.is_injured else "No"
						])
				break
	elif survivors > 1:
		print("\n⏱️ TIME LIMIT - Multiple survivors:")
		for squad in scenario.world.roaming_squads:
			var living_count = 0
			for warrior in squad.warriors:
				if warrior != null and not warrior.is_dead:
					living_count += 1
			if living_count > 0:
				print("  - %s (Morale: %d)" % [squad.squad_name, squad.get_morale()])
	else:
		print("\n💀 ALL SQUADS ELIMINATED")
	
	print("\n[DEMO] Demo complete. Exiting in 2 seconds...")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()

## Print status of all squads
func _print_squad_status(scenario: GameScenario) -> void:
	for squad in scenario.world.roaming_squads:
		var living_warriors = 0
		for warrior in squad.warriors:
			if not warrior.is_dead:
				living_warriors += 1
		
		print("  [%s] %s - Location: %s, Morale: %d, Warriors: %d/%d" % [
			squad.squad_id,
			squad.squad_name,
			squad.current_location_id,
			squad.get_morale(),
			living_warriors,
			squad.warriors.size()
		])
