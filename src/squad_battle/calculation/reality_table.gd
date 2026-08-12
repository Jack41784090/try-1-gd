class_name RealityTable extends Resource

@export var entries: Array[RealityFormula] = []


func get_calculation(reality: SquadBattleTypes.Reality) -> Calculation:
	for entry in entries:
		if entry.reality == reality:
			return entry.calculation
	assert(false, "RealityTable missing entry for %s" % reality)
	return null
