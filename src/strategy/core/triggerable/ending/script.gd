extends Triggerable
class_name Ending

@export var ending_id: String = ""
@export var ending_name: String = ""
@export var narrative_text: String = ""
@export var epilogue_scene_paths: Array[String] = []

func _init() -> void:
	super._init()

func trigger(_context: Dictionary) -> Array[EndingResult]:
	trigger_id = ending_id
	trigger_name = ending_name
	
	
	var ending_result = EndingResult.new({
		"ending_id": ending_id,
		"ending_name": ending_name,
		"description": description,
		"narrative_text": narrative_text,
		"epilogue_scene_paths": epilogue_scene_paths,
		"requires_async": epilogue_scene_paths.size() > 0
	})
	
	
	return [ending_result]

func execute(_context: Dictionary) -> Array[EndingResult]:
	return trigger(_context)
