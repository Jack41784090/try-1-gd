class_name SkillEffectConsider extends SkillEffect

@export var value_consideration: Consideration = null
@export var property_direct: SquadBattleTypes.EntityChangeable;

func commit(_data = null) -> Array[EntityUpdate]:
	var updates: Array[EntityUpdate] = []
	
	for t in triggers:
		StatusEffectEventBus.Disconnect(t, commit)
	
	if updates_collector:
		for u in updates:
			updates_collector.append(u)
	
	print("  [effect] %s ✓" % name)
	return updates
