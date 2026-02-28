extends RefCounted

class_name StrategyTypes

enum LocationType {
	CITY,
	TOWN,
	VILLAGE,
	FORT,
	ROAD,
}

enum Religion {
	ATHEIST,
	CATHOLIC,
	MUSLIM,
	SAVINKOVIST,
	PROTESTANT,
	PAGAN,
	BUDDHIST,
	TENGRIST,
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
	ATTACK,
	FORCE_MARCH,
	MANAGE_SQUAD,
	RECRUIT,
	CUSTOM,
	HEAL,
	BUY_SUPPLIES,
}

enum TriggerWhen {
	BEFORE_ACTIVITY,
	AFTER_ACTIVITY,
	GAME_START,
	TURN_START,
}

enum LogicalOperator {
	AND,
	OR,
}

enum GlobalModifier {
	END,
	METAL,
	WOOD,
	WATER,
	FIRE,
	EARTH,
}

enum WarriorAttribute {
	DIPLOMACY,
	SURVIVAL,
	PERCEPTION,
	LEADERSHIP,
	STEALTH,
}


class EventChoice:
	var choice_id: String
	var choice_text: String
	var conditions: Array = []
	var effects: Dictionary = { }


	func _init(p_id: String = "", p_text: String = "") -> void:
		choice_id = p_id
		choice_text = p_text


	func is_available(context: Dictionary) -> bool:
		for condition in conditions:
			if not condition.evaluate(context):
				return false
		return true


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
			"completed_missions": completed_missions,
		}


enum SquadProperty {
	MONEY,
	HEALTH,
	FOOD_SUPPLIES,
	AMMO_SUPPLIES,
	FUEL_SUPPLIES,
	MORALE,
	DISCIPLINE,
	EXPERIENCE,
}

enum ItemType {
	SUPPLY,
}

enum ContactState {
	NONE,
	SUSPECTED,
	TRACKED,
	LOCKED,
}

enum EngagementType {
	AMBUSH,
	SET_PIECE,
	MEETING,
	AVOIDANCE,
}

enum EngagementStance {
	ALWAYS_ENGAGE,
	ENGAGE_WHEN_CONFIRMED,
}

enum SocialClass {
	PEASANT,
	SOLDIER,
	MERCHANT,
	NOBLE,
	CLERGY,
}


static func get_social_class_food_demand(social_class: SocialClass) -> float:
	match social_class:
		SocialClass.PEASANT:
			return 0.5
		SocialClass.SOLDIER:
			return 1.0
		SocialClass.MERCHANT:
			return 0.75
		SocialClass.NOBLE:
			return 1.5
		SocialClass.CLERGY:
			return 0.75
		_:
			return 1.0
