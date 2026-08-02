class_name SquadArmor extends RefCounted

var armor_class: SquadBattleTypes.ArmorClasses = SquadBattleTypes.ArmorClasses.Unarmored
var defense_bonus: float
var armor_bonus: float
var magical_armor_bonus: float = 0.0
var protection_translation: Array[ProtectionTranslation] = []
var defender_ref: CombatEntity = null

func _init(config: ArmorConfig):
	assert(config != null, "ArmorConfig cannot be null")
	armor_class = config.armor_class
	defense_bonus = config.defense_bonus
	armor_bonus = config.armor_bonus
	magical_armor_bonus = config.magical_armor_bonus
	protection_translation = config.protection_translation

func set_defender(defender):
	defender_ref = defender

func get_PV() -> float:
	assert(defender_ref != null, "Armor defender_ref not set. Call set_defender() first.")
	var endurance = defender_ref.calculate_reality_value(SquadBattleTypes.Reality.HP)
	var bravery = defender_ref.calculate_reality_value(SquadBattleTypes.Reality.Bravery)
	return armor_bonus + endurance * 0.5 + bravery * 0.5

func get_magical_PV() -> float:
	assert(defender_ref != null, "Armor defender_ref not set. Call set_defender() first.")
	var spirituality = defender_ref.calculate_reality_value(SquadBattleTypes.Reality.Spirituality)
	var willpower = defender_ref.calculate_reality_value(SquadBattleTypes.Reality.Bravery)
	return magical_armor_bonus + spirituality * 0.5 + willpower * 0.5

func get_raw_damage_taken(raw_damage: Dictionary) -> float:
	assert(defender_ref != null, "Armor defender_ref not set. Call set_defender() first.")
	
	var total_damage = 0.0
	var protection_dict = {}
	for translation in protection_translation:
		var reality = translation.Reality
		var potency_list = translation.PotencyList
		var defenders_reality = defender_ref.calculate_reality_value(reality)
		for potency_entry in potency_list:
			var potency = potency_entry.potency
			var value = potency_entry.value
			var potency_protection = value * defenders_reality
			if not protection_dict.has(potency):
				protection_dict[potency] = 0
			protection_dict[potency] += potency_protection
	
	for potency in raw_damage:
		var damage = raw_damage[potency]
		var protection = protection_dict.get(potency, 0.0)
		var final_damage = max(0.0, damage - protection)
		total_damage += final_damage
	
	return total_damage
