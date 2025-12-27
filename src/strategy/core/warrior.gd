extends Resource
class_name Warrior

@export var warrior_id: String = ""
@export var warrior_name: String = ""
@export var morale: float = 50.0
@export var religion: StrategyTypes.Religion = StrategyTypes.Religion.CATHOLIC
@export var attributes: Dictionary = {
	"diplomacy": 0,
	"survival": 0,
	"perception": 0,
	"leadership": 0,
	"stealth": 0
}

@export var combat_stats: EntityBaseStats
@export var logic_type: LogicFactory.LogicAvailable = LogicFactory.LogicAvailable.Frontline

@export var equipment_weapon: WeaponConfig
@export var equipment_armor: ArmorConfig

var is_dead: bool = false
var is_injured: bool = false

func _religion_tostring(_r):
	return StrategyTypes.Religion.keys()[_r]

func _init() -> void:
	if not combat_stats:
		combat_stats = EntityBaseStats.new()

func _to_string() -> String:
	return "Warrior(id=%s, name=%s, morale=%f, religion=%s, attributes=%s)" % [warrior_id, warrior_name, morale, _religion_tostring(religion), attributes]

func modify_morale(amount: float) -> void:
	morale = clamp(morale + amount, 0.0, 200.0)
	if morale <= 0.0:
		is_dead = true

func get_morale() -> float:
	return morale

func check_religion(religion_type: StrategyTypes.Religion) -> bool:
	return religion == religion_type

func get_attribute(attribute: StrategyTypes.WarriorAttribute) -> int:
	var key = _attribute_to_key(attribute)
	return attributes.get(key, 0)

func set_attribute(attribute: StrategyTypes.WarriorAttribute, value: int) -> void:
	var key = _attribute_to_key(attribute)
	attributes[key] = clamp(value, 0, 100)

func modify_attribute(attribute: StrategyTypes.WarriorAttribute, amount: int) -> void:
	var current = get_attribute(attribute)
	set_attribute(attribute, current + amount)

func _attribute_to_key(attribute: StrategyTypes.WarriorAttribute) -> String:
	match attribute:
		StrategyTypes.WarriorAttribute.DIPLOMACY:
			return "diplomacy"
		StrategyTypes.WarriorAttribute.SURVIVAL:
			return "survival"
		StrategyTypes.WarriorAttribute.PERCEPTION:
			return "perception"
		StrategyTypes.WarriorAttribute.LEADERSHIP:
			return "leadership"
		StrategyTypes.WarriorAttribute.STEALTH:
			return "stealth"
		_:
			return "diplomacy"

func to_squad_entity(player_id: int, team: String, starting_location: int) -> SquadEntity:
	push_warning("Warrior.to_squad_entity() - Combat bridge not yet fully implemented")
	
	var entity_config = EntityConfig.new(
		"landsnecht",
		player_id,
		warrior_name,
		team,
		combat_stats,
		starting_location,
		logic_type
	)
	if equipment_weapon:
		entity_config.weapon = equipment_weapon
	if equipment_armor:
		entity_config.armor = equipment_armor
	
	return SquadEntity.new(entity_config)

func from_combat_result(entity_update: EntityUpdate) -> void:
	push_warning("Warrior.from_combat_result() - Combat bridge not yet fully implemented")
	
	match entity_update.change.property:
		SquadBattleTypes.EntityChangeable.HP:
			if entity_update.change.to <= 0:
				is_dead = true
				morale = 0.0
			elif entity_update.change.to < entity_update.change.from:
				is_injured = true
				var damage_ratio = (entity_update.change.from - entity_update.change.to) / entity_update.change.from
				modify_morale(-damage_ratio * 20.0)
		
		SquadBattleTypes.EntityChangeable.ORG:
			var org_change = entity_update.change.to - entity_update.change.from
			modify_morale(org_change * 0.5)
		
		SquadBattleTypes.EntityChangeable.DIE:
			is_dead = true
			morale = 0.0

