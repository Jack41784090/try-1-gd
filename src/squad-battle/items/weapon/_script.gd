class_name SquadWeapon extends RefCounted

var weapon_class: SquadBattleTypes.WeaponClasses = SquadBattleTypes.WeaponClasses.Unarmed
var hit_bonus: float
var penetration_bonus: float
var is_magical: bool = false
var damage_translation: Array[DamageTranslation] = []
var weapon_location_map: Array[WeaponLocation] = []

func _init(config: WeaponConfig):
	assert(config != null, "WeaponConfig cannot be null")
	weapon_class = config.weapon_class
	hit_bonus = config.hit_bonus
	penetration_bonus = config.penetration_bonus
	is_magical = config.is_magical
	damage_translation = config.damage_translation
	weapon_location_map = config.weapon_location_map

func get_range_at_location(loc: int) -> Array:
	for entry in weapon_location_map:
		if entry.from == loc:
			return entry.can_hit
	return []

func get_total_penetration_value(attacker) -> float:
	var force = attacker.calculate_reality_value(SquadBattleTypes.Reality.Force)
	var precision = attacker.calculate_reality_value(SquadBattleTypes.Reality.Precision)
	var result = penetration_bonus + force * 0.67 + precision * 0.33
	return result

func get_magical_penetration_value(attacker) -> float:
	var mana = attacker.calculate_reality_value(SquadBattleTypes.Reality.Mana)
	var spirituality = attacker.calculate_reality_value(SquadBattleTypes.Reality.Spirituality)
	return penetration_bonus + mana * 0.67 + spirituality * 0.33

func get_total_hit_value(attacker) -> float:
	var maneuver = attacker.calculate_reality_value(SquadBattleTypes.Reality.Maneuver)
	var precision = attacker.calculate_reality_value(SquadBattleTypes.Reality.Precision)
	var result = hit_bonus + maneuver / 2.0 + precision / 2.0
	return result

func get_potency_array_damage(attacker) -> Dictionary:
	var damage_potencies = {}
	
	for translation in damage_translation:
		var reality = translation.reality
		var potency_list = translation.potency_list
		var warriors_reality = attacker.calculate_reality_value(reality)
		
		for potency_entry in potency_list:
			var potency = potency_entry.potency
			var value = potency_entry.value
			var potency_damage = value * warriors_reality
			
			if not damage_potencies.has(potency):
				damage_potencies[potency] = 0
			damage_potencies[potency] += potency_damage
	
	return damage_potencies

func get_potency_damage(potency: SquadBattleTypes.Potency, attacker) -> float:
	var damage = 0.0
	
	for translation in damage_translation:
		var reality = translation.reality
		var potency_list = translation.potency_list
		
		for potency_entry in potency_list:
			if potency_entry.potency == potency:
				var warriors_reality = attacker.calculate_reality_value(reality)
				damage += potency_entry.value * warriors_reality
	
	return damage

func get_raw_weapon_damage(attacker) -> float:
	var damage = 0.0
	
	for translation in damage_translation:
		var reality = translation.reality
		var potency_list = translation.potency_list
		var warriors_reality = attacker.calculate_reality_value(reality)
		
		for potency_entry in potency_list:
			var value = potency_entry.value
			damage += value * warriors_reality
	
	return damage
