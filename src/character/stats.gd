class_name CombatEntityStats
extends RefCounted

var base: CombatEntityBaseStats
var hp: float
var sta: float
var org: float
var pos: float
var mag: float
var loc: SquadBattleTypes.SquadEntityInSquadLocation


func _init(_base: CombatEntityBaseStats) -> void:
	base = _base
