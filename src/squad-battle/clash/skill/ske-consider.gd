class_name SkillEffectConsider extends SkillEffect

@export var value_consideration: Consideration = null
@export var property_direct: SquadBattleTypes.EntityChangeable;

func commit(_data = null) -> Array[EntityUpdate]:
	print("    [SkillEffect-Consideration] Committing '%s'" % name)
	
	var updates: Array[EntityUpdate] = []
	
	for t in triggers:
		StatusEffectEventBus.Disconnect(t, commit)
	
	if updates_collector:
		for u in updates:
			updates_collector.append(u)
		print("    [SkillEffect] Added %d updates to collector" % updates.size())
	
	print("    [SkillEffect] Commit complete ")
	
	return updates
