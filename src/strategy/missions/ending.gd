extends Resource
class_name Ending

@export var ending_id: String = ""
@export var ending_name: String = ""
@export var description: String = ""
@export var conditions: Array[TriggerCondition] = []
@export var narrative_text: String = ""
@export var epilogue_scene_paths: Array[String] = []

func check_conditions(context: Dictionary) -> bool:
	for condition in conditions:
		if not condition.evaluate(context):
			return false
	return true

func trigger() -> Dictionary:
	return {
		"ending_id": ending_id,
		"ending_name": ending_name,
		"description": description,
		"narrative_text": narrative_text,
		"epilogue_scene_paths": epilogue_scene_paths
	}

