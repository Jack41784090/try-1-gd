extends Triggerable
class_name Mission

@export var mission_id: String = ""
@export var mission_name: String = ""
@export var prerequisite_mission_ids: Array[String] = []
@export var postrequisite_mission_ids: Array[String] = []
@export var completion_effects: Dictionary = {}
@export var dialogue_scene_path: String = ""
@export var is_completed: bool = false
@export var is_unlocked: bool = false
@export var is_failed: bool = false

func _init() -> void:
	super._init()

func check_unlock(completed_mission_ids: Array[String]) -> bool:
	if is_unlocked or is_completed or is_failed:
		return false
	
	for prereq_id in prerequisite_mission_ids:
		if not prereq_id in completed_mission_ids:
			return false
	
	return true

func unlock() -> void:
	if not is_completed and not is_failed:
		is_unlocked = true

func can_trigger(context: Dictionary = {}) -> bool:
	if is_completed or is_failed or not is_unlocked:
		return false
	
	return super.can_trigger(context)

func check_completion(context: Dictionary) -> bool:
	return can_trigger(context) and check_conditions(context)

func trigger(context: Dictionary) -> Array[MissionResult]:
	trigger_id = mission_id
	trigger_name = mission_name
	
	execution_started.emit()
	var result = complete()
	
	var result_dict = {
		"mission_id": mission_id,
		"narrative_text": result.narrative_text,
		"requires_async": result.requires_async,
		"unlocked_missions": result.unlocked_missions,
		"reputation_changes": result.reputation_changes,
		"squad_stat_changes": result.squad_stat_changes,
		"world_stat_changes": result.world_stat_changes,
		# "-": result.-,
		"dialogue_scene_path": result.dialogue_scene_path
	}
	
	triggered.emit(result_dict)
	
	if not result.requires_async:
		execution_completed.emit(result_dict)
	
	return [result]

func execute(context: Dictionary) -> MissionResult:
	return complete()

func complete() -> MissionResult:
	is_completed = true
	is_unlocked = false
	
	var result = MissionResult.new(mission_id)
	result.unlocked_missions = postrequisite_mission_ids.duplicate()
	result.narrative_text = "Mission '%s' completed!" % mission_name
	
	if not dialogue_scene_path.is_empty():
		result.dialogue_scene_path = dialogue_scene_path
		result.requires_async = true
	
	for stat_name in completion_effects.get("squad_stats", {}):
		result.modify_squad_stat(stat_name, completion_effects["squad_stats"][stat_name])
	
	for stat_name in completion_effects.get("world_stats", {}):
		result.modify_world_stat(stat_name, completion_effects["world_stats"][stat_name])
	
	for faction_id in completion_effects.get("reputation", {}):
		result.modify_faction_reputation(faction_id, completion_effects["reputation"][faction_id])
	
	var triggered_events: Array = completion_effects.get("trigger_events", [])
	for event_id in triggered_events:
		result.trigger_event(event_id)
	
	return result

func fail() -> void:
	is_failed = true
	is_unlocked = false

func reset() -> void:
	is_completed = false
	is_unlocked = false
	is_failed = false

func set_prerequisites(mission_ids: Array[String]) -> void:
	prerequisite_mission_ids.clear()
	prerequisite_mission_ids.append_array(mission_ids)

func add_prerequisite(prereq_mission_id: String) -> void:
	if not prereq_mission_id in prerequisite_mission_ids:
		prerequisite_mission_ids.append(prereq_mission_id)

func set_postrequisites(mission_ids: Array[String]) -> void:
	postrequisite_mission_ids.clear()
	postrequisite_mission_ids.append_array(mission_ids)

func add_postrequisite(postreq_mission_id: String) -> void:
	if not postreq_mission_id in postrequisite_mission_ids:
		postrequisite_mission_ids.append(postreq_mission_id)

func set_completion_squad_effect(stat_name: String, value: float) -> void:
	if not completion_effects.has("squad_stats"):
		completion_effects["squad_stats"] = {}
	completion_effects["squad_stats"][stat_name] = value

func set_completion_world_effect(stat_name: String, value: float) -> void:
	if not completion_effects.has("world_stats"):
		completion_effects["world_stats"] = {}
	completion_effects["world_stats"][stat_name] = value

func set_completion_reputation_effect(faction_id: String, value: float) -> void:
	if not completion_effects.has("reputation"):
		completion_effects["reputation"] = {}
	completion_effects["reputation"][faction_id] = value

func add_completion_triggered_event(event_id: String) -> void:
	if not completion_effects.has("trigger_events"):
		completion_effects["trigger_events"] = []
	completion_effects["trigger_events"].append(event_id)
