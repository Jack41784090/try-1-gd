extends RefCounted
class_name SquadBattleMasterFactory

## Factory for creating SquadBattle master scene instances
## Creates configured 3D battle scenes with provided SquadBattle data

const MASTER_SCENE = preload("res://scenes/sb-master.tscn")

static func create_battle_scene(battle: SquadBattle) -> Node3D:
	var instance = MASTER_SCENE.instantiate()
	instance.battle = battle
	instance.config = {}
	# instance.max_rounds = max_rounds
	# instance.delay_between_rounds = delay
	return instance
