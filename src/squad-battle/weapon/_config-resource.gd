class_name WeaponConfig extends Resource

@export var weapon_name: String = "Unarmed"
@export var hit_bonus: float
@export var penetration_bonus: float
@export var damage_translation: Array[DamageTranslation] = []
@export var weapon_location_map: Array[WeaponLocation] = []