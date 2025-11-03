class_name Consideration extends Resource

@export var weight: float = 1.0
@export var op: CsdrTypes.OP

@export var subcsdr: Array[Consideration]

# func _ini

func score() -> float:
    match op:
        CsdrTypes.OP.ADD:
            var sum: float = subcsdr.reduce(func(acc: float, csdr: Consideration): return acc + csdr.score(), 0.0)
            return sum * weight
        CsdrTypes.OP.RDC:
            var sum: float = subcsdr.reduce(func(acc: float, csdr: Consideration): return acc - csdr.score(), 0.0)
            return sum * weight
        CsdrTypes.OP.MUL:
            var sum: float = subcsdr.reduce(func(acc: float, csdr: Consideration): return acc * csdr.score(), 0.0)
            return sum * weight
        _:
            assert(false, "Unimplemented Operation in Consideration used")
            return 0.0

