class_name OneClash extends Resource

var updates: Array[EntityUpdate] = []

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
	skill.caster = attacker
	skill.target = targeted
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
		updates.append(EntityUpdate.new(
			attacker.player_id,
			target.player_id,
			EntityChange.new(SquadBattleTypes.EntityChangeable.DODGE, -1, -1)
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
		updates.append(EntityUpdate.new(
			attacker.player_id,
			target.player_id,
			EntityChange.new(SquadBattleTypes.EntityChangeable.CLINK, -1, -1)
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
	StatusEffectEventBus.EmitSignal(StatusEffectEventBus.Signals.TargetTookDamage, dm)
	# assert(emit_result == OK, "Failed to emit TargetTookDamage signal, error code: %d" % emit_result)

func cleanup() -> Array[EntityUpdate]:
	print("[OneClash] Cleanup - Total updates: %d" % updates.size())
	return updates

func commit() -> Array[EntityUpdate]:
	#region debugprints
	print("\n═══════════════════════════════════════════════════")
	print("[OneClash] CLASH START")
	print("  Attacker: %s (ID: %d)" % [attacker.entity_name, attacker.player_id])
	print("  Target: %s (ID: %d)" % [targeted.entity_name, targeted.player_id])
	if skill:
		print("  Skill: %s" % skill.name)
		print("  → Skill has %d effect(s)" % skill.effects.size())
		for i in range(skill.effects.size()):
			var effect = skill.effects[i]
			print("    %d. %s (Type: %s)" % [i + 1, effect.name, _get_effect_type_name(effect)])
			if effect.triggers.size() > 0:
				print("       Triggers on: %s" % _format_triggers(effect.triggers))
	else:
		print("  Skill: None")
	print("═══════════════════════════════════════════════════")
	#endregion
	
	# 1. Setup skill effect connections (must be done after resource loading completes)
	if skill and skill.effects.size() > 0:
		print("[OneClash] Setting up skill effect connections...")
		for effect in skill.effects:
			var effect_instance = effect.duplicate()
			# if effect_instance.affected == null:
			# 	effect_instance.affected = effect.targeting_consideration.score_then_return(
			if effect_instance.source == null:
				effect_instance.source = attacker
			effect_instance.setup_connections(updates)

	# 2. Roll for hit
	var hit = roll_for_hit()
	if not hit:
		print("[OneClash] ✗ Clash ended: MISS")
		print("═══════════════════════════════════════════════════\n")
		return cleanup()
	
	StatusEffectEventBus.EmitSignal(StatusEffectEventBus.Signals.OnBasicAttackHit, target_manifestation())
	
	# 3. Roll for pierce
	var pierce = roll_for_pierce()
	if not pierce:
		print("[OneClash] ✗ Clash ended: BLOCKED")
		print("═══════════════════════════════════════════════════\n")
		return cleanup()
	
	# 4. Calculate damage
	damage_calculation()
	
	# 5. Done
	print("[OneClash] ✓ Clash completed successfully")
	print("═══════════════════════════════════════════════════\n")
	return cleanup()

func _get_effect_type_name(effect: SkillEffect) -> String:
	if not effect:
		return "Unknown"
	match effect.commitType:
		ClashCommonTypes.CommitType.ApplyStatusEffect: return "ApplyStatusEffect"
		ClashCommonTypes.CommitType.Damage: return "Damage"
		ClashCommonTypes.CommitType.Heal: return "Heal"
		_: return "Unknown"

func _format_triggers(trigger_array: Array) -> String:
	if trigger_array.is_empty():
		return "None"
	var names = []
	for t in trigger_array:
		match t:
			StatusEffectEventBus.Signals.HelloWorld: names.append("HelloWorld")
			StatusEffectEventBus.Signals.TargetTookDamage: names.append("TargetTookDamage")
			_: names.append("Signal_%d" % t)
	return ", ".join(names)

func _emit_seeb(_signal: StatusEffectEventBus.Signals):
	StatusEffectEventBus.EmitSignal(_signal, self)
