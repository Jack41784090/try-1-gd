class_name MissionResult extends StrategyTypes.GenericResult

var mission_id: String
var unlocked_missions: Array[String] = []

func _init(p_mission_id: String = "") -> void:
    mission_id = p_mission_id

func has_event_chain() -> bool:
    return not event_chain_path.is_empty()