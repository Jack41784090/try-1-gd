class_name PatrolHandler
extends ActivityHandler


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var squad = context.get("squad") as StrategySquad
	var world = context.get("world") as World
	var tracker = world.contact_tracker

	var contacts_for = tracker.get_contacts_for(squad.squad_id)
	var detected_count := 0
	for c in contacts_for:
		if c.get_state() >= StrategyTypes.ContactState.SUSPECTED:
			detected_count += 1

	result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, 2.0)
	Log.info("PatrolHandler", "PATROL: detected %d contacts, morale +2" % detected_count)

	return result
