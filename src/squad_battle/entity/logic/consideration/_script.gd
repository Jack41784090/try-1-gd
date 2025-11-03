class_name Consideration extends Resource

# @export var action: SquadBattleTypes.SquadEntityAction
@export var weight: float = 1.0
@export var op: CsdrTypes.OP

@export var subcsdr: Array[Consideration]

func score(entity, situation, context) -> float:
    var result: float
    match op:
        CsdrTypes.OP.ADD:
            var sum: float = subcsdr.reduce(func(acc: float, csdr: Consideration): return acc + csdr.score(entity, situation, context), 0.0)
            result = sum * weight
            print("  [Consideration.ADD] sum=%.2f, weight=%.2f → %.2f" % [sum, weight, result])
        CsdrTypes.OP.RDC:
            var sum: float = subcsdr.reduce(func(acc: float, csdr: Consideration): return acc - csdr.score(entity, situation, context), 0.0)
            result = sum * weight
            print("  [Consideration.RDC] sum=%.2f, weight=%.2f → %.2f" % [sum, weight, result])
        CsdrTypes.OP.MUL:
            var sum: float = subcsdr.reduce(func(acc: float, csdr: Consideration): return acc * csdr.score(entity, situation, context), 1.0)
            result = sum * weight
            print("  [Consideration.MUL] sum=%.2f, weight=%.2f → %.2f" % [sum, weight, result])
        _:
            assert(false, "Unimplemented Operation in Consideration used")
            result = 0.0
    return result

