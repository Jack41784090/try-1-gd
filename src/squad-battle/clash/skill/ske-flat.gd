class_name SkillEffectFlat extends SkillEffect

@export var value: float
@export var property_direct: SquadBattleTypes.EntityChangeable;

func commit(_data = null) -> Array[EntityUpdate]:
	if stacks == 0:
		for t in triggers:
			StatusEffectEventBus.Disconnect(t, commit)
	else:
		stacks -= 1
	
	if updates_collector != null:
		match property_direct:
			SquadBattleTypes.EntityChangeable.HP:
				if value > 0:
					var h = affected.heal(value)
					updates_collector.append(
						EntityUpdate.new(source.player_id, affected.player_id, h))
				else:
					var r = affected.damage(value, source.player_id)
					for u in r:
						updates_collector.append(u)
			_:
				var change = affected.mod_changeable_stat(property_direct, value)
				updates_collector.append(
					EntityUpdate.new(source.player_id, affected.player_id, change))
	
	print("  [effect] %s ✓" % _debug_id)
	return updates_collector
