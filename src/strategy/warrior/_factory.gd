class_name WarriorFactory

static func create_warrior(class_id: EntityClasses.Types, id: String, name: String, religion: StrategyTypes.Religion, combat_stats: EntityBaseStats) -> CharacterSocialStats:
	var warrior = CharacterSocialStats.new()
	warrior.class_id = class_id
	warrior.id = id
	warrior.name = name
	warrior.religion = religion
	warrior.combat_stats = combat_stats
	warrior.morale = 100.0
	warrior.attributes = {
		"diplomacy": 50,
		"survival": 50,
		"perception": 50,
		"leadership": 50,
		"stealth": 50
	}
	return warrior
