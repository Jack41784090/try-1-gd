@tool
class_name TestStrategyEntity
extends Resource

@export var display_name: String
@export var resource: TestStrategyEntityResource:
	set(value):
		if resource == value:
			return
		resource = value
		_reinit()
@export_tool_button("Rebuild stats", "Reload") var rebuild: Callable = _reinit
@export var rs_arr: Dictionary[StatName.I, ReactiveStat];

#@export var morale: ReactiveStat

#@export var equipment_weapon: WeaponResource
#@export var equipment_armor: ArmorConfig
#@export var is_dead: bool
#@export var is_injured: bool
#@export var move_speed: float

func get_stat_value(key: StatName.I) -> Variant:
	var v = get_stat(key)
	return v.stat_value if v else null

func get_stat(key: StatName.I) -> ReactiveStat:
	return rs_arr.get(key)

func _init(_resource: TestStrategyEntityResource = null) -> void:
	resource = _resource
	_reinit()
	#morale = .5
	#move_speed = 5.
	#if _resource:
		#display_name = _resource.name

#func emit_changed():
	#pass
	
func _on_rs_changed(...any) -> void:
	emit_changed()

func _reinit() -> void:
	display_name = "Testing"
	var rebuilt: Dictionary[StatName.I, ReactiveStat] = {}
	if resource:
		for rs in resource.rs_array:
			var dup: ReactiveStat = rs.duplicate(true)
			dup.changed.connect(_on_rs_changed)
			rebuilt[rs.stat_name] = dup
	rs_arr = rebuilt
	emit_changed()
	notify_property_list_changed.call_deferred()

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
