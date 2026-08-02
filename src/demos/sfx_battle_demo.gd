extends Node3D

## Battle demo to test combat SFX: sword_hit, combat clink, death,
## victory_fanfare / defeat. Uses the graphical battle view
## so sounds actually play through the SFX autoload.
## Run with F6 in the Godot editor (NOT headless — needs audio output).

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("SFX BATTLE DEMO")
	print("=".repeat(60))
	print("Listen for: sword hits, armor clinks, death sounds, victory/defeat fanfare")

	# --- create sfx battle ---
	var teams: Dictionary[SquadBattleTypes.Side, Array] = {
		SquadBattleTypes.Side.ATTACKER: [
			["Player Warband", SquadBattleTypes.Side.ATTACKER, ["landsknecht", "landsknecht", "landsknecht", "healer", "landsknecht"]],
		],
		SquadBattleTypes.Side.DEFENDER: [
			["Enemy Warband", SquadBattleTypes.Side.DEFENDER, ["landsknecht", "landsknecht", "landsknecht", "healer", "landsknecht"]],
		],
	}
	var battle := SquadBattle.new(teams, Tactic.create_full_assault(), Tactic.create_aggressive_charge())

	var battle_scene = SquadBattleMasterFactory.create_battle_scene(battle)
	add_child(battle_scene)

	battle_scene.delay_between_rounds = 1.8

	var outcome = await battle.battle_completed

	print("\n" + "=".repeat(60))
	print("[SfxDemo] Battle finished: %s" % SquadBattleTypes.BattleOutcome.keys()[outcome])
	print("=".repeat(60))

	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
