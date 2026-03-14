class_name CaravanBrain
extends RefCounted

var squad: SquadStrategicData
var _config: SquadBrainConfig


func _init(p_squad: SquadStrategicData, p_config: SquadBrainConfig) -> void:
	assert(p_squad != null, "CaravanBrain requires a squad")
	assert(p_squad.is_caravan(), "CaravanBrain requires a merchant squad")
	squad = p_squad
	_config = p_config


func decide(world: World, _faction: Variant = null, _directive: Variant = null) -> Dictionary:
	if squad.cargo_destination_id.is_empty():
		Log.warn("CaravanBrain", "%s has no destination" % squad.squad_name)
		return {"activity_type": StrategyTypes.ActivityType.REST, "context": {}}

	if squad.current_location_id == squad.cargo_destination_id:
		return {"activity_type": StrategyTypes.ActivityType.REST, "context": {}}

	var next_hop := _get_next_hop(world)
	if next_hop.is_empty():
		Log.warn("CaravanBrain", "%s cannot find path to %s" % [squad.squad_name, squad.cargo_destination_id])
		return {"activity_type": StrategyTypes.ActivityType.REST, "context": {}}

	Log.debug("CaravanBrain", "%s travelling: %s → %s (dest: %s)" % [
		squad.squad_name, squad.current_location_id, next_hop, squad.cargo_destination_id,
	])
	return {
		"activity_type": StrategyTypes.ActivityType.TRAVEL,
		"context": {"travel_destination": next_hop},
	}


func _get_next_hop(world: World) -> String:
	var current_loc := world.get_location_by_id(squad.current_location_id)
	if current_loc == null:
		return ""
	if current_loc.is_connected_to(squad.cargo_destination_id):
		return squad.cargo_destination_id
	var path := world.travel_graph.find_path(squad.current_location_id, squad.cargo_destination_id)
	if path.size() > 1:
		return path[1]
	return ""
