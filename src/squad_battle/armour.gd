extends RefCounted
class_name SquadArmour

const Types = preload("res://squad_battle/types.gd")

var DV: float
var PV: float
var resistance: Dictionary = {}

func unprotected() -> SquadArmour:
	DV = 12
	PV = 0
	resistance = {
		Types.DamageType.Cut: -0.2,
		Types.DamageType.Impale: -0.2
	}
	return self

func _init(config: Types.ArmourConfig = null):
	if config:
		DV = config.DV
		PV = config.PV
		resistance = config.resistance.duplicate()
	else:
		unprotected()

func get_DV() -> float:
	return DV

func get_PV() -> float:
	return PV

func get_raw_damage_taken(damage_types_array: Dictionary) -> float:
	var damage = 0.0
	
	for damage_type in damage_types_array:
		var value = damage_types_array[damage_type]
		if resistance.has(damage_type):
			damage += value * (1 - resistance[damage_type])
		else:
			damage += value
	
	return damage

func get_state() -> Dictionary:
	return {
		"DV": DV,
		"PV": PV,
		"resistance": resistance.duplicate()
	}
