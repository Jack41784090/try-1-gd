class_name MissionResult extends GenericResult

var mission_id: String
var unlocked_missions: Array[String] = []
var narrative_text: String = ""
var reputation_changes: Dictionary = {}

func _init(p_mission_id: String = "") -> void:
    mission_id = p_mission_id

func has_event_chain() -> bool:
    return not event_chain_path.is_empty()

func modify_faction_reputation(faction_id: String, amount: float) -> void:
    reputation_changes[faction_id] = reputation_changes.get(faction_id, 0.0) + amount

func trigger_event(_event_id: String) -> void:
    pass