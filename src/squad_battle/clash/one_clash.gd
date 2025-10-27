class_name OneClash extends Resource

var updates: Array[SquadBattleTypes.EntityUpdate] = []

@export var affecteds: Array[SquadEntity] = []
@export var attacker: SquadEntity
@export var targeted: SquadEntity
@export var skill: Skill

func _init(
	_attacker: SquadEntity = null,
	_targeted: SquadEntity = null,
	_skill: Skill = null
):
	# If all parameters are null, we're being loaded from a resource file
	# The @export variables will be set by the resource loader
	if _attacker == null and _targeted == null and _skill == null:
		return
		
	attacker = _attacker
	targeted = _targeted
	skill = _skill
	affecteds = [_targeted] # todo: change affected based on skill AOE or not

func target_manifestation():
	return targeted

func roll_for_hit() -> bool:
	var chosen_weapon = attacker.weapon
	var target = target_manifestation()
	
	var try_hit = chosen_weapon.get_total_hit_value(attacker)
	var hit_def = 0
	var roll_offence_hit = randf() * try_hit
	var roll_defence_hit = randf() * hit_def
	
	print("[OneClash] Rolling for Hit: %s attacks %s" % [attacker.entity_name, target.entity_name])
	print("  → Attacker Hit: %.2f (%.2f roll × %.2f base)" % [roll_offence_hit, randf(), try_hit])
	print("  → Defender Evasion: %.2f" % roll_defence_hit)
	
	if roll_defence_hit >= roll_offence_hit:
		print("  ✗ DODGED!")
		updates.append(SquadBattleTypes.EntityUpdate.new(
			attacker.player_id,
			target.player_id,
			SquadBattleTypes.EntityChange.new(SquadBattleTypes.EntityChangeable.DODGE, -1, -1)
		))
		return false
	
	print("  ✓ HIT SUCCESS!")
	return true

func roll_for_pierce() -> bool:
	var chosen_weapon = attacker.weapon
	var target = target_manifestation()
	var armour = target.get_armour()
	
	var try_hit = chosen_weapon.get_total_penetration_value(attacker)
	var hit_def = armour.get_PV()
	var roll_offence_hit = randf() * try_hit
	var roll_defence_hit = randf() * hit_def
	
	print("[OneClash] Rolling for Pierce:")
	print("  → Weapon Penetration: %.2f (%.2f roll × %.2f base)" % [roll_offence_hit, randf(), try_hit])
	print("  → Armour Defense: %.2f (%.2f roll × %.2f PV)" % [roll_defence_hit, randf(), hit_def])
	
	if roll_defence_hit >= roll_offence_hit:
		print("  ✗ BLOCKED! (Clink)")
		updates.append(SquadBattleTypes.EntityUpdate.new(
			attacker.player_id,
			target.player_id,
			SquadBattleTypes.EntityChange.new(SquadBattleTypes.EntityChangeable.CLINK, -1, -1)
		))
		return false
	
	print("  ✓ PIERCE SUCCESS!")
	return true

func damage_calculation():
	var chosen_weapon = attacker.weapon
	var target = target_manifestation()
	var armour = target.get_armour()
	var raw_damage = chosen_weapon.get_potency_array_damage(attacker)
	var dm = armour.get_raw_damage_taken(raw_damage)
	
	print("[OneClash] Calculating Damage:")
	#print("  → Raw Weapon Damage: %.2f" % raw_damage)
	print("  → After Armour Reduction: %.2f" % dm)
	print("  → Target HP Before: %.2f" % target.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP))
	
	var damage_updates = target.damage(dm, attacker.player_id)
	for update in damage_updates:
		print("  → Update: %s" % [update])
		updates.append(update)
	
	print("  → Target HP After: %.2f" % target.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP))
	print("[OneClash] Emitting TargetTookDamage signal")
	StatusEffectEventBus.emitSignal(StatusEffectEventBus.Signals.TargetTookDamage)

func apply_effect(effect: Dictionary, target, _damage_dealt: float) -> Array:
	var effect_updates: Array = []
	var effect_type = effect.get("effect", {}).get("type", "")
	
	print("[OneClash] Applying Effect: %s" % effect_type)
	
	match effect_type:
		"Damage":
			var damage_effect = effect.get("effect", {})
			var calculation = damage_effect.get("calculation", {})
			var damage_amount = 0.0
			
			match calculation.get("type", "Flat"):
				"Flat":
					damage_amount = damage_effect.get("amount", 0.0)
					print("  → Flat Damage: %.2f" % damage_amount)
				"StatScaling":
					var stat = calculation.get("stat")
					var percent = calculation.get("percent", 0.0)
					if stat != null:
						var stat_value = attacker.calculate_reality_value(stat)
						damage_amount = stat_value * percent
						print("  → Stat Scaling: %s × %.2f%% = %.2f" % [stat, percent * 100, damage_amount])
			
			if damage_amount > 0:
				print("  → Dealing %.2f damage to %s" % [damage_amount, target.entity_name])
				var dmg_updates = target.damage(damage_amount, attacker.player_id)
				for u in dmg_updates:
					effect_updates.append(u)
		
		"Heal":
			var heal_amount = effect.get("effect", {}).get("amount", 0.0)
			print("  → Healing %.2f to %s" % [heal_amount, target.entity_name])
			var heal_change = target.heal(heal_amount)
			if heal_change:
				effect_updates.append(SquadBattleTypes.EntityUpdate.new(attacker.player_id, target.player_id, heal_change))
		
		"ApplyStatusEffect":
			print("  → ApplyStatusEffect not yet implemented")
		
		"ModifyStat":
			print("  → ModifyStat not yet implemented")
	
	return effect_updates

func cleanup() -> Array:
	print("[OneClash] Cleanup - Total updates: %d" % updates.size())
	#remove_destroyed_status_effects()
	return updates

func commit() -> Array:
	print("\n═══════════════════════════════════════════════════")
	print("[OneClash] CLASH START")
	print("  Attacker: %s (ID: %d)" % [attacker.entity_name, attacker.player_id])
	print("  Target: %s (ID: %d)" % [targeted.entity_name, targeted.player_id])
	print("  Skill: %s" % skill.name if skill else "None")
	print("═══════════════════════════════════════════════════")
	
	#subscribe_existing_status_effects_to_event_bus()
	#subscribe_new_skill_status_effects_to_event_bus()
	
	var hit = roll_for_hit()
	if not hit:
		print("[OneClash] ✗ Clash ended: MISS")
		print("═══════════════════════════════════════════════════\n")
		return cleanup()
	
	var pierce = roll_for_pierce()
	if not pierce:
		print("[OneClash] ✗ Clash ended: BLOCKED")
		print("═══════════════════════════════════════════════════\n")
		return cleanup()
	
	damage_calculation()
	print("[OneClash] ✓ Clash completed successfully")
	print("═══════════════════════════════════════════════════\n")
	return cleanup()
