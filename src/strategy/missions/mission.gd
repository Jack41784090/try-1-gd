extends Resource
class_name Mission

@export var mission_id: String = ""
@export var mission_name: String = ""
@export var description: String = ""
@export var prerequisite_mission_ids: Array[String] = []
@export var postrequisite_mission_ids: Array[String] = []
@export var finish_conditions: Array[TriggerCondition] = []
@export var is_completed: bool = false
@export var is_unlocked: bool = false
@export var is_failed: bool = false

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

func check_completion(context: Dictionary) -> bool:
	if is_completed or is_failed or not is_unlocked:
		return false
	
	for condition in finish_conditions:
		if not condition.evaluate(context):
			return false
	
	return true

func complete() -> StrategyTypes.MissionResult:
	is_completed = true
	is_unlocked = false
	
	var result = StrategyTypes.MissionResult.new(mission_id)
	result.unlocked_missions = postrequisite_mission_ids.duplicate()
	result.narrative_text = "Mission '%s' completed!" % mission_name
	
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

func add_finish_condition(condition: TriggerCondition) -> void:
	finish_conditions.append(condition)

