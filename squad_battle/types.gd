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
	LOC
}

enum SquadEntityAction {
	ATTACK,
	FORWARD,
	HEAL,
	IDLE,
	RETREAT,
	CAPITULATE
}

class EntityBaseStats:
	var id: String
	var strength: float
	var dex: float
	var acr: float
	var spd: float
	var siz: float
	var int_stat: float
	var spr: float
	var fai: float
	var cha: float
	var beu: float
	var wil: float
	var endurance: float
	
	func _init(p_id: String = "", p_str: float = 10, p_dex: float = 10, p_acr: float = 10,
			p_spd: float = 10, p_siz: float = 10, p_int: float = 10, p_spr: float = 10,
			p_fai: float = 10, p_cha: float = 10, p_beu: float = 10, p_wil: float = 10,
			p_end: float = 10):
		id = p_id
		strength = p_str
		dex = p_dex
		acr = p_acr
		spd = p_spd
		siz = p_siz
		int_stat = p_int
		spr = p_spr
		fai = p_fai
		cha = p_cha
		beu = p_beu
		wil = p_wil
		endurance = p_end

class EntityChange:
	var property: String
	var from: float
	var to: float
	var metadata: Dictionary = {}
	
	func _init(p_property: String, p_from: float, p_to: float, p_metadata: Dictionary = {}):
		property = p_property
		from = p_from
		to = p_to
		metadata = p_metadata

class EntityUpdate:
	var source: int
	var affected: int
	var change: EntityChange
	var done: bool = false
	
	func _init(p_source: int, p_affected: int, p_change: EntityChange):
		source = p_source
		affected = p_affected
		change = p_change

class WeaponConfig:
	var hit_bonus: float
	var penetration_bonus: float
	var damage_translation: Dictionary = {}
	var weapon_range: Dictionary = {}
	
	func _init(p_hit_bonus: float = 0, p_penetration_bonus: float = 0):
		hit_bonus = p_hit_bonus
		penetration_bonus = p_penetration_bonus

class ArmourConfig:
	var DV: float
	var PV: float
	var resistance: Dictionary = {}
	
	func _init(p_DV: float = 12, p_PV: float = 0):
		DV = p_DV
		PV = p_PV
