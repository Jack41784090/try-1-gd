class_name WeaponResource
extends CombatEquipment

@export var icon: Texture2D = PlaceholderTexture2D.new()
@export var weapon_class: SquadBattleTypes.WeaponClasses = SquadBattleTypes.WeaponClasses.Unarmed
@export var hit_bonus: float
@export var penetration_bonus: float
@export var damage_translation: Array[DamageTranslation] = []
@export var is_magical: bool = false
@export var weapon_location_map: Array[WeaponLocation] = []
@export var hit_calc: Calculation
@export var penetration_calc: Calculation
@export var magical_penetration_calc: Calculation
