class_name StrategyEntity
extends Node

var resource: StrategyEntityResource
var morale: float:
	set(_m):
		morale = clamp(_m, 0.0, 1.0)

var display_name: String
var equipment_weapon: WeaponResource
var equipment_armor: ArmorConfig
var is_dead: bool
var is_injured: bool
var move_speed: float


func _init(_resource: StrategyEntityResource) -> void:
	morale = .5
	move_speed = 5.
	resource = _resource
	display_name = resource.name


func _religion_tostring(_r):
	return StrategyTypes.Religion.keys()[_r]

# func _to_string() -> String:
# 	return "StrategyEntity(morale=%f, religion=%s, attributes=%s)" % [morale, _religion_tostring(resource.religion), attributes]


func check_religion(religion_type: StrategyTypes.Religion) -> bool:
	return resource.religion == religion_type


func get_demand() -> Dictionary:
	return {
		StrategyTypes.SquadProperty.FOOD_SUPPLIES: 5,
	}

# func get_attribute(attribute: StrategyTypes.WarriorAttribute) -> int:
# 	var key = _attribute_to_key(attribute)
# 	return attributes.get(key, 0)

# func set_attribute(attribute: StrategyTypes.WarriorAttribute, value: int) -> void:
# 	var key = _attribute_to_key(attribute)
# 	attributes[key] = clamp(value, 0, 100)

# func modify_attribute(attribute: StrategyTypes.WarriorAttribute, amount: int) -> void:
# 	var current = get_attribute(attribute)
# 	set_attribute(attribute, current + amount)

# func _attribute_to_key(attribute: StrategyTypes.WarriorAttribute) -> String:
# 	match attribute:
# 		StrategyTypes.WarriorAttribute.DIPLOMACY:
# 			return "diplomacy"
# 		StrategyTypes.WarriorAttribute.SURVIVAL:
# 			return "survival"
# 		StrategyTypes.WarriorAttribute.PERCEPTION:
# 			return "perception"
# 		StrategyTypes.WarriorAttribute.LEADERSHIP:
# 			return "leadership"
# 		StrategyTypes.WarriorAttribute.STEALTH:
# 			return "stealth"
# 		_:
# 			return "diplomacy"

## A StrategyEntity's combat profile is its `identification` template
## (CombatEntityResource); the config wraps that template with this entity's
## battlefield placement.
# func convert_to_entity(entity_id: int, team: String, starting_loc) -> CombatEntityConfig:
# 	var res := CombatEntityFactory.get_resource(identification)
# 	return CombatEntityConfig.new(res, entity_id, team, starting_loc)

# func from_combat_result(entity_update: EntityUpdate) -> void:
# 	match entity_update.change.property:
# 		SquadBattleTypes.EntityChangeable.HP:
# 			if entity_update.change.to <= 0:
# 				is_dead = true
# 				morale = 0.0
# 			elif entity_update.change.to < entity_update.change.from:
# 				is_injured = true
# 				var damage_ratio = (entity_update.change.from - entity_update.change.to) / entity_update.change.from
# 				modify_morale(-damage_ratio * 20.0)

# 		SquadBattleTypes.EntityChangeable.ORG:
# 			var org_change = entity_update.change.to - entity_update.change.from
# 			modify_morale(org_change * 0.5)

# 		SquadBattleTypes.EntityChangeable.DIE:
# 			is_dead = true
# 			morale = 0.0
