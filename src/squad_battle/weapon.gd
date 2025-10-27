extends RefCounted
class_name SquadWeapon

const Types = preload("res://src/squad_battle/types.gd")

var hit_bonus: float
var penetration_bonus: float
var damage_translation: Array = []
var weapon_location_map: Array = []
var weapon_name: String = "Unarmed"

func unarmed() -> SquadWeapon:
	hit_bonus = 0
	penetration_bonus = 0
	damage_translation = [
		[Types.Reality.Force, [[Types.Potency.Strike, 1]]]
	]
	weapon_location_map = [
		[Types.SquadEntityInSquadLocation.Front, [Types.SquadEntityInSquadLocation.Front]],
		[Types.SquadEntityInSquadLocation.Middle, []],
		[Types.SquadEntityInSquadLocation.Back, []]
	]
	return self

func _init(config: Types.WeaponConfig = null):
	if config:
		hit_bonus = config.hit_bonus
		penetration_bonus = config.penetration_bonus
		
		for reality in config.damage_translation:
			var potency_array = config.damage_translation[reality]
			damage_translation.append([reality, potency_array])
		
		for loc in config.weapon_range:
			var range_array = config.weapon_range[loc]
			weapon_location_map.append([loc, range_array])
	else:
		unarmed()

func get_range_at_location(loc: int) -> Array:
	for entry in weapon_location_map:
		if entry[0] == loc:
			return entry[1]
	return []

func get_total_penetration_value(attacker) -> float:
	var force = attacker.calculate_reality_value(Types.Reality.Force)
	var precision = attacker.calculate_reality_value(Types.Reality.Precision)
	var result = penetration_bonus + force * 0.67 + precision * 0.33
	return result

func get_total_hit_value(attacker) -> float:
	var maneuver = attacker.calculate_reality_value(Types.Reality.Maneuver)
	var precision = attacker.calculate_reality_value(Types.Reality.Precision)
	var result = hit_bonus + maneuver / 2.0 + precision / 2.0
	return result

func get_potency_array_damage(attacker) -> Dictionary:
	var damage_potencies = {}
	
	for translation in damage_translation:
		var reality = translation[0]
		var potency_list = translation[1]
		var warriors_reality = attacker.calculate_reality_value(reality)
		
		for potency_entry in potency_list:
			var potency = potency_entry[0]
			var value = potency_entry[1]
			var potency_damage = value * warriors_reality
			
			if not damage_potencies.has(potency):
				damage_potencies[potency] = 0
			damage_potencies[potency] += potency_damage
	
	return damage_potencies

func get_potency_damage(potency: Types.Potency, attacker) -> float:
	var damage = 0.0
	
	for translation in damage_translation:
		var reality = translation[0]
		var potency_list = translation[1]
		
		for potency_entry in potency_list:
			if potency_entry[0] == potency:
				var warriors_reality = attacker.calculate_reality_value(reality)
				damage += potency_entry[1] * warriors_reality
	
	return damage

func get_raw_weapon_damage(attacker) -> float:
	var damage = 0.0
	
	for translation in damage_translation:
		var reality = translation[0]
		var potency_list = translation[1]
		var warriors_reality = attacker.calculate_reality_value(reality)
		
		for potency_entry in potency_list:
			var value = potency_entry[1]
			damage += value * warriors_reality
	
	return damage

func get_weapon_skills(source: SquadEntity) -> Array[Skill]:
	return [
		Skill.new(
			weapon_name + "-basic-attack",
			[SkillEffect.new(
				weapon_name + "-basic-attack",
				source,
				null,
				ClashCommonTypes.CommitType.Damage,
				[StatusEffectEventBus.Signals.OnBasicAttackHit],
				{
					"calculationType": ClashCommonTypes.CalculationType.Flat,
					"value": 1.0
				}
			)]
		)
		# {
		# 	"id": weapon_name + "-basic-attack",
		# 	"name": weapon_name + " Attack",
		# 	"effects": [{
		# 		"name": weapon_name + "-basic-attack",
		# 		"affected": "target",
		# 		"trigger": "OnBasicAttackHit",
		# 		"duration": 0,
		# 		"original_source": source.player_id,
		# 		"affected_id": -1,
		# 		"effect": {
		# 			"type": "Damage",
		# 			"damage_type": "Physical",
		# 			"amount": 1
		# 		}
		# 	}]
		# }
	]

func get_state() -> Dictionary:
	var state = {
		"hit_bonus": hit_bonus,
		"penetration_bonus": penetration_bonus,
		"damage_translation": {},
		"weapon_range": {}
	}
	
	for translation in damage_translation:
		state["damage_translation"][translation[0]] = translation[1]
	
	for location_entry in weapon_location_map:
		state["weapon_range"][location_entry[0]] = location_entry[1]
	
	return state
