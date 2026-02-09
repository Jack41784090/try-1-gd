class_name SkillEffectFlat extends SkillEffect

@export var value: float
@export var property_direct: SquadBattleTypes.EntityChangeable;

# func _init(
# 	_name: String = '',
# 	_source: CharacterCombatStats = null,
# 	_affected: CharacterCombatStats = null,
# 	# _targeting: Targeting = Targeting.SENTINEL,
# 	_commitType: ClashCommonTypes.CommitType = ClashCommonTypes.CommitType.ApplyStatusEffect,
# 	_triggers: Array[StatusEffectEventBus.Signals] = [],
# 	_additional_data: Dictionary = {}
# ) -> void:
# 	# super._init(_name, _source, _affected, _commitType, _triggers, _additional_data)
# 	_debug_id = "[%s-%s]" % [self.get_class(), name]

func commit(_data = null) -> Array[EntityUpdate]:
	print("%s Committing" % _debug_id)
	
	if stacks == 0:
		for t in triggers:
			StatusEffectEventBus.Disconnect(t, commit)
	else:
		stacks -= 1
	
	if updates_collector != null:
		match SquadBattleTypes.EntityChangeable:
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
	
	print("%s Commit complete" % _debug_id)
	
	return updates_collector
