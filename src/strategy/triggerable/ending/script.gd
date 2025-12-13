extends Triggerable
class_name Ending

@export var ending_id: String = ""
@export var ending_name: String = ""
@export var narrative_text: String = ""
@export var epilogue_scene_paths: Array[String] = []

func _init() -> void:
	super._init()

func trigger() -> EndingResult:
	trigger_id = ending_id
	trigger_name = ending_name
	
	execution_started.emit()
	
	var ending_result = EndingResult.new({
		"ending_id": ending_id,
		"ending_name": ending_name,
		"description": description,
		"narrative_text": narrative_text,
		"epilogue_scene_paths": epilogue_scene_paths,
		"requires_async": epilogue_scene_paths.size() > 0
	})
	
	triggered.emit(ending_result)
	
	if epilogue_scene_paths.size() == 0:
		execution_completed.emit(ending_result)
	
	return ending_result

func execute(_squad: StrategicSquad, _world: World) -> EndingResult:
	return trigger()
