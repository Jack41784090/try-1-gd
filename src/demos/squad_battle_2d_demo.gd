extends Control

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("SQUAD BATTLE 2D VIEW/PRESENTER DEMO")
	print("=".repeat(60))

	var battle = _create_demo_battle()
	var battle_scene = SquadBattleMasterFactory.create_battle_scene(battle)
	add_child(battle_scene)

	var presenter = battle_scene.get_node("SquadBattlePresenter")
	print("[Demo] Battle scene instantiated, awaiting completion...")

	var outcome = await presenter.battle_completed

	print("\n" + "=".repeat(60))
	print("[Demo] Battle finished: %s" % SquadBattleTypes.BattleOutcome.keys()[outcome])
	print("=".repeat(60))

	await get_tree().create_timer(2.0).timeout
	get_tree().quit()


func _create_demo_battle() -> SquadBattle:
	var config = {
		"teams": {
			SquadBattleTypes.Side.ATTACKER: [{
				"side": SquadBattleTypes.Side.ATTACKER,
				"name": "Player Squad",
				"team": "player",
				"entities": [
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Healer,
					EntityClasses.Types.Crossbowman,
				]
			}],
			SquadBattleTypes.Side.DEFENDER: [{
				"side": SquadBattleTypes.Side.DEFENDER,
				"name": "Enemy Warband",
				"team": "enemy",
				"entities": [
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Pikeman,
					EntityClasses.Types.Landsknecht,
				]
			}]
		},
		"attacker_tactic": Tactic.create_aggressive_charge(),
		"defender_tactic": Tactic.create_guerilla_defence()
	}
	return SquadBattle.new(config)
