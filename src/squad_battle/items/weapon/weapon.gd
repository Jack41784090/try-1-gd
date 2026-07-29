class_name Weapon
extends RefCounted

var resource: WeaponResource


func _init(config: WeaponResource):
	resource = config
	pass


func get_range_at_location(loc: int) -> Array:
	for entry in resource.weapon_location_map:
		if entry.from == loc:
			return entry.can_hit
	return []


func get_total_penetration_value(attacker) -> float:
	var force = attacker.calculate_reality_value(SquadBattleTypes.Reality.Force)
	var precision = attacker.calculate_reality_value(SquadBattleTypes.Reality.Precision)
	var result = resource.penetration_bonus + force * 0.67 + precision * 0.33
	return result


func get_magical_penetration_value(attacker) -> float:
	var mana = attacker.calculate_reality_value(SquadBattleTypes.Reality.Mana)
	var spirituality = attacker.calculate_reality_value(SquadBattleTypes.Reality.Spirituality)
	return resource.penetration_bonus + mana * 0.67 + spirituality * 0.33


func get_total_hit_value(attacker) -> float:
	var maneuver = attacker.calculate_reality_value(SquadBattleTypes.Reality.Maneuver)
	var precision = attacker.calculate_reality_value(SquadBattleTypes.Reality.Precision)
	var result = resource.hit_bonus + maneuver / 2.0 + precision / 2.0
	return result


func get_potency_array_damage(attacker) -> Dictionary:
	var damage_potencies = {}

	for translation in resource.damage_translation:
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

	for translation in resource.damage_translation:
		var reality = translation.reality
		var potency_list = translation.potency_list

		for potency_entry in potency_list:
			if potency_entry.potency == potency:
				var warriors_reality = attacker.calculate_reality_value(reality)
				damage += potency_entry.value * warriors_reality

	return damage


func get_raw_weapon_damage(attacker) -> float:
	var damage = 0.0

	for translation in resource.damage_translation:
		var reality = translation.reality
		var potency_list = translation.potency_list
		var warriors_reality = attacker.calculate_reality_value(reality)

		for potency_entry in potency_list:
			var value = potency_entry.value
			damage += value * warriors_reality

	return damage
