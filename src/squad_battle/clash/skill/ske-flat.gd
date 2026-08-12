class_name SkillEffectFlat extends SkillEffect

@export var value: float
@export var property_direct: SquadBattleTypes.EntityChangeable;

func apply(intent: ClashIntent, actor: CombatEntity) -> Array[EntityUpdate]:
	var updates: Array[EntityUpdate] = []
	match property_direct:
		SquadBattleTypes.EntityChangeable.HP:
			if value > 0:
				var h = affected.heal(value)
				updates.append(EntityUpdate.new(source.player_id, affected.player_id, h))
			else:
				var r = affected.damage(value, source.player_id)
				for u in r:
					updates.append(u)
		_:
			var change = affected.mod_changeable_stat(property_direct, value)
			updates.append(EntityUpdate.new(source.player_id, affected.player_id, change))
	return updates
