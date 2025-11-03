class_name EntityConsideration extends Consideration

var entity: SquadEntity
@export var property: SquadBattleTypes.EntityChangeable
@export var detection: CsdrTypes.DETECTION
@export var value: float
@export var or_equal: bool = false
@export var percentage: bool = false

func score() -> float:
    var stat_v: float = entity.changeable_stats.get(property)
    match detection:
        CsdrTypes.DETECTION.EQUAL:
            return int(stat_v == value) * weight
        CsdrTypes.DETECTION.ABOVE:
            if or_equal:
                return int(stat_v >= value) * weight
            else:
                return int(stat_v > value) * weight
        CsdrTypes.DETECTION.BELOW:
            if or_equal:
                return int(stat_v <= value) * weight
            else:
                return int(stat_v < value) * weight
        _:
            assert(false, "Unimplemented detection in EntityConsideration");
            return 0;
