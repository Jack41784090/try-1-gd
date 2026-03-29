class_name OneClash
extends Resource

var updates: Array[EntityUpdate] = []

@export var affecteds: Array[CombatEntity] = []
@export var attacker: CombatEntity
@export var targeted: CombatEntity
@export var skill: Skill
var situation: Situation
var context: Dictionary


func _init(
		_attacker: CombatEntity = null,
		_targeted: CombatEntity = null,
		_skill: Skill = null,
		_situation: Situation = null,
		_context: Dictionary = { },
):
	# If all parameters are null, we're being loaded from a resource file
	# The @export variables will be set by the resource loader
	if _attacker == null and _targeted == null and _skill == null:
		return

	skill = _skill
	attacker = _attacker
	targeted = _targeted
	affecteds = [_targeted] # todo: change affected based on skill AOE or not
	situation = _situation
	context = _context


func target_manifestation():
	return targeted


func roll_for_hit() -> bool:
	# Roll attacker's weapon hit value vs defender's evasion
	# Hit = random(0..weapon_hit) vs random(0..evasion). If evasion >= hit → DODGE
	# e.g., weapon_hit=80, evasion=20 → roll 56 vs roll 12 → HIT (56 > 12)
	# e.g., weapon_hit=50, evasion=40 → roll 20 vs roll 35 → DODGE (35 >= 20)
	var chosen_weapon = attacker.weapon
	var target = target_manifestation()

	var try_hit = chosen_weapon.get_total_hit_value(attacker)
	var hit_def = target.calculate_reality_value(SquadBattleTypes.Reality.Maneuver)
	var roll_offence_hit = randf() * try_hit
	var roll_defence_hit = randf() * hit_def

	print("[OneClash] Hit roll: %s vs %s — attacker %.2f / weapon base %.2f, defender evasion %.2f" % [attacker.entity_name, target.entity_name, roll_offence_hit, try_hit, roll_defence_hit])

	if roll_defence_hit >= roll_offence_hit:
		print("  ✗ DODGED")
		updates.append(
			EntityUpdate.new(
				attacker.player_id,
				target.player_id,
				EntityChange.new(SquadBattleTypes.EntityChangeable.DODGE, -1, -1),
			),
		)
		return false

	return true


func roll_for_pierce() -> bool:
	# Roll weapon penetration vs armour protection value
	# Pierce = random(0..penetration) vs random(0..armour_PV). If armour >= pierce → BLOCKED (Clink)
	# e.g., penetration=60, armour_PV=30 → roll 42 vs roll 18 → PIERCE (42 > 18)
	# e.g., penetration=40, armour_PV=50 → roll 25 vs roll 40 → BLOCKED (40 >= 25)
	var chosen_weapon = attacker.weapon
	var target = target_manifestation()
	var armour = target.get_armour()

	var try_hit: float
	var hit_def: float
	if chosen_weapon.is_magical:
		try_hit = chosen_weapon.get_magical_penetration_value(attacker)
		hit_def = armour.get_magical_PV()
	else:
		try_hit = chosen_weapon.get_total_penetration_value(attacker)
		hit_def = armour.get_PV()
	var roll_offence_hit = randf() * try_hit
	var roll_defence_hit = randf() * hit_def

	print("[OneClash] Pierce roll: pen %.2f/%.2f vs arm %.2f/%.2f%s" % [roll_offence_hit, try_hit, roll_defence_hit, hit_def, " [magical]" if chosen_weapon.is_magical else ""])

	if roll_defence_hit >= roll_offence_hit:
		print("  ✗ BLOCKED")
		updates.append(
			EntityUpdate.new(
				attacker.player_id,
				target.player_id,
				EntityChange.new(SquadBattleTypes.EntityChangeable.CLINK, -1, -1),
			),
		)
		return false

	print("  ✓ PIERCE")
	return true


