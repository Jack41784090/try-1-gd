class_name ClashResolver
extends RefCounted

const MAX_DEPTH: int = 8

var updates: Array[EntityUpdate] = []
var _stack: Array[ClashIntent] = []
var _budget: Dictionary = {}
var _latch: Dictionary = {}
var _reaction_budget: int = 0
var _all_entities: Array[CombatEntity] = []


func set_entities(entities: Array[CombatEntity]) -> void:
	_all_entities = entities


func begin_round(reaction_budget: int) -> void:
	_budget.clear()
	_latch.clear()
	_reaction_budget = reaction_budget


func resolve(root: ClashIntent) -> Array[EntityUpdate]:
	updates = []
	_stack = [root]

	while not _stack.is_empty():
		var top: ClashIntent = _stack.back()
		if top.phase == ClashIntent.Phase.PROPOSED:
			top.phase = ClashIntent.Phase.GATHERED
			_gather(SquadBattleTypes.ReactionWindow.ON_CAST, top)
			if _stack.back() != top:
				continue
		if top.phase == ClashIntent.Phase.CANCELLED:
			if top.cause:
				updates.append(EntityUpdate.new(
					top.caster.player_id,
					top.target.player_id,
					EntityChange.new(SquadBattleTypes.EntityChangeable.PROC, -1, -1, top.metadata()),
				))
			_stack.pop_back()
			continue

		# --- _commit ---
		var attacker := top.caster
		var targeted := top.target
		var skill := top.skill

		skill.caster = attacker
		skill.situation = top.situation
		skill.context = top.context
		skill.target = targeted
		var bc = BattleContext.from_dict(top.context) if top.context.size() > 0 else null
		for e in skill.effects:
			e.set_attacker_and_target(attacker, targeted, bc)

		var is_self_cast := attacker.player_id == targeted.player_id
		if is_self_cast:
			Log.debug("ClashResolver", "[%d]%s ‹%s› on self" % [attacker.player_id, attacker.display_name, skill.name if skill else "?"])
		else:
			Log.debug("ClashResolver", "[%d]%s → [%d]%s | ‹%s›" % [attacker.player_id, attacker.display_name, targeted.player_id, targeted.display_name, skill.name if skill else "?"])

		var real_effects = skill.return_appropriate_skill_effects()
		if real_effects.size() > 0:
			for effect in real_effects:
				assert(effect != null, "Effect instance [%s] is null" % effect.name)
				assert(effect.source != null, "Effect source [%s] is null" % effect.name)
				assert(effect.affected != null, "Effect affected [%s] is null" % effect.name)
				effect.setup_connections(updates)

		StatusEffectEventBus.EmitSignal(StatusEffectEventBus.Signals.OnCastSkill)

		if skill.roll_for_damage:
			# --- _roll_for_hit ---
			var chosen_weapon = attacker.weapon
			var try_hit = chosen_weapon.get_total_hit_value(attacker)
			var skill_level := _get_skill_level(attacker)
			try_hit += skill_level * 2.0
			var hit_def = targeted.calculate_reality_value(SquadBattleTypes.Reality.Maneuver)
			var roll_offence_hit = randf() * try_hit
			var roll_defence_hit = randf() * hit_def
			Log.trace("ClashResolver", "Hit roll: %s vs %s — attacker %.2f / weapon base %.2f, defender evasion %.2f" % [attacker.display_name, targeted.display_name, roll_offence_hit, try_hit, roll_defence_hit])
			if roll_defence_hit >= roll_offence_hit:
				Log.trace("ClashResolver", "✗ DODGED")
				updates.append(EntityUpdate.new(
					attacker.player_id,
					targeted.player_id,
					EntityChange.new(SquadBattleTypes.EntityChangeable.DODGE, -1, -1),
				))
				raise_window(SquadBattleTypes.ReactionWindow.ON_DODGE, top)
			else:
				raise_window(SquadBattleTypes.ReactionWindow.ON_HIT, top)
				StatusEffectEventBus.EmitSignal(StatusEffectEventBus.Signals.OnBasicAttackHit, targeted)

				# --- _roll_for_pierce ---
				var armour = targeted.get_armour()
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
				Log.trace("ClashResolver", "Pierce roll: pen %.2f/%.2f vs arm %.2f/%.2f%s" % [roll_offence_pierce, try_pierce, roll_defence_pierce, pierce_def, " [magical]" if chosen_weapon.resource.is_magical else ""])
				if roll_defence_pierce >= roll_offence_pierce:
					Log.trace("ClashResolver", "✗ BLOCKED")
					updates.append(EntityUpdate.new(
						attacker.player_id,
						targeted.player_id,
						EntityChange.new(SquadBattleTypes.EntityChangeable.CLINK, -1, -1),
					))
					raise_window(SquadBattleTypes.ReactionWindow.ON_BLOCK, top)
				else:
					Log.trace("ClashResolver", "✓ PIERCE")
					raise_window(SquadBattleTypes.ReactionWindow.ON_PIERCE, top)
					if top.phase != ClashIntent.Phase.CANCELLED:
						# --- _apply_damage ---
						var skill_bonus := skill_level * 0.5
						var raw_damage = chosen_weapon.get_potency_array_damage(attacker)
						var base_dm = armour.get_raw_damage_taken(raw_damage) + skill_bonus
						var dm = base_dm * top.damage_multiplier + top.bonus_damage
						var hp_before = targeted.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
						var damage_updates = targeted.damage(dm, attacker.player_id)
						for update in damage_updates:
							updates.append(update)
						var hp_after = targeted.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
						Log.trace("ClashResolver", "→ Dealt %.2f to %s — HP %.1f→%.1f" % [dm, targeted.display_name, hp_before, hp_after])
						if hp_after <= 0:
							raise_window(SquadBattleTypes.ReactionWindow.ON_KILL, top)
						raise_window(SquadBattleTypes.ReactionWindow.ON_DAMAGED, top)
		else:
			raise_window(SquadBattleTypes.ReactionWindow.ON_DAMAGED, top)

		top.phase = ClashIntent.Phase.COMMITTED
		_stack.erase(top)

	return updates


