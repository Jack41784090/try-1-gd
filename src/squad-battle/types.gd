extends RefCounted
class_name SquadBattleTypes

enum Reality {
	HP,
	Force,
	Mana,
	Spirituality,
	Divinity,
	Precision,
	Maneuver,
	Convince,
	Bravery,
	Guts
}

enum Potency {
	Strike,
	Slash,
	Stab,
	TheWay,
	Light,
	Dark,
	Arcane
}

enum DamageType {
	Physical,
	Cut,
	Impale,
	Magic
}

enum SquadEntityInSquadLocation {
	Front = 1,
	Middle = 2,
	Back = 3
}

enum EntityChangeable {
	HP,
	STA,
	ORG,
	POS,
	MAG,
	LOC,

	DIE,
	CAPITULATE,
	CLINK,
	DODGE,
	PROC
}

enum SquadEntityAction {
	ATTACK,
	FORWARD,
	HEAL,
	IDLE,
	RETREAT,
	CAPITULATE
}

enum Side {
	NULL,
	ATTACKER,
	DEFENDER
}

enum BattleOutcome {
	ONGOING,
	ATTACKER_VICTORY,
	DEFENDER_VICTORY,
	DRAW
}


# class WeaponConfig:
# 	var hit_bonus: float
# 	var penetration_bonus: float
# 	var damage_translation: Dictionary = {}
# 	var weapon_range: Dictionary = {}
	
# 	func _init(p_hit_bonus: float = 0, p_penetration_bonus: float = 0):
# 		hit_bonus = p_hit_bonus
# 		penetration_bonus = p_penetration_bonus

class ArmourConfig:
	var DV: float
	var PV: float
	var resistance: Dictionary = {}
	
	func _init(p_DV: float = 12, p_PV: float = 0):
		DV = p_DV
		PV = p_PV
