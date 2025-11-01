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

class GenericResult:
	var squad_stat_changes: Dictionary = {}
	var world_stat_changes: Dictionary = {}
	var event_chain_path: String = ""
	var requires_async: bool

	pass


class ActivityResult extends  GenericResult:
	var triggered_event_ids: Array[String] = []
	var combat_initiated: bool = false
	var location_changed: String = ""
	
	func trigger_event(event_id: String) -> void:
		triggered_event_ids.append(event_id)
	
	func modify_squad_stat(stat_name: String, value: float) -> void:
		squad_stat_changes[stat_name] = squad_stat_changes.get(stat_name, 0.0) + value
	
	func modify_world_stat(stat_name: String, value: float) -> void:
		world_stat_changes[stat_name] = world_stat_changes.get(stat_name, 0.0) + value
	
	func has_event_chain() -> bool:
		return not event_chain_path.is_empty()

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

class EventResult extends GenericResult:
	var event_id: String;
	var event_name: String;
	var choices: Array[EventChoice] = []
	var immediate_effects: Dictionary = {}
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

class MissionResult extends GenericResult:
	var mission_id: String
	var unlocked_missions: Array[String] = []
	var reputation_changes: Dictionary = {}
	var triggered_event_ids: Array[String] = []
	
	func _init(p_mission_id: String = "") -> void:
		mission_id = p_mission_id
	
	func trigger_event(event_id: String) -> void:
		triggered_event_ids.append(event_id)
	
	func modify_squad_stat(stat_name: String, value: float) -> void:
		squad_stat_changes[stat_name] = squad_stat_changes.get(stat_name, 0.0) + value
	
	func modify_world_stat(stat_name: String, value: float) -> void:
		world_stat_changes[stat_name] = world_stat_changes.get(stat_name, 0.0) + value
	
	func modify_faction_reputation(faction_id: String, value: float) -> void:
		reputation_changes[faction_id] = reputation_changes.get(faction_id, 0.0) + value
	
	func has_event_chain() -> bool:
		return not event_chain_path.is_empty()

class EndingResult extends GenericResult:
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