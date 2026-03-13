extends Node3D

## Battle demo to test combat SFX: sword_hit, combat clink, death,
## victory_fanfare / defeat. Uses the graphical View/Presenter pipeline
## so sounds actually play through the SFX autoload.
## Run with F6 in the Godot editor (NOT headless — needs audio output).

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("SFX BATTLE DEMO")
	print("=".repeat(60))
	print("Listen for: sword hits, armor clinks, death sounds, victory/defeat fanfare")

	var battle = _create_sfx_battle()
	var battle_scene = SquadBattleMasterFactory.create_battle_scene(battle)
	add_child(battle_scene)

	var presenter = battle_scene.get_node("SquadBattlePresenter")
	presenter.delay_between_rounds = 1.8

	var outcome = await presenter.battle_completed

	print("\n" + "=".repeat(60))
	print("[SfxDemo] Battle finished: %s" % SquadBattleTypes.BattleOutcome.keys()[outcome])
	print("=".repeat(60))

	await get_tree().create_timer(3.0).timeout
	get_tree().quit()


func _create_sfx_battle() -> SquadBattle:
	var config = {
		"teams": {
			SquadBattleTypes.Side.ATTACKER: [{
				"side": SquadBattleTypes.Side.ATTACKER,
				"name": "Player Warband",
				"team": "player",
				"entities": [
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Healer,
					EntityClasses.Types.Landsknecht,
				]
			}],
			SquadBattleTypes.Side.DEFENDER: [{
				"side": SquadBattleTypes.Side.DEFENDER,
				"name": "Enemy Warband",
				"team": "enemy",
				"entities": [
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Healer,
					EntityClasses.Types.Landsknecht,
				]
			}]
		},
		"attacker_tactic": Tactic.create_full_assault(),
		"defender_tactic": Tactic.create_aggressive_charge(),
	}
	return SquadBattle.new(config)
