class_name SkillEffectSplash extends SkillEffect

@export var splash_damage_ratio: float = 0.5

func apply(intent: ClashIntent, actor: CombatEntity) -> Array[EntityUpdate]:
	var updates: Array[EntityUpdate] = []
	if not situation or not source or not affected:
		return updates

	var target_loc = affected.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
	var enemies_at_loc = situation.get_enemies_at(target_loc)

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
			updates.append(
				EntityUpdate.new(source.player_id, enemy.player_id,
					EntityChange.new(SquadBattleTypes.EntityChangeable.CLINK, -1, -1)))
			continue

		var raw_damage = source.weapon.get_potency_array_damage(source)
		var dm = armour.get_raw_damage_taken(raw_damage) * splash_damage_ratio

		var damage_updates = enemy.damage(dm, source.player_id)
		for u in damage_updates:
			updates.append(u)

	return updates
