class_name WarriorRigFactory extends RefCounted

const WARRIOR_RIG_SCENE_PATH = "res://scenes/rig/warrior_rig_2.tscn"

static var _scene_cache: PackedScene

## Identity is read leniently rather than through Character.get_combat_identification(): rig art is cosmetic, so a warrior without a resource should still get a rig instead of tripping an assert.
static func create_rig_for_warrior(warrior: Character) -> WarriorRig:
	var identity := warrior.combat_identification
	if identity.is_empty() and warrior.strategy and warrior.strategy.resource:
		identity = warrior.strategy.resource.identification
	return _create_rig(identity, warrior.id)

static func create_rig_for_entity(entity: CombatEntity) -> WarriorRig:
	var identity := entity.resource.codename if entity.resource else ""
	return _create_rig(identity, str(entity.player_id))

static func create_rig_for_npc(character_id: String) -> WarriorRig:
	return _create_rig(character_id, character_id)

## `config_id` picks the look (a class or character name); `rig_id` is who this particular rig belongs to, reported back to callers.
static func _create_rig(config_id: String, rig_id: String) -> WarriorRig:
	if not _scene_cache:
		_scene_cache = load(WARRIOR_RIG_SCENE_PATH) as PackedScene
		assert(_scene_cache != null, "Failed to load WarriorRig scene from: %s" % WARRIOR_RIG_SCENE_PATH)
	var rig := _scene_cache.instantiate() as WarriorRig
	rig.setup_default(rig_id)
	var config = WarriorRigConfigFactory.get_config(config_id)
	if config:
		rig.apply_config(config)
	return rig
