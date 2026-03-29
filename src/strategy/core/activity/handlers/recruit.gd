class_name RecruitHandler
extends ActivityHandler


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var world = context.get("world") as World

	var recruited_entity = EntityFactory.get_entity(EntityClasses.Types.Landsknecht)
	var class_id = recruited_entity.class_id

	var new_warrior = WarriorFactory.create_warrior(
		class_id,
		EntityClasses.Types.keys()[class_id],
		recruited_entity.entity_name,
		StrategyTypes.Religion.CATHOLIC,
		EntityBaseStats.new(),
	)
	new_warrior.name = "Recruit_%d" % world.turn_count

	Log.info("RecruitHandler", "Recruited new warrior: %s" % new_warrior.name)
	result.append_new_recruits([new_warrior])

	return result
