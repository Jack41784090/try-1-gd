class_name StrategicAITypes extends RefCounted

enum GlanceSubject {
	SQUAD,
	LOCATION,
	WORLD,
	FACTION,
}

enum SquadGlanceable {
	FOOD,
	MONEY,
	MORALE,
	WARRIOR_COUNT,
	KARMA,
	TRAVEL_TOOLS,
}

enum LocationGlanceable {
	STABILITY,
	DEVELOPMENT,
	ENEMY_COUNT,
	ACTIVE_CLUE_COUNT,
	HAS_ACTIVITY,
	TYPE,
}

enum WorldGlanceable {
	TURN_COUNT,
	ADJACENT_ENEMY_COUNT,
	NEAREST_ENEMY_DISTANCE,
	NEAREST_TOWN_DISTANCE,
}

enum FactionGlanceable {
	REPUTATION,
	ARMY_COUNT,
}

enum DestinationStrategy {
	NEAREST_TOWN,
	NEAREST_ENEMY,
	CLUE_DESTINATION,
	DIRECTIVE_LOCATION,
}

enum TargetStrategy {
	WEAKEST,
	STRONGEST,
	RANDOM,
}

enum DirectiveType {
	NONE,
	ATTACK_LOCATION,
	DEFEND_LOCATION,
	RETREAT,
}