func raise_window(window: SquadBattleTypes.ReactionWindow, intent: ClashIntent) -> void:
	intent._window = window
	_gather(window, intent)


func _build_squad_data(entity: CombatEntity) -> Dictionary:
	var our: Dictionary = {}
	var enemy: Dictionary = {}
	for e in _all_entities:
		if e.is_dead():
			continue
		var loc = e.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
		if e.side == entity.side:
			if not our.has(loc):
				our[loc] = []
			our[loc].append(e)
		else:
			if not enemy.has(loc):
				enemy[loc] = []
			enemy[loc].append(e)
	return {"our": our, "enemy": enemy}


func _gather(window: SquadBattleTypes.ReactionWindow, intent: ClashIntent) -> void:
	if intent.depth >= MAX_DEPTH:
		Log.warn("ClashResolver", "MAX_DEPTH reached (%d), skipping gather" % MAX_DEPTH)
		return

	var candidates: Array[Dictionary] = []
	for entity in _all_entities:
		if entity.is_dead():
			continue
		for reaction in entity.reactions:
			if reaction.once_per_round:
				var latch_key := "%d:%s" % [entity.player_id, reaction.reaction_name]
				if _latch.has(latch_key):
					continue
			var budget_used: int = _budget.get(entity.player_id, 0)
			if budget_used >= _reaction_budget:
				continue
			var squads := _build_squad_data(entity)
			var situation := Situation.new({"entity": entity, "our_squad": squads["our"], "enemy_squad": squads["enemy"]})
			if reaction.can_react(window, intent, entity, situation):
				candidates.append({"entity": entity, "reaction": reaction})

	candidates.sort_custom(func(a, b): return a["reaction"].priority > b["reaction"].priority)

	for c in candidates:
		var entity: CombatEntity = c["entity"]
		var reaction: ReactionSkill = c["reaction"]

		if reaction.once_per_round:
			var latch_key := "%d:%s" % [entity.player_id, reaction.reaction_name]
			_latch[latch_key] = true
		_budget[entity.player_id] = _budget.get(entity.player_id, 0) + 1

		if reaction.effect != null:
			reaction.effect.apply(intent, entity)
			updates.append(EntityUpdate.new(
				entity.player_id,
				intent.target.player_id,
				EntityChange.new(SquadBattleTypes.EntityChangeable.PROC, -1, -1, intent.metadata()),
			))
			if intent.phase == ClashIntent.Phase.CANCELLED:
				return

		if reaction.skill != null:
			var child_target := intent.target
			if reaction.skill.targeting_consideration != null:
				var squads := _build_squad_data(entity)
				var sit := Situation.new({"entity": entity, "our_squad": squads["our"], "enemy_squad": squads["enemy"]})
				var found = reaction.skill.targeting_consideration.score_then_return(entity, sit, intent.context)
				if found is CombatEntity:
					child_target = found
			var child := ClashIntent.new(entity, reaction.skill.duplicate(), child_target, intent.depth + 1, intent, intent.situation, intent.context)
			_stack.append(child)


func _get_skill_level(attacker: CombatEntity) -> float:
	if attacker.skill_set == null:
		return 0.0
	var skill_type := WeaponFactory.get_skill_used(attacker.weapon.resource.weapon_class)
	return float(attacker.skill_set.get_level(skill_type))
