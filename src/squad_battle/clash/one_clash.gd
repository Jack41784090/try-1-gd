class_name OneClash
extends RefCounted

var updates: Array[EntityUpdate] = []

var affecteds: Array[CombatEntity] = []
var attacker: CombatEntity
var targeted: CombatEntity
var skill: Skill
var situation: Situation
var context: Dictionary


func _init(
		_attacker: CombatEntity = null,
		_targeted: CombatEntity = null,
		_skill: Skill = null,
		_situation: Situation = null,
		_context: Dictionary = {},
):
	## If all parameters are null, we're being loaded from a resource file
	## The @export variables will be set by the resource loader
	if _attacker == null and _targeted == null and _skill == null:
		return

	skill = _skill
	attacker = _attacker
	targeted = _targeted
	affecteds = [_targeted]
	situation = _situation
	context = _context


func target_manifestation() -> CombatEntity:
	return targeted


func _get_attacker_skill_level() -> float:
	if attacker.skill_set == null:
		return 0.0
	var skill_type := WeaponFactory.get_skill_used(attacker.weapon.resource.weapon_class)
	return float(attacker.skill_set.get_level(skill_type))


func cleanup() -> Array[EntityUpdate]:
	var parts: Array[String] = []
	for u in updates:
		if u.change != null:
			parts.append(str(u))
	if parts.size() > 0:
		Log.trace("OneClash", "↳ %s" % "  ".join(parts))
	return updates


func commit() -> Array[EntityUpdate]:
	## Executes a full single clash: skill setup → hit roll → pierce roll → damage calculation
	## Returns all EntityUpdate objects generated during this clash
	## e.g., Hans attacks Fritz with "Slash":
	##   → skill effects connected → roll hit (HIT) → roll pierce (PIERCE) → damage 30 → Fritz HP 80→50
	##   → returns [EntityUpdate(Hans→Fritz, HP: 80→50)]
	## e.g., Hans attacks Fritz with "Heal" (roll_for_damage=false):
	##   → skill effects fire immediately → no hit/pierce rolls → returns [EntityUpdate(Hans→Fritz, HP: 40→60)]
	skill.caster = attacker
	skill.situation = situation
	skill.context = context
	skill.target = targeted
	var bc = BattleContext.from_dict(context) if context.size() > 0 else null
	for e in skill.effects:
		e.set_attacker_and_target(attacker, targeted, bc)

	var is_self_cast = attacker.player_id == targeted.player_id
	if is_self_cast:
		Log.debug("OneClash", "[%d]%s ‹%s› on self" % [attacker.player_id, attacker.display_name, skill.name if skill else "?"])
	else:
		Log.debug("OneClash", "[%d]%s → [%d]%s | ‹%s›" % [attacker.player_id, attacker.display_name, targeted.player_id, targeted.display_name, skill.name if skill else "?"])

	var real_effects = skill.return_appropriate_skill_effects()
	if skill and real_effects.size() > 0:
		for effect in real_effects:
			var effect_instance = effect

			assert(effect_instance != null, "Effect instance [%s] is null" % effect.name) # if null, check if [return_who_to_cast_at] is called
			assert(effect_instance.source != null, "Effect source [%s] is null" % effect.name)
			assert(effect_instance.affected != null, "Effect affected [%s] is null" % effect.name)

			effect_instance.setup_connections(updates)

	StatusEffectEventBus.EmitSignal(StatusEffectEventBus.Signals.OnCastSkill)

	if skill.roll_for_damage:
		# --- roll_for_hit ---
		var chosen_weapon = attacker.weapon
		var target = target_manifestation()
		var try_hit = chosen_weapon.get_total_hit_value(attacker)
		var skill_level: float = _get_attacker_skill_level()
		try_hit += skill_level * 2.0
		var hit_def = target.calculate_reality_value(SquadBattleTypes.Reality.Maneuver)
		var roll_offence_hit = randf() * try_hit
		var roll_defence_hit = randf() * hit_def
		Log.trace("OneClash", "Hit roll: %s vs %s — attacker %.2f / weapon base %.2f, defender evasion %.2f" % [attacker.display_name, target.display_name, roll_offence_hit, try_hit, roll_defence_hit])
		if roll_defence_hit >= roll_offence_hit:
			Log.trace("OneClash", "✗ DODGED")
			updates.append(
				EntityUpdate.new(
					attacker.player_id,
					target.player_id,
					EntityChange.new(SquadBattleTypes.EntityChangeable.DODGE, -1, -1),
				),
			)
			return cleanup()

		StatusEffectEventBus.EmitSignal(StatusEffectEventBus.Signals.OnBasicAttackHit, target)

		# --- roll_for_pierce ---
		var armour = target.get_armour()
		var try_pierce: float
		var pierce_def: float
		if chosen_weapon.resource.is_magical:
			try_pierce = chosen_weapon.get_magical_penetration_value(attacker) + skill_level * 2.0
			pierce_def = armour.get_magical_PV()
		else:
			try_pierce = chosen_weapon.get_total_penetration_value(attacker) + skill_level * 2.0
			pierce_def = armour.get_PV()
		var roll_offence_pierce = randf() * try_pierce
		var roll_defence_pierce = randf() * pierce_def
		Log.trace("OneClash", "Pierce roll: pen %.2f/%.2f vs arm %.2f/%.2f%s" % [roll_offence_pierce, try_pierce, roll_defence_pierce, pierce_def, " [magical]" if chosen_weapon.resource.is_magical else ""])
		if roll_defence_pierce >= roll_offence_pierce:
			Log.trace("OneClash", "✗ BLOCKED")
			updates.append(
				EntityUpdate.new(
					attacker.player_id,
					target.player_id,
					EntityChange.new(SquadBattleTypes.EntityChangeable.CLINK, -1, -1),
				),
			)
			return cleanup()
		Log.trace("OneClash", "✓ PIERCE")

		# --- damage_calculation ---
		var skill_bonus: float = skill_level * 0.5
		var raw_damage = chosen_weapon.get_potency_array_damage(attacker)
		var dm = armour.get_raw_damage_taken(raw_damage) + skill_bonus
		var hp_before = target.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
		var damage_updates = target.damage(dm, attacker.player_id)
		for update in damage_updates:
			updates.append(update)
		var hp_after = target.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
		Log.trace("OneClash", "→ Dealt %.2f to %s — HP %.1f→%.1f" % [dm, target.display_name, hp_before, hp_after])
		StatusEffectEventBus.EmitSignal(StatusEffectEventBus.Signals.TargetTookDamage, dm)

	return cleanup()

func _format_triggers(trigger_array: Array[int]) -> String:
	if trigger_array.is_empty():
		return "None"
	var keys = StatusEffectEventBus.Signals.keys()
	var values = StatusEffectEventBus.Signals.values()
	var names: Array[String] = []
	for t in trigger_array:
		var idx = values.find(t)
		names.append(keys[idx] if idx >= 0 else "Signal_%d" % t)
	return ", ".join(names)


func _emit_seeb(_signal: StatusEffectEventBus.Signals) -> void:
	StatusEffectEventBus.EmitSignal(_signal, self )
