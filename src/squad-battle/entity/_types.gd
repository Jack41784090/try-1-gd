extends RefCounted
class_name EntityConfig

var entity_type_id: EntityClasses.Types
var side: SquadBattleTypes.Side
var player_id: int
var name: String
var team: String
var stats: EntityBaseStats
var logic_enum: LogicFactory.LogicAvailable
var weapon: WeaponConfig
var weapon_class: WeaponFactory.WeaponClasses
var armor: ArmorConfig
var armor_class: ArmorFactory.ArmorClasses
var innate_skills: Array[Skill]
var starting_location: SquadBattleTypes.SquadEntityInSquadLocation = SquadBattleTypes.SquadEntityInSquadLocation.Front
var skill_set: SkillSet

func _init(
    p_entity_type_id: EntityClasses.Types,
	p_player_id: int,
	p_name: String,
	p_team: String,
	p_stats: EntityBaseStats,
	p_starting_location: SquadBattleTypes.SquadEntityInSquadLocation = SquadBattleTypes.SquadEntityInSquadLocation.Front,
	p_logic_enum: LogicFactory.LogicAvailable = LogicFactory.LogicAvailable.Frontline,
	p_weapon: WeaponConfig = null,
	p_weapon_class: WeaponFactory.WeaponClasses = WeaponFactory.WeaponClasses.Unarmed,
	p_armor: ArmorConfig = null,
	p_armor_class: ArmorFactory.ArmorClasses = ArmorFactory.ArmorClasses.Unarmored,
	p_innate_skills: Array[Skill] = [],
	p_skill_set: SkillSet = null,
):
	entity_type_id = p_entity_type_id
	player_id = p_player_id
	name = p_name
	team = p_team
	stats = p_stats
	starting_location = p_starting_location
	logic_enum = p_logic_enum
	weapon = p_weapon
	weapon_class = p_weapon_class
	armor = p_armor
	armor_class = p_armor_class
	innate_skills = p_innate_skills
	skill_set = p_skill_set
