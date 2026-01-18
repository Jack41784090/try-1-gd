class_name  WarriorFactory

static func create_warrior(id: String, name: String, religion: StrategyTypes.Religion, combat_stats: EntityBaseStats) -> Warrior:
    var warrior = Warrior.new()
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