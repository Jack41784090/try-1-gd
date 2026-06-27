class_name ArmorConfig extends CombatEquipment

@export var armor_class: SquadBattleTypes.ArmorClasses = SquadBattleTypes.ArmorClasses.Unarmored
@export var defense_bonus: float
@export var armor_bonus: float
@export var magical_armor_bonus: float = 0.0
@export var protection_translation: Array[ProtectionTranslation] = []
