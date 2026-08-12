class_name Calculation extends Resource

## Mirrors the ADD/MUL fold semantics previously hardcoded in
## CombatEntity._RealityOp / _REALITY_TABLE.
enum Op { ADD, MUL }

@export var base: float = 0.0
@export var op: Op = Op.ADD
@export var terms: Array[CalculationTerm] = []


func evaluate(entity: CombatEntity) -> float:
	if op == Op.MUL:
		var product: float = 1.0
		for term in terms:
			product *= term.sample(entity)
		return base + product
	var total: float = base
	for term in terms:
		total += term.sample(entity)
	return total