func damage_calculation():
	# Calculates final damage: weapon potency → armour damage reduction → apply to target HP
	# e.g., weapon raw_damage=[15, 8, 5] (slash/pierce/blunt), armour reduces to total 20
	#   → target.damage(20, attacker_id) → target HP 80→60 → EntityUpdate(HP: 80→60)
	var chosen_weapon = attacker.weapon
	var target = target_manifestation()
	var armour = target.get_armour()
	var raw_damage = chosen_weapon.get_potency_array_damage(attacker)
	var dm = armour.get_raw_damage_taken(raw_damage)

	var hp_before = target.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var damage_updates = target.damage(dm, attacker.player_id)
	for update in damage_updates:
		updates.append(update)

	var hp_after = target.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	print("  → Dealt %.2f to %s — HP %.1f→%.1f" % [dm, target.entity_name, hp_before, hp_after])
	StatusEffectEventBus.EmitSignal(StatusEffectEventBus.Signals.TargetTookDamage, dm)


func cleanup() -> Array[EntityUpdate]:
	var parts: Array[String] = []
	for u in updates:
		if u.change != null:
			parts.append(str(u))
	if parts.size() > 0:
		print("  ↳ %s" % "  ".join(parts))
	return updates


func commit() -> Array[EntityUpdate]:
	# Executes a full single clash: skill setup → hit roll → pierce roll → damage calculation
	# Returns all EntityUpdate objects generated during this clash
	# e.g., Hans attacks Fritz with "Slash":
	#   → skill effects connected → roll hit (HIT) → roll pierce (PIERCE) → damage 30 → Fritz HP 80→50
	#   → returns [EntityUpdate(Hans→Fritz, HP: 80→50)]
	# e.g., Hans attacks Fritz with "Heal" (roll_for_damage=false):
	#   → skill effects fire immediately → no hit/pierce rolls → returns [EntityUpdate(Hans→Fritz, HP: 40→60)]
	#region debugprints
	# Set up skill context directly — avoids re-running targeting consideration a second time
	skill.caster = attacker
	skill.situation = situation
	skill.context = context
	skill.target = targeted
	var bc = BattleContext.from_dict(context) if context.size() > 0 else null
	for e in skill.effects:
		e.set_attacker_and_target(attacker, targeted, bc)

	var is_self_cast = attacker.player_id == targeted.player_id
	if is_self_cast:
		print("\n[OneClash] [%d]%s ‹%s› on self" % [attacker.player_id, attacker.entity_name, skill.name if skill else "?"])
	else:
		print("\n[OneClash] [%d]%s → [%d]%s | ‹%s›" % [attacker.player_id, attacker.entity_name, targeted.player_id, targeted.entity_name, skill.name if skill else "?"])
	#endregion

	# 1. Setup skill effect connections (must be done after resource loading completes)
	var real_effects = skill.return_appropriate_skill_effects()
	if skill and real_effects.size() > 0:
		for effect in real_effects:
			var effect_instance = effect

			assert(effect_instance != null, "Effect instance [%s] is null" % effect.name) # if null, check if [return_who_to_cast_at] is called
			assert(effect_instance.source != null, "Effect source [%s] is null" % effect.name)
			assert(effect_instance.affected != null, "Effect affected [%s] is null" % effect.name)

			effect_instance.setup_connections(updates)

	StatusEffectEventBus.EmitSignal(StatusEffectEventBus.Signals.OnCastSkill)

	# 2. Roll for hit → pierce → damage (only for damage skills)
	if skill.roll_for_damage:
		var hit = roll_for_hit()
		if not hit:
			return cleanup()

		StatusEffectEventBus.EmitSignal(StatusEffectEventBus.Signals.OnBasicAttackHit, target_manifestation())

		var pierce = roll_for_pierce()
		if not pierce:
			return cleanup()

		damage_calculation()

	return cleanup()

# func _get_effect_type_name(effect: SkillEffect) -> String:
# 	if not effect:
# 		return "Unknown"
# 	match effect.commitType:
# 		ClashCommonTypes.CommitType.ApplyStatusEffect: return "ApplyStatusEffect"
# 		ClashCommonTypes.CommitType.Damage: return "Damage"
# 		ClashCommonTypes.CommitType.Heal: return "Heal"
# 		_: return "Unknown"


func _format_triggers(trigger_array: Array) -> String:
	if trigger_array.is_empty():
		return "None"
	var keys = StatusEffectEventBus.Signals.keys()
	var names = []
	for t in trigger_array:
		names.append(keys[t] if t >= 0 and t < keys.size() else "Signal_%d" % t)
	return ", ".join(names)


func _emit_seeb(_signal: StatusEffectEventBus.Signals):
	StatusEffectEventBus.EmitSignal(_signal, self)
