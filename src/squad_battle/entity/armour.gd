extends RefCounted
class_name SquadArmour

var DV: float
var PV: float
var resistance: Dictionary = {}

func _init(config: ArmorConfig = null):
	if config:
		DV = config.DV
		PV = config.PV
		resistance = config.resistance.duplicate()
	else:
		DV = 12
		PV = 0
		resistance = {
			SquadBattleTypes.DamageType.Cut: - 0.2,
			SquadBattleTypes.DamageType.Impale: - 0.2
		}

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


