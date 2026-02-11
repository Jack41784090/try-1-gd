extends Node

## Demo script to test headless combat execution
## Attach this to a Node in a scene and run to see headless battle results

func _ready():
	print("\n=== HEADLESS COMBAT DEMO ===\n")
	test_basic_headless_combat()

func test_basic_headless_combat():
	print("Creating test battle configuration...")
	
	# Create attacker squad (3 Landsknechts)
	var attacker_entities = []
	for i in range(3):
		attacker_entities.append(EntityFactory.EntityClasses.Landsknecht)
	
	var attacker_squad_config = {
		"entities": attacker_entities,
		"name": "Attacker SquadCombatData",
		"team": "player",
		"side": SquadBattleTypes.Side.ATTACKER
	}
	
	# Create defender squad (2 Landsknechts + 1 Healer)
	var defender_entities = []
	for i in range(2):
		defender_entities.append(EntityFactory.EntityClasses.Landsknecht)
	defender_entities.append(EntityFactory.EntityClasses.Healer)
	
	var defender_squad_config = {
		"entities": defender_entities,
		"name": "Defender SquadCombatData",
		"team": "enemy",
		"side": SquadBattleTypes.Side.DEFENDER
	}
	
	# Create battle configuration
	var battle_config = {
		"teams": {
			SquadBattleTypes.Side.ATTACKER: [attacker_squad_config],
			SquadBattleTypes.Side.DEFENDER: [defender_squad_config]
		},
		"attacker_tactic": Tactic.create_aggressive_charge(),
		"defender_tactic": Tactic.create_defensive_formation()
	}
	
	print("Initializing SquadBattle...")
	var battle = SquadBattle.new(battle_config)
	
	print("\nStarting headless combat simulation...\n")
	var all_updates = battle.run_headless()
	
	print("\n=== COMBAT RESULTS ===")
	print("Total entity updates: %d" % all_updates.size())
	print("Final outcome: %s" % SquadBattleTypes.BattleOutcome.keys()[battle.get_battle_outcome()])
	print("Rounds fought: %d/%d" % [battle.round_count, battle.max_rounds])
	
	# Print summary of updates by type
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
	
	# Print survivor counts
	var attacker_survivors = battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
	var defender_survivors = battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
	
	print("\nSurvivors:")
	print("  Attacker: %d entities remaining" % attacker_survivors)
	print("  Defender: %d entities remaining" % defender_survivors)
	
	print("\n=== DEMO COMPLETE ===\n")
