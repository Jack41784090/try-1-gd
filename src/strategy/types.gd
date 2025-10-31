extends RefCounted
class_name StrategyTypes

enum LocationType {
	CITY,
	TOWN,
	VILLAGE,
	FORT,
	ROAD
}

enum Religion {
	CATHOLIC,
	MUSLIM,
	SAVINKOVIST,
	PROTESTANT,
	PAGAN,
	BUDDHIST,
	TENGRIST
}

enum ActivityType {
	REST,
	DRILL,
	TRAVEL,
	PATROL,
	INVESTIGATE,
	HOLD_MASS,
	MERCENARY_WORK,
	FORAGE,
	CUSTOM
}

enum TriggerWhen {
	BEFORE_ACTIVITY,
	AFTER_ACTIVITY
}

enum LogicalOperator {
	AND,
	OR
}

enum GlobalModifier {
	METAL,
	WOOD,
	WATER,
	FIRE,
	EARTH
}

enum WarriorAttribute {
	DIPLOMACY,
	SURVIVAL,
	PERCEPTION,
	LEADERSHIP,
	STEALTH
}

class ActivityResult:
	var squad_stat_changes: Dictionary = {}
	var world_stat_changes: Dictionary = {}
	var narrative_log: Array[String] = []
	var triggered_event_ids: Array[String] = []
	var combat_initiated: bool = false
	var location_changed: String = ""
	
	func add_narrative(text: String) -> void:
		narrative_log.append(text)
	
	func trigger_event(event_id: String) -> void:
		triggered_event_ids.append(event_id)
	
	func modify_squad_stat(stat_name: String, value: float) -> void:
		squad_stat_changes[stat_name] = squad_stat_changes.get(stat_name, 0.0) + value
	
	func modify_world_stat(stat_name: String, value: float) -> void:
		world_stat_changes[stat_name] = world_stat_changes.get(stat_name, 0.0) + value

class EventChoice:
	var choice_id: String
	var choice_text: String
	var conditions: Array = []
	var effects: Dictionary = {}
	
	func _init(p_id: String = "", p_text: String = "") -> void:
		choice_id = p_id
		choice_text = p_text
	
	func is_available(context: Dictionary) -> bool:
		for condition in conditions:
			if not condition.evaluate(context):
				return false
		return true

class EventResult:
	var choices: Array[EventChoice] = []
	var immediate_effects: Dictionary = {}
	var narrative_text: String = ""
	var dialogue_scene_path: String = ""
	var auto_resolved: bool = true
	
	func add_choice(choice: EventChoice) -> void:
		choices.append(choice)
		auto_resolved = false

class TriggerContext:
	var squad: Resource
	var world: Resource
	var activity: Resource
	var location: Resource
	var turn: int = 0
	var completed_missions: Array[String] = []
	
	func _init(p_squad: Resource = null, p_world: Resource = null) -> void:
		squad = p_squad
		world = p_world
	
	func to_dict() -> Dictionary:
		return {
			"squad": squad,
			"world": world,
			"activity": activity,
			"location": location,
			"turn": turn,
			"completed_missions": completed_missions
		}

class MissionResult:
	var mission_id: String
	var unlocked_missions: Array[String] = []
	var reputation_changes: Dictionary = {}
	var narrative_text: String = ""
	
	func _init(p_mission_id: String = "") -> void:
		mission_id = p_mission_id

