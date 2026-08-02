extends RefCounted
class_name SquadBattleTypes

enum WeaponClasses {
	Unarmed,
	Flammenschwert,
	Crossbow,
	Arquebus,
	Pike,
	Mace,
	AlchemicalFire,
}

enum ArmorClasses {
	Unarmored,
	LeatherArmor,
	PaddedArmor,
	HalfPlate,
}

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

enum ReactionWindow {
	ON_CAST,
	ON_HIT,
	ON_DODGE,
	ON_PIERCE,
	ON_BLOCK,
	ON_DAMAGED,
	ON_HEAL,
	ON_KILL,
	ON_DEATH,
	ON_RETREAT,
	ON_CAPITULATE,
	ON_ROUND_START,
	ON_ROUND_END,
}
