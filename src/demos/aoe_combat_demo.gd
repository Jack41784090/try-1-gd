extends Node

func _ready():
	print("\n=== AOE COMBAT DEMO (Gelehrter + Splash) ===\n")

	print("Setting up squads with Gelehrter mage units...\n")

	var attacker_entities = [
		"landsknecht",
		"landsknecht",
		"gelehrter",
		"gelehrter",
		"healer",
	]

	var defender_entities = [
		"landsknecht",
		"landsknecht",
		"landsknecht",
		"pikeman",
		"crossbowman",
	]

	var teams: Dictionary[SquadBattleTypes.Side, Array] = {
		SquadBattleTypes.Side.ATTACKER: [
			["Alchemists' Guild", SquadBattleTypes.Side.ATTACKER, attacker_entities],
		],
		SquadBattleTypes.Side.DEFENDER: [
			["Town Militia", SquadBattleTypes.Side.DEFENDER, defender_entities],
		],
	}

	print("Initializing SquadBattle...")
	var battle = SquadBattle.new(teams, Tactic.create_full_assault(), Tactic.create_aggressive_charge())

	print("\n--- INITIAL POSITIONS ---")
	_print_squad_positions(battle, SquadBattleTypes.Side.ATTACKER, "Alchemists' Guild")
	_print_squad_positions(battle, SquadBattleTypes.Side.DEFENDER, "Town Militia")

	print("\nStarting headless combat simulation...\n")
	var all_updates = battle.run_headless()

	print("\n=== COMBAT RESULTS ===")
	print("Total entity updates: %d" % all_updates.size())
	print("Final outcome: %s" % SquadBattleTypes.BattleOutcome.keys()[battle.get_battle_outcome()])
	print("Rounds fought: %d/%d" % [battle.round_count, battle.max_rounds])

	var hp_changes = 0
	var org_changes = 0
	var deaths = 0
	var loc_changes = 0
	var clinks = 0
	var other_changes = 0

	for update in all_updates:
		match update.change.property:
			SquadBattleTypes.EntityChangeable.HP:
				hp_changes += 1
			SquadBattleTypes.EntityChangeable.ORG:
				org_changes += 1
			SquadBattleTypes.EntityChangeable.DIE:
				deaths += 1
			SquadBattleTypes.EntityChangeable.LOC:
				loc_changes += 1
			SquadBattleTypes.EntityChangeable.CLINK:
				clinks += 1
			_:
				other_changes += 1

	print("\nUpdate breakdown:")
	print("  HP changes: %d" % hp_changes)
	print("  ORG changes: %d" % org_changes)
	print("  Location changes: %d (movement)" % loc_changes)
	print("  Deaths: %d" % deaths)
	print("  Clinks (blocked): %d" % clinks)
	print("  Other changes: %d" % other_changes)

	print("\n--- FINAL POSITIONS ---")
	_print_squad_positions(battle, SquadBattleTypes.Side.ATTACKER, "Alchemists' Guild")
	_print_squad_positions(battle, SquadBattleTypes.Side.DEFENDER, "Town Militia")

	var attacker_strength = battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
	var defender_strength = battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
	print("\nFinal strength:")
	print("  Attacker: %.0f HP remaining" % attacker_strength)
	print("  Defender: %.0f HP remaining" % defender_strength)

	print("\n=== DEMO COMPLETE ===\n")

	get_tree().quit()

func _print_squad_positions(battle: SquadBattle, side: SquadBattleTypes.Side, label: String):
	var squads = battle.side_squads_dict.get(side, [])
	print("  %s:" % label)
	for squad in squads:
		for entity in squad.entities:
			var loc = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC)
			var hp = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
			var hp_max = entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
			var org = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
			var loc_name = SquadBattleTypes.SquadEntityInSquadLocation.keys()[loc - 1] if loc >= 1 and loc <= 3 else "?"
			var magical_tag = " [magical]" if entity.weapon and entity.weapon.resource.is_magical else ""
			print("    %s [%s] HP:%.0f/%.0f ORG:%.1f Weapon:%s%s" % [
				entity.display_name, loc_name, hp, hp_max, org,
				SquadBattleTypes.WeaponClasses.keys()[entity.weapon.resource.weapon_class] if entity.weapon else "None",
				magical_tag
			])
