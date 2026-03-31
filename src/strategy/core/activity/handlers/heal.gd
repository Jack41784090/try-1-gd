class_name HealHandler
extends ActivityHandler


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var squad = context.get("squad") as SquadData
	var world = context.get("world") as World
	var location = world.get_location_by_id(squad.current_location_id)

	if not location:
		return result

	var cost_per_warrior := 10.0
	var healed_count := 0

	for warrior in squad.warriors:
		if warrior.is_injured and not warrior.is_dead:
			if squad.money >= cost_per_warrior:
				squad.spend_money(cost_per_warrior)
				warrior.is_injured = false
				healed_count += 1

	if healed_count > 0:
		StrategyEventBus.squad_resource_changed.emit("money", squad.money)
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, 10.0)
		Log.info("HealHandler", "HEAL at %s: healed %d warriors for %.0f gold (morale +10)" % [
			location.location_name,
			healed_count,
			healed_count * cost_per_warrior,
		])
	else:
		Log.info("HealHandler", "HEAL at %s: no warriors to heal or not enough money" % location.location_name)

	return result
