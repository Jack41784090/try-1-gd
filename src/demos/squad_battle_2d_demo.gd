extends Control

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("SQUAD BATTLE 2D DEMO")
	print("=".repeat(60))

	var battle = _create_demo_battle()
	var battle_scene = SquadBattleMasterFactory.create_battle_scene(battle)
	add_child(battle_scene)

	print("[Demo] Battle scene instantiated, awaiting completion...")

	var outcome = await battle.battle_completed

	print("\n" + "=".repeat(60))
	print("[Demo] Battle finished: %s" % SquadBattleTypes.BattleOutcome.keys()[outcome])
	print("=".repeat(60))

	await get_tree().create_timer(2.0).timeout
	get_tree().quit()


func _create_demo_battle() -> SquadBattle:
	var teams: Dictionary[SquadBattleTypes.Side, Array] = {
		SquadBattleTypes.Side.ATTACKER: [
			["Player Squad", SquadBattleTypes.Side.ATTACKER, ["landsknecht", "landsknecht", "healer", "crossbowman"]],
		],
		SquadBattleTypes.Side.DEFENDER: [
			["Enemy Warband", SquadBattleTypes.Side.DEFENDER, ["landsknecht", "pikeman", "landsknecht"]],
		],
	}
	return SquadBattle.new(teams, Tactic.create_aggressive_charge(), Tactic.create_guerilla_defence())
