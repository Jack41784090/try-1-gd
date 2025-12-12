class_name SquadArmor extends RefCounted

var armor_name: String = "Unarmored"
var defense_bonus: float
var armor_bonus: float
var protection_translation: Array[ProtectionTranslation] = []
var defender_ref = null

func _init(config: ArmorConfig):
	assert(config != null, "ArmorConfig cannot be null")
	armor_name = config.armor_name
	defense_bonus = config.defense_bonus
	armor_bonus = config.armor_bonus
	protection_translation = config.protection_translation

func set_defender(defender):
	defender_ref = defender

func get_total_armor_value(defender) -> float:
	var endurance = defender.calculate_reality_value(SquadBattleTypes.Reality.HP)
	var bravery = defender.calculate_reality_value(SquadBattleTypes.Reality.Bravery)
	var result = armor_bonus + endurance * 0.5 + bravery * 0.5
	return result

func get_total_defense_value(defender) -> float:
	var maneuver = defender.calculate_reality_value(SquadBattleTypes.Reality.Maneuver)
	var bravery = defender.calculate_reality_value(SquadBattleTypes.Reality.Bravery)
	var result = defense_bonus + maneuver / 2.0 + bravery / 2.0
	return result

func get_protection_array(defender) -> Dictionary:
	var protections = {}
	
	for translation in protection_translation:
		var reality = translation.Reality
		var potency_list = translation.PotencyList
		var defenders_reality = defender.calculate_reality_value(reality)
		
		for potency_entry in potency_list:
			var potency = potency_entry.potency
			var value = potency_entry.value
			var potency_protection = value * defenders_reality
			
			if not protections.has(potency):
				protections[potency] = 0
			protections[potency] += potency_protection
	
	return protections

func get_potency_protection(potency: SquadBattleTypes.Potency, defender) -> float:
	var protection = 0.0
	
	for translation in protection_translation:
		var reality = translation.Reality
		var potency_list = translation.PotencyList
		
		for potency_entry in potency_list:
			if potency_entry.potency == potency:
				var defenders_reality = defender.calculate_reality_value(reality)
				protection += potency_entry.value * defenders_reality
	
	return protection

func get_raw_armor_protection(defender) -> float:
	var protection = 0.0
	
	for translation in protection_translation:
		var reality = translation.Reality
		var potency_list = translation.PotencyList
		var defenders_reality = defender.calculate_reality_value(reality)
		
		for potency_entry in potency_list:
			var value = potency_entry.value
			protection += value * defenders_reality
	
	return protection

func get_PV() -> float:
	assert(defender_ref != null, "Armor defender_ref not set. Call set_defender() first.")
	return get_total_armor_value(defender_ref)

func get_raw_damage_taken(raw_damage: Dictionary) -> float:
	assert(defender_ref != null, "Armor defender_ref not set. Call set_defender() first.")
	
	var total_damage = 0.0
	var protection_dict = get_protection_array(defender_ref)
	
	for potency in raw_damage:
		var damage = raw_damage[potency]
		var protection = protection_dict.get(potency, 0.0)
		var final_damage = max(0.0, damage - protection)
		total_damage += final_damage
	
	return total_damage

