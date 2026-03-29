class_name InvestigateHandler
extends ActivityHandler


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var squad = context.get("squad") as SquadData
	var world = context.get("world") as World
	var location = world.get_location_by_id(squad.current_location_id)

	if not location:
		return result

	var clues_found = randf() * 5
	result.clues_left += clues_found

	return result
