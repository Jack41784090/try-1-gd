class_name EndingResult extends GenericResult

var ending_id: String;
var ending_name: String;
var description: String;

func _init(config: Dictionary) -> void:
    ending_id = config.get("ending_id"); assert(ending_id)
    ending_name = config.get("ending_name", "Unnamed Ending");
    description = config.get("description", "")
    # epilogue_scene_paths = config.get("epilogue_scene_paths", [] as Array[String])
    event_chain_path = config.get("event_chain_path", "")
    requires_async = config.get("requires_async")
    pass