class_name WarriorBackground extends Resource

@export var background_id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
@export var cost: int = 100
@export var stats_template_path: String = ""
@export var default_weapon_id: StringName = &""
@export var default_armor_id: StringName = &""
@export var default_role: LogicFactory.LogicAvailable = LogicFactory.LogicAvailable.Frontline
@export var default_position: SquadBattleTypes.SquadEntityInSquadLocation = SquadBattleTypes.SquadEntityInSquadLocation.Front
@export var default_skills: Dictionary = {}
@export var speed_kmh: float = 5.0
