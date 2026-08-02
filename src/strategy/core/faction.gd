extends Resource
class_name Faction

@export var faction_id: String = ""
@export var faction_name: String = ""
@export var description: String = ""
@export var leader_squad_id: String = ""
@export var missions: Array[Mission] = []
@export var reputation: float = 0.0
var armies: Array[StrategySquad] = []

func get_completed_mission_ids() -> Array[String]:
	var completed_ids: Array[String] = []
	for mission in missions:
		if mission.is_completed:
			completed_ids.append(mission.mission_id)
	return completed_ids

func get_reputation() -> float:
	return reputation

func get_mission_by_id(mission_id: String) -> Mission:
	for mission in missions:
		if mission.mission_id == mission_id:
			return mission
	return null

func check_mission_completions(context: Dictionary) -> Array[MissionResult]:
	var results: Array[MissionResult] = []

	for mission in missions:
		if mission.check_completion(context):
			var result = mission.complete()
			results.append(result)

			for unlocked_id in result.unlocked_missions:
				var unlocked_mission = get_mission_by_id(unlocked_id)
				if unlocked_mission:
					unlocked_mission.unlock()

	return results

func get_armies_at_location(location_id: String) -> Array[StrategySquad]:
	var armies_at_loc: Array[StrategySquad] = []
	for army in armies:
		if army.current_location_id == location_id:
			armies_at_loc.append(army)
	return armies_at_loc

func add_army(squad: StrategySquad) -> void:
	armies.append(squad)

func remove_army(squad_id: String) -> void:
	for i in range(armies.size() - 1, -1, -1):
		if armies[i].squad_id == squad_id:
			armies.remove_at(i)
			break

func get_army_by_id(squad_id: String) -> StrategySquad:
	for army in armies:
		if army.squad_id == squad_id:
			return army
	return null
