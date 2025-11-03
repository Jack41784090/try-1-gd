class_name EntityConsideration extends Consideration

@export var property: SquadBattleTypes.EntityChangeable
@export var detection: CsdrTypes.DETECTION
@export var value: float
@export var or_equal: bool = false
@export var percentage: bool = false

func score(entity, _situation, _context) -> float:
    var stat_v: float = entity.changeable_stats.get(property)
    var original_stat = stat_v
    
    if percentage:
        var max_v: float = entity.get_ceiling_changeable_stat(property)
        stat_v = stat_v / max(max_v, 1.0)
    
    var property_name = SquadBattleTypes.EntityChangeable.keys()[property]
    var detection_name = CsdrTypes.DETECTION.keys()[detection]
    var result: float
    var condition_met: bool
    
    match detection:
        CsdrTypes.DETECTION.EQUAL:
            condition_met = (stat_v == value)
            result = int(condition_met) * weight
        CsdrTypes.DETECTION.ABOVE:
            if or_equal:
                condition_met = (stat_v >= value)
            else:
                condition_met = (stat_v > value)
            result = int(condition_met) * weight
        CsdrTypes.DETECTION.BELOW:
            if or_equal:
                condition_met = (stat_v <= value)
            else:
                condition_met = (stat_v < value)
            result = int(condition_met) * weight
        _:
            assert(false, "Unimplemented detection in EntityConsideration");
            result = 0
    
    if percentage:
        print("    [EntityConsideration] %s: %.1f/%.1f (%.1f%%) %s %.1f? %s → score=%.2f" % [
            property_name, original_stat, entity.get_ceiling_changeable_stat(property), 
            stat_v * 100, detection_name, value * 100, condition_met, result])
    else:
        print("    [EntityConsideration] %s: %.1f %s %.1f? %s → score=%.2f" % [
            property_name, stat_v, detection_name, value, condition_met, result])
    
    return result
