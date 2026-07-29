class_name SkillEffectSplash extends SkillEffect

@export var splash_damage_ratio: float = 0.5

func commit(_data = null) -> Array[EntityUpdate]:
	for t in triggers:
		StatusEffectEventBus.Disconnect(t, commit)

	if not battle_context or not source or not affected:
		print("  [splash] %s — no context, skipped" % _debug_id)
		return []

	var target_loc = affected.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
	var enemies_at_loc = battle_context.get_enemies_at(target_loc)

	var splash_count = 0
	for enemy in enemies_at_loc:
		if enemy == affected:
			continue
		if enemy.is_dead():
			continue

		var armour = enemy.get_armour()
		var try_hit = source.weapon.get_magical_penetration_value(source)
		var hit_def = armour.get_magical_PV()
		var roll_offence = randf() * try_hit
		var roll_defence = randf() * hit_def

		if roll_defence >= roll_offence:
			print("  [splash] %s → %s BLOCKED (pen %.2f vs arm %.2f)" % [source.display_name, enemy.display_name, roll_offence, roll_defence])
			if updates_collector != null:
				updates_collector.append(
					EntityUpdate.new(source.player_id, enemy.player_id,
						EntityChange.new(SquadBattleTypes.EntityChangeable.CLINK, -1, -1)))
			continue

		var raw_damage = source.weapon.get_potency_array_damage(source)
		var dm = armour.get_raw_damage_taken(raw_damage) * splash_damage_ratio

		var hp_before = enemy.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
		var damage_updates = enemy.damage(dm, source.player_id)
		var hp_after = enemy.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)

		if updates_collector != null:
			for u in damage_updates:
				updates_collector.append(u)

		splash_count += 1
		print("  [splash] %s → %s dealt %.2f — HP %.1f→%.1f" % [source.display_name, enemy.display_name, dm, hp_before, hp_after])

	print("  [splash] %s hit %d extra targets" % [_debug_id, splash_count])
	return updates_collector if updates_collector else []
