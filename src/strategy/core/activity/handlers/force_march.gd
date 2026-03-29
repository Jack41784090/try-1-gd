class_name ForceMarchHandler
extends ActivityHandler


func can_execute(activity, squad: SquadData, location: Location) -> bool:
	if activity.destination_id.is_empty():
		return false
	if not location.is_connected_to(activity.destination_id):
		return false
	var total_demand := 0.0
	for w in squad.get_living_warriors():
		var demand = w.get_demand()
		total_demand += demand.get(StrategyTypes.SquadProperty.FOOD_SUPPLIES, 0.0)
	var food_cost = int(ceil(total_demand * activity.force_march_supply_multiplier))
	return squad.food >= food_cost


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var world = context.get("world") as World
	var squad = context.get("squad") as SquadData
	var activity = context.get("activity")

	squad.consume_supplies_by_demand(activity.force_march_supply_multiplier)
	squad.apply_travel_morale_penalty(-4.0)

	squad.set_location(activity.destination_id)
	var final_location = activity.destination_id

	if not activity.ultimate_destination_id.is_empty() and activity.ultimate_destination_id != activity.destination_id:
		var current_loc = world.get_location_by_id(activity.destination_id)
		if current_loc and squad.food > 0:
			var path = world.travel_graph.find_path(activity.destination_id, activity.ultimate_destination_id)
			if path.size() > 1:
				var second_hop = path[1]
				squad.consume_supplies_by_demand(activity.force_march_supply_multiplier)
				squad.set_location(second_hop)
				final_location = second_hop
				Log.info("ForceMarchHandler", "Double-hop: %s → %s → %s" % [
					squad.squad_name, activity.destination_id, second_hop])

	result.location_changed = final_location
	result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -10.0)

	var enemies_at_destination = world.get_squads_at_location(final_location)
	if not enemies_at_destination.is_empty():
		var target_enemy = enemies_at_destination[0]
		result.requires_combat = true
		result.combat_target_squad_id = target_enemy.squad_id
		result.requires_async = true

	return result
