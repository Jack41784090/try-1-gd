class_name TravelHandler
extends ActivityHandler


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var squad = context.get("squad") as SquadData

	var consumed = squad.consume_supplies_by_demand()
	if not consumed:
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)

	squad.apply_travel_morale_penalty(-2.0)

	if not result.location_changed.is_empty():
		squad.set_location(result.location_changed)

	return result
