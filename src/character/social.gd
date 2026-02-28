class_name CharacterSocialStats extends Resource

@export var id: String = ""
@export var name: String = ""
@export var class_id: EntityClasses.Types = EntityClasses.Types.Landsknecht
@export var social_class: StrategyTypes.SocialClass = StrategyTypes.SocialClass.SOLDIER
@export var morale: float = 50.0
@export var religion: StrategyTypes.Religion = StrategyTypes.Religion.CATHOLIC
@export var attributes: Dictionary = {
	"diplomacy": 0,
	"survival": 0,
	"perception": 0,
	"leadership": 0,
	"stealth": 0
}
@export var location_prebattle: SquadBattleTypes.SquadEntityInSquadLocation = SquadBattleTypes.SquadEntityInSquadLocation.Back

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
	return "CharacterSocialStats(morale=%f, religion=%s, attributes=%s)" % [morale, _religion_tostring(religion), attributes]

func modify_morale(amount: float) -> void:
	morale = clamp(morale + amount, 0.0, 200.0)

func get_morale() -> float:
	return morale

func check_religion(religion_type: StrategyTypes.Religion) -> bool:
	return religion == religion_type

func get_demand() -> Dictionary:
	var food = StrategyTypes.get_social_class_food_demand(
		social_class
	)
	return {
		StrategyTypes.SquadProperty.FOOD_SUPPLIES: food
	}

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

func convert_to_entity(entity_id, team, starting_loc, ) -> EntityConfig:
	var e_config = EntityConfig.new(
		self.class_id,
		entity_id,
		self.name,
		team,
		self.combat_stats if self.combat_stats else EntityBaseStats.new(),
		starting_loc,
		self.logic_type
	)
	
	if self.equipment_weapon:
		e_config.weapon = self.equipment_weapon
	else:
		e_config.weapon_class = WeaponFactory.WeaponClasses.Unarmed
		print("[CombatBridge]   CharacterSocialStats '%s' has no weapon, using Unarmed" % self.name)
	
	if self.equipment_armor:
		e_config.armor = self.equipment_armor
	else:
		e_config.armor_class = ArmorFactory.ArmorClasses.Unarmored
		print("[CombatBridge]   CharacterSocialStats '%s' has no armor, using Unarmored" % self.name)

	return e_config
		

func from_combat_result(entity_update: EntityUpdate) -> void:
	push_warning("CharacterSocialStats.from_combat_result() - Combat bridge not yet fully implemented")
	
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
