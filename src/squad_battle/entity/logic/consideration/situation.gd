class_name SituationConsideration extends Consideration

enum ComparisonType {
    OUTNUMBERED,            # my_enemies > my_allies * threshold
    ALLIES_IN_LOCATION,     # count allies at specific location
    ENEMIES_IN_LOCATION,    # count enemies at specific location
    BETTER_WEAPON_POSITION, # weapon has better range elsewhere
}

@export var comparison_type: ComparisonType
@export var threshold: float = 2.0
@export var target_location: SquadBattleTypes.SquadEntityInSquadLocation

func score(_entity, situation, _context) -> float:
    var result: float
    var type_name = ["OUTNUMBERED", "ALLIES_IN_LOCATION", "ENEMIES_IN_LOCATION", "BETTER_WEAPON_POSITION"][comparison_type]
    
    match comparison_type:
        ComparisonType.OUTNUMBERED:
            result = _score_outnumbered(situation)
        ComparisonType.ALLIES_IN_LOCATION:
            result = _score_allies_in_location(situation)
        ComparisonType.ENEMIES_IN_LOCATION:
            result = _score_enemies_in_location(situation)
        ComparisonType.BETTER_WEAPON_POSITION:
            result = _score_better_weapon_position(_entity, situation)
        _:
            assert(false, "Unimplemented comparison type in SituationConsideration");
            result = -INF
    
    return result

func _score_outnumbered(situation) -> float:
    var unwrapped = situation.unwrap()
    var my_allies = (unwrapped.get("frontline_ally_count", 0) + 
                    unwrapped.get("midline_ally_count", 0) + 
                    unwrapped.get("backline_ally_count", 0))
    var my_enemies = (unwrapped.get("frontline_enemy_count", 0) + 
                     unwrapped.get("midline_enemy_count", 0) + 
                     unwrapped.get("backline_enemy_count", 0))
    
    var is_outnumbered = my_enemies > my_allies * threshold
    var result = weight if is_outnumbered else 0.0
    print("    [SituationConsideration.OUTNUMBERED] allies=%d, enemies=%d, threshold=%.1fx → %s → score=%.2f" % [
        my_allies, my_enemies, threshold, is_outnumbered, result])
    return result

func _score_allies_in_location(situation) -> float:
    var unwrapped = situation.unwrap()
    var count = 0
    var location_name = SquadBattleTypes.SquadEntityInSquadLocation.keys()[target_location]
    
    match target_location:
        SquadBattleTypes.SquadEntityInSquadLocation.Front:
            count = unwrapped.get("frontline_ally_count", 0)
        SquadBattleTypes.SquadEntityInSquadLocation.Middle:
            count = unwrapped.get("midline_ally_count", 0)
        SquadBattleTypes.SquadEntityInSquadLocation.Back:
            count = unwrapped.get("backline_ally_count", 0)
    
    var result = count * weight
    print("    [SituationConsideration.ALLIES_IN_LOCATION] location=%s, count=%d, weight=%.2f → score=%.2f" % [
        location_name, count, weight, result])
    return result

func _score_enemies_in_location(situation) -> float:
    var unwrapped = situation.unwrap()
    var count = 0
    var location_name = SquadBattleTypes.SquadEntityInSquadLocation.keys()[target_location]
    
    match target_location:
        SquadBattleTypes.SquadEntityInSquadLocation.Front:
            count = unwrapped.get("frontline_enemy_count", 0)
        SquadBattleTypes.SquadEntityInSquadLocation.Middle:
            count = unwrapped.get("midline_enemy_count", 0)
        SquadBattleTypes.SquadEntityInSquadLocation.Back:
            count = unwrapped.get("backline_enemy_count", 0)
    
    var result = count * weight
    print("    [SituationConsideration.ENEMIES_IN_LOCATION] location=%s, count=%d, weight=%.2f → score=%.2f" % [
        location_name, count, weight, result])
    return result

func _score_better_weapon_position(entity, situation) -> float:
    var unwrapped = situation.unwrap()
    var my_location = unwrapped["my_location"]
    var weapon = entity.weapon
    
    var front_opts = weapon.get_range_at_location(SquadBattleTypes.SquadEntityInSquadLocation.Front)
    var mid_opts = weapon.get_range_at_location(SquadBattleTypes.SquadEntityInSquadLocation.Middle)
    var back_opts = weapon.get_range_at_location(SquadBattleTypes.SquadEntityInSquadLocation.Back)
    
    var front_total := _count_targets_in_ranges(front_opts, unwrapped)
    var mid_total := _count_targets_in_ranges(mid_opts, unwrapped)
    var back_total := _count_targets_in_ranges(back_opts, unwrapped)
    
    var max_count = max(front_total, mid_total, back_total)
    var current_total := _count_targets_in_ranges(weapon.get_range_at_location(my_location), unwrapped)
    
    var has_better = max_count > current_total
    var result = weight if has_better else 0.0
    var location_name = SquadBattleTypes.SquadEntityInSquadLocation.keys()[my_location]
    print("    [SituationConsideration.BETTER_WEAPON_POSITION] current_loc=%s, targets=%d, max_elsewhere=%d → %s → score=%.2f" % [
        location_name, current_total, max_count, has_better, result])
    return result

func _count_targets_in_ranges(ranges: Array, unwrapped: Dictionary) -> int:
    var total := 0
    for opt in ranges:
        match opt:
            SquadBattleTypes.SquadEntityInSquadLocation.Front:
                total += unwrapped.get("frontline_enemy_count", 0)
            SquadBattleTypes.SquadEntityInSquadLocation.Middle:
                total += unwrapped.get("midline_enemy_count", 0)
            SquadBattleTypes.SquadEntityInSquadLocation.Back:
                total += unwrapped.get("backline_enemy_count", 0)
    return total

