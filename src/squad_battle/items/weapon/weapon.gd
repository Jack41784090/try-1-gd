class_name Weapon
extends RefCounted

var resource: WeaponResource


func _init(config: WeaponResource):
	resource = config
	pass


func get_range_at_location(loc: int) -> Array[SquadBattleTypes.SquadEntityInSquadLocation]:
	for entry in resource.weapon_location_map:
		if entry.from == loc:
			return entry.can_hit
	return []


func get_total_penetration_value(attacker) -> float:
	return resource.penetration_bonus + resource.penetration_calc.evaluate(attacker)


func get_magical_penetration_value(attacker) -> float:
	return resource.penetration_bonus + resource.magical_penetration_calc.evaluate(attacker)


func get_total_hit_value(attacker) -> float:
	return resource.hit_bonus + resource.hit_calc.evaluate(attacker)


func get_potency_array_damage(attacker) -> Dictionary:
	var damage_potencies = {}

	for translation in resource.damage_translation:
		var contribution = translation.evaluate(attacker)
		for potency in contribution:
			damage_potencies[potency] = damage_potencies.get(potency, 0.0) + contribution[potency]

	return damage_potencies
