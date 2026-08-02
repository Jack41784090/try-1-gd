extends Node

## Demo script to test headless combat execution
## Attach this to a Node in a scene and run to see headless battle results

func _ready():
	print("\n=== HEADLESS COMBAT DEMO ===\n")

	# --- test basic headless combat ---
	print("Creating test battle configuration...")
	
	var attacker_entities: Array[String] = []
	for i in range(3):
		attacker_entities.append("landsknecht")

	var defender_entities: Array[String] = []
	for i in range(2):
		defender_entities.append("landsknecht")
	defender_entities.append("healer")

	var teams: Dictionary[SquadBattleTypes.Side, Array] = {
		SquadBattleTypes.Side.ATTACKER: [
			["Attacker CombatSquad", SquadBattleTypes.Side.ATTACKER, attacker_entities],
		],
		SquadBattleTypes.Side.DEFENDER: [
			["Defender CombatSquad", SquadBattleTypes.Side.DEFENDER, defender_entities],
		],
	}

	print("Initializing SquadBattle...")
	var battle = SquadBattle.new(teams, Tactic.create_aggressive_charge(), Tactic.create_defensive_formation())
	
	print("\nStarting headless combat simulation...\n")
	var all_updates = battle.run_headless()
	
	print("\n=== COMBAT RESULTS ===")
	print("Total entity updates: %d" % all_updates.size())
	print("Final outcome: %s" % SquadBattleTypes.BattleOutcome.keys()[battle.get_battle_outcome()])
	print("Rounds fought: %d/%d" % [battle.round_count, battle.max_rounds])
	
	var hp_changes = 0
	var deaths = 0
	var other_changes = 0
	
	for update in all_updates:
		match update.change.property:
			SquadBattleTypes.EntityChangeable.HP:
				hp_changes += 1
				if update.change.to <= 0:
					deaths += 1
			SquadBattleTypes.EntityChangeable.DIE:
				deaths += 1
			_:
				other_changes += 1
	
	print("\nUpdate breakdown:")
	print("  HP changes: %d" % hp_changes)
	print("  Deaths: %d" % deaths)
	print("  Other changes: %d" % other_changes)
	
	var attacker_survivors = battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
	var defender_survivors = battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
	
	print("\nSurvivors:")
	print("  Attacker: %d entities remaining" % attacker_survivors)
	print("  Defender: %d entities remaining" % defender_survivors)
	
	print("\n=== DEMO COMPLETE ===\n")
