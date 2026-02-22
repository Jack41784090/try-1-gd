class_name WarriorRigFactory extends RefCounted

const WARRIOR_RIG_SCENE_PATH = "res://scenes/warrior_rig.tscn"

static var _scene_cache: PackedScene

static func create_rig_for_warrior(warrior: CharacterSocialStats) -> WarriorRig:
	var rig = _instantiate_rig()
	rig.setup(warrior.class_id, warrior.id)

	var config = WarriorRigConfigFactory.get_config(warrior.class_id)
	if config:
		rig.apply_config(config)

	return rig

static func create_rig_for_npc(character_id: String) -> WarriorRig:
	var rig = _instantiate_rig()
	var hash_val = character_id.hash()
	var class_id = (abs(hash_val) % EntityClasses.Types.size()) as EntityClasses.Types
	rig.setup(class_id, character_id)

	var config = WarriorRigConfigFactory.get_config(class_id)
	if config:
		rig.apply_config(config)

	return rig

static func _instantiate_rig() -> WarriorRig:
	if not _scene_cache:
		_scene_cache = load(WARRIOR_RIG_SCENE_PATH) as PackedScene
		assert(_scene_cache != null, "Failed to load WarriorRig scene from: %s" % WARRIOR_RIG_SCENE_PATH)
	return _scene_cache.instantiate() as WarriorRig
