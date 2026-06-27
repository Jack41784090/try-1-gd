class_name RecruitHandler
extends ActivityHandler


func execute(_context: Dictionary, result: ActivityResult) -> ActivityResult:
	# DISABLED: recruitment needs the StrategyEntity runtime-build bridge
	# (StrategyEntityFactory) which does not exist during the StrategyEntity rewrite.
	# var world = context.get("world") as World
	# var identification := "landsknecht"
	# var new_warrior = StrategyEntityFactory.Create(
	# 	identification,
	# 	identification,
	# 	identification.capitalize(),
	# 	StrategyTypes.Religion.CATHOLIC,
	# 	CombatEntityBaseStats.new(),
	# )
	# new_warrior.name = "Recruit_%d" % world.current_hour
	# Log.info("RecruitHandler", "Recruited new warrior: %s" % new_warrior.name)
	# result.append_new_recruits([new_warrior])

	return result
