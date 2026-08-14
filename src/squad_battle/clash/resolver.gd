class_name ClashResolver
extends RefCounted

const MAX_DEPTH: int = 8

signal window_raised(intent, window: int)

var updates: Array[EntityUpdate] = []
var _stack: Array[ClashIntent] = []
var _all_entities: Array[CombatEntity] = []


func set_entities(entities: Array[CombatEntity]) -> void:
	_all_entities = entities
	_subscribe_all_reactions()


func resolve(root: ClashIntent) -> Array[EntityUpdate]:
	updates = []
	_stack = [root]

	while not _stack.is_empty():
		var top: ClashIntent = _stack.back()
		if top.phase == ClashIntent.Phase.PROPOSED:
			top.phase = ClashIntent.Phase.GATHERED
			raise_window(SquadBattleTypes.ReactionWindow.ON_CAST, top)
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
		skill.context = top.situation.context if top.situation else {}
		skill.target = targeted
		for e in skill.effects:
			e.set_attacker_and_target(attacker, targeted, top.situation)

		var is_self_cast := attacker.player_id == targeted.player_id
		if is_self_cast:
			MyLog.debug("ClashResolver", "[%d]%s ‹%s› on self" % [attacker.player_id, attacker.display_name, skill.name if skill else "?"])
		else:
			MyLog.debug("ClashResolver", "[%d]%s → [%d]%s | ‹%s›" % [attacker.player_id, attacker.display_name, targeted.player_id, targeted.display_name, skill.name if skill else "?"])

		if skill.sta_cost > 0.0:
			updates.append(EntityUpdate.new(
				attacker.player_id, attacker.player_id,
				attacker.mod_changeable_stat(SquadBattleTypes.EntityChangeable.STA, -skill.sta_cost)))
		execute_effects(skill.effects.filter(func(e): return e.window == SquadBattleTypes.ReactionWindow.ON_CAST), top, attacker)

		if skill.roll_for_damage:
			# --- _roll_for_hit ---
			var chosen_weapon = attacker.weapon
			var try_hit = chosen_weapon.get_total_hit_value(attacker)
			var skill_level := _get_skill_level(attacker)
			try_hit += skill_level * 2.0
			var hit_def = targeted.calculate_reality_value(SquadBattleTypes.Reality.Maneuver)
			var roll_offence_hit = randf() * try_hit
			var roll_defence_hit = randf() * hit_def
			MyLog.trace("ClashResolver", "Hit roll: %s vs %s — attacker %.2f / weapon base %.2f, defender evasion %.2f" % [attacker.display_name, targeted.display_name, roll_offence_hit, try_hit, roll_defence_hit])
			if roll_defence_hit >= roll_offence_hit:
				MyLog.trace("ClashResolver", "✗ DODGED")
				updates.append(EntityUpdate.new(
					attacker.player_id,
					targeted.player_id,
					EntityChange.new(SquadBattleTypes.EntityChangeable.DODGE, -1, -1),
				))
				raise_window(SquadBattleTypes.ReactionWindow.ON_DODGE, top)
				execute_effects(skill.effects.filter(func(e): return e.window == SquadBattleTypes.ReactionWindow.ON_DODGE), top, attacker)
			else:
				raise_window(SquadBattleTypes.ReactionWindow.ON_HIT, top)
				execute_effects(skill.effects.filter(func(e): return e.window == SquadBattleTypes.ReactionWindow.ON_HIT), top, attacker)

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
				MyLog.trace("ClashResolver", "Pierce roll: pen %.2f/%.2f vs arm %.2f/%.2f%s" % [roll_offence_pierce, try_pierce, roll_defence_pierce, pierce_def, " [magical]" if chosen_weapon.resource.is_magical else ""])
				if roll_defence_pierce >= roll_offence_pierce:
					MyLog.trace("ClashResolver", "✗ BLOCKED")
					updates.append(EntityUpdate.new(
						attacker.player_id,
						targeted.player_id,
						EntityChange.new(SquadBattleTypes.EntityChangeable.CLINK, -1, -1),
					))
					raise_window(SquadBattleTypes.ReactionWindow.ON_BLOCK, top)
					execute_effects(skill.effects.filter(func(e): return e.window == SquadBattleTypes.ReactionWindow.ON_BLOCK), top, attacker)
				else:
					MyLog.trace("ClashResolver", "✓ PIERCE")
					raise_window(SquadBattleTypes.ReactionWindow.ON_PIERCE, top)
					execute_effects(skill.effects.filter(func(e): return e.window == SquadBattleTypes.ReactionWindow.ON_PIERCE), top, attacker)
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
						var org_after = targeted.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
						MyLog.trace("ClashResolver", "→ Dealt %.2f to %s — HP %.1f→%.1f" % [dm, targeted.display_name, hp_before, hp_after])
						if org_after <= 0:
							raise_window(SquadBattleTypes.ReactionWindow.ON_RETREAT, top)
							execute_effects(skill.effects.filter(func(e): return e.window == SquadBattleTypes.ReactionWindow.ON_RETREAT), top, attacker)
						if hp_after <= 0:
							raise_window(SquadBattleTypes.ReactionWindow.ON_KILL, top)
							execute_effects(skill.effects.filter(func(e): return e.window == SquadBattleTypes.ReactionWindow.ON_KILL), top, attacker)
						raise_window(SquadBattleTypes.ReactionWindow.ON_DAMAGED, top)
						execute_effects(skill.effects.filter(func(e): return e.window == SquadBattleTypes.ReactionWindow.ON_DAMAGED), top, attacker)
		else:
			raise_window(SquadBattleTypes.ReactionWindow.ON_DAMAGED, top)
			execute_effects(skill.effects.filter(func(e): return e.window == SquadBattleTypes.ReactionWindow.ON_DAMAGED), top, attacker)

		top.phase = ClashIntent.Phase.COMMITTED
		_stack.erase(top)

	return updates


