extends Resource
class_name Faction

@export var faction_id: String = ""
@export var faction_name: String = ""
@export var description: String = ""
@export var leader_squad_id: String = ""
@export var missions: Array[Mission] = []
@export var reputation: float = 0.0

func get_available_missions() -> Array[Mission]:
	var available: Array[Mission] = []
	for mission in missions:
		if mission.is_unlocked and not mission.is_completed and not mission.is_failed:
			available.append(mission)
	return available

func get_completed_mission_ids() -> Array[String]:
	var completed_ids: Array[String] = []
	for mission in missions:
		if mission.is_completed:
			completed_ids.append(mission.mission_id)
	return completed_ids

func update_mission_graph() -> Array[Mission]:
	var completed_ids = get_completed_mission_ids()
	var newly_unlocked: Array[Mission] = []
	
	for mission in missions:
		if mission.check_unlock(completed_ids):
			mission.unlock()
			newly_unlocked.append(mission)
	
	return newly_unlocked

func modify_reputation(amount: float) -> void:
	reputation = clamp(reputation + amount, -100.0, 100.0)

func get_reputation() -> float:
	return reputation

func get_mission_by_id(mission_id: String) -> Mission:
	for mission in missions:
		if mission.mission_id == mission_id:
			return mission
	return null

func add_mission(mission: Mission) -> void:
	missions.append(mission)

func check_mission_completions(context: Dictionary) -> Array[Mission]:
	var completed: Array[Mission] = []
	
	for mission in missions:
		if mission.check_completion(context):
			var result = mission.complete()
			completed.append(mission)
			
			for unlocked_id in result.unlocked_missions:
				var unlocked_mission = get_mission_by_id(unlocked_id)
				if unlocked_mission:
					unlocked_mission.unlock()
	
	return completed

