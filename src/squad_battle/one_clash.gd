extends RefCounted
class_name OneClash

const Types = preload("res://src/squad_battle/types.gd")

var updates: Array = []
var attacker
var targets: Array = []
var defender
var skill: Dictionary
var status_effect_disconnects: Array = []

func _init(config: Dictionary):
	attacker = config.get("attacker")
	defender = config.get("defender")
	targets = config.get("targets", [defender if defender else attacker])
	skill = config.get("skill", {})

func target_manifestation():
	assert(defender != null, "No defender")
	return defender

func remove_destroyed_status_effects():
	var attacker_before = attacker.status_effects.size()
	attacker.status_effects = attacker.status_effects.filter(func(se): return se.duration != 0)
	
	if attacker_before > attacker.status_effects.size():
		print("[OneClash] Attacker: ", attacker_before - attacker.status_effects.size(), " status effect(s) removed")
	
	if defender:
		var defender_before = defender.status_effects.size()
		defender.status_effects = defender.status_effects.filter(func(se): return se.duration != 0)
		
		if defender_before > defender.status_effects.size():
			print("[OneClash] Defender: ", defender_before - defender.status_effects.size(), " status effect(s) removed")

func subscribe_existing_status_effects_to_event_bus():
	for se in attacker.status_effects:
		print("[OneClash] A:Registering existing status effect")
	
	if defender:
		for se in defender.status_effects:
			print("[OneClash] D:Registering existing status effect")

func subscribe_new_skill_status_effects_to_event_bus():
	if not skill.has("effects"):
		return
	
	for effect in skill["effects"]:
		var effect_targets = []
		if effect.get("affected") == "self":
			effect_targets = [attacker]
		else:
			effect_targets = targets
		
		for target in effect_targets:
			print("[OneClash] Registering skill effect")

func roll_for_hit() -> bool:
	var chosen_weapon = attacker.weapon
	var target = target_manifestation()
	
	var try_hit = chosen_weapon.get_total_hit_value(attacker)
	var hit_def = 0
	var roll_offence_hit = randf() * try_hit
	var roll_defence_hit = randf() * hit_def
	
	if roll_defence_hit >= roll_offence_hit:
		updates.append(Types.EntityUpdate.new(
			attacker.player_id,
			target.player_id,
			Types.EntityChange.new("DODGE", -1, -1)
		))
	
	return roll_offence_hit > roll_defence_hit

func roll_for_pierce() -> bool:
	var chosen_weapon = attacker.weapon
	var target = target_manifestation()
	var armour = target.get_armour()
	
	var try_hit = chosen_weapon.get_total_penetration_value(attacker)
	var hit_def = armour.get_PV()
	var roll_offence_hit = randf() * try_hit
	var roll_defence_hit = randf() * hit_def
	
	if roll_defence_hit >= roll_offence_hit:
		updates.append(Types.EntityUpdate.new(
			attacker.player_id,
			target.player_id,
			Types.EntityChange.new("CLINK", -1, -1)
		))
	
	return roll_offence_hit > roll_defence_hit

func damage_calculation():
	var chosen_weapon = attacker.weapon
	var target = target_manifestation()
	var armour = target.get_armour()
	var dm = armour.get_raw_damage_taken(chosen_weapon.get_potency_array_damage(attacker))
	
	var damage_updates = target.damage(dm, attacker.player_id)
	for update in damage_updates:
		updates.append(update)
	
	apply_skill_effects_on_hit(target, dm)

func apply_skill_effects_on_hit(target, damage_dealt: float):
	if not skill.has("effects"):
		return
	
	for effect in skill["effects"]:
		if effect.get("trigger") != "OnBasicAttackHit":
			continue
		
		var effect_target = attacker if effect.get("affected") == "self" else target
		var effect_updates = apply_effect(effect, effect_target, damage_dealt)
		for update in effect_updates:
			updates.append(update)

func apply_effect(effect: Dictionary, target, _damage_dealt: float) -> Array:
	var effect_updates: Array = []
	var effect_type = effect.get("effect", {}).get("type", "")
	
	match effect_type:
		"Damage":
			var damage_effect = effect.get("effect", {})
			var calculation = damage_effect.get("calculation", {})
			var damage_amount = 0.0
			
			match calculation.get("type", "Flat"):
				"Flat":
					damage_amount = damage_effect.get("amount", 0.0)
				"StatScaling":
					var stat = calculation.get("stat")
					var percent = calculation.get("percent", 0.0)
					if stat != null:
						var stat_value = attacker.calculate_reality_value(stat)
						damage_amount = stat_value * percent
			
			if damage_amount > 0:
				var dmg_updates = target.damage(damage_amount, attacker.player_id)
				for u in dmg_updates:
					effect_updates.append(u)
		
		"Heal":
			var heal_amount = effect.get("effect", {}).get("amount", 0.0)
			var heal_change = target.heal(heal_amount)
			if heal_change:
				effect_updates.append(Types.EntityUpdate.new(attacker.player_id, target.player_id, heal_change))
		
		"ApplyStatusEffect":
			print("[OneClash] ApplyStatusEffect not yet implemented")
		
		"ModifyStat":
			print("[OneClash] ModifyStat not yet implemented")
	
	return effect_updates

func disconnect_all():
	print("[OneClash] Disconnecting all status effect listeners")
	for disconnect_func in status_effect_disconnects:
		if disconnect_func is Callable:
			disconnect_func.call()

func cleanup() -> Array:
	remove_destroyed_status_effects()
	disconnect_all()
	return updates

func commit() -> Array:
	subscribe_existing_status_effects_to_event_bus()
	subscribe_new_skill_status_effects_to_event_bus()
	
	var hit = roll_for_hit()
	if not hit:
		return cleanup()
	
	var pierce = roll_for_pierce()
	if not pierce:
		return cleanup()
	
	damage_calculation()
	return cleanup()