func raise_window(window: SquadBattleTypes.ReactionWindow, intent: ClashIntent) -> void:
	intent._window = window
	if intent.depth >= MAX_DEPTH:
		return
	window_raised.emit(intent, window)


func reaction_allowed(owner: CombatEntity, reaction: ReactionSkill) -> bool:
	if reaction.remaining_activations <= 0:
		return false
	if owner.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.STA) < reaction.sta_cost:
		return false
	return true


func build_situation(owner: CombatEntity) -> Situation:
	var squads := _build_squad_data(owner)
	return Situation.new({"entity": owner, "our_squad": squads["our"], "enemy_squad": squads["enemy"]})


func execute_effects(effects: Array[SkillEffect], intent: ClashIntent, actor: CombatEntity) -> void:
	for effect in effects:
		var eu := effect.apply(intent, actor)
		for u in eu:
			updates.append(u)
		if intent.phase == ClashIntent.Phase.CANCELLED:
			break
	if not effects.is_empty():
		updates.append(EntityUpdate.new(
			actor.player_id, intent.target.player_id,
			EntityChange.new(SquadBattleTypes.EntityChangeable.PROC, -1, -1, intent.metadata())))


func apply_reaction(reaction: ReactionSkill, intent: ClashIntent, owner: CombatEntity) -> void:
	updates.append(EntityUpdate.new(
		owner.player_id,
		owner.player_id,
		owner.mod_changeable_stat(SquadBattleTypes.EntityChangeable.STA, -reaction.sta_cost),
	))
	reaction.remaining_activations -= 1

	execute_effects(reaction.effects, intent, owner)
	if intent.phase == ClashIntent.Phase.CANCELLED:
		_expire_if_spent(reaction, owner)
		return

	if reaction.skill != null:
		var child_target := intent.target
		if reaction.skill.targeting_consideration != null:
			var squads := _build_squad_data(owner)
			var sit := Situation.new({"entity": owner, "our_squad": squads["our"], "enemy_squad": squads["enemy"]})
			var found = reaction.skill.targeting_consideration.score_then_return(owner, sit, intent.situation.context if intent.situation else {})
			if found is CombatEntity:
				child_target = found
		var child := ClashIntent.new(owner, reaction.skill.duplicate(), child_target, intent.depth + 1, intent, intent.situation)
		child.reaction_source_name = reaction.reaction_name
		child.reaction_source_owner = owner.player_id
		_stack.append(child)

	_expire_if_spent(reaction, owner)


func _expire_if_spent(reaction: ReactionSkill, owner: CombatEntity) -> void:
	if reaction.remaining_activations <= 0:
		reaction.unsubscribe()
		owner.reactions.erase(reaction)


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


func has_ancestor_reaction(intent: ClashIntent, owner: CombatEntity, reaction_name: String) -> bool:
	var cur := intent.cause
	while cur != null:
		if cur.reaction_source_owner == owner.player_id and cur.reaction_source_name == reaction_name:
			return true
		cur = cur.cause
	return false


func _subscribe_all_reactions() -> void:
	var subs: Array[Dictionary] = []
	for entity in _all_entities:
		if not entity.is_dead():
			# default Retreat reaction
			for reaction in entity.reactions:
				subs.append({"reaction": reaction, "entity": entity})

	subs.sort_custom(func(a, b): return a["reaction"].priority > b["reaction"].priority)

	for sub in subs:
		sub["reaction"].subscribe_to(self, sub["entity"])


func _get_skill_level(attacker: CombatEntity) -> float:
	if attacker.skill_set == null:
		return 0.0
	var skill_type := WeaponFactory.get_skill_used(attacker.weapon.resource.weapon_class)
	return float(attacker.skill_set.get_level(skill_type))
