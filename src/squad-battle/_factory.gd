extends RefCounted
class_name SquadBattleMasterFactory

const MASTER_SCENE = preload("res://scenes/sb-master.tscn")

static func create_battle_scene(battle: SquadBattle) -> Node3D:
	var instance = MASTER_SCENE.instantiate()
	instance.battle = battle
	instance.config = {}
	return instance
