class_name ContextConsideration extends Consideration

enum ContextQuery {
    ALLIES_AT_MY_LOCATION,      # Allies sharing my location
    LINE_AHEAD_EXISTS,          # Is there a frontline ahead of me?
    AT_SPECIFIC_LOCATION,       # Am I at a specific location?
}

@export var query_type: ContextQuery
@export var target_location: SquadBattleTypes.SquadEntityInSquadLocation
@export var invert: bool = false  # Flip the result

func score(entity, situation, context) -> float:
    var result := false
    var query_name = ["ALLIES_AT_MY_LOCATION", "LINE_AHEAD_EXISTS", "AT_SPECIFIC_LOCATION"][query_type]
    var details := ""
    
    match query_type:
        ContextQuery.ALLIES_AT_MY_LOCATION:
            result = _has_allies_at_my_location(entity, context)
            var my_location = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
            var loc_name = SquadBattleTypes.SquadEntityInSquadLocation.keys()[my_location - 1]
            var ally_count = 0
            if context["our_squad"].has(my_location):
                ally_count = context["our_squad"][my_location].size()
            details = "location=%s, allies=%d" % [loc_name, ally_count]
        ContextQuery.LINE_AHEAD_EXISTS:
            result = _line_ahead_exists(entity, situation)
            details = "has_frontline_ahead=%s" % result
        ContextQuery.AT_SPECIFIC_LOCATION:
            result = _at_specific_location(entity, target_location)
            var my_location = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
            var my_loc_name = SquadBattleTypes.SquadEntityInSquadLocation.keys()[my_location - 1]
            var target_loc_name = SquadBattleTypes.SquadEntityInSquadLocation.keys()[target_location - 1]
            details = "my_loc=%s, target=%s" % [my_loc_name, target_loc_name]
    
    if invert:
        result = not result
    
    var final_score = weight if result else 0.0
    print("    [ContextConsideration.%s] %s, inverted=%s → %s → score=%.2f" % [
        query_name, details, invert, result, final_score])
    
    return final_score

func _has_allies_at_my_location(entity, context) -> bool:
    var my_location = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
    if context["our_squad"].has(my_location):
        var allies = context["our_squad"][my_location]
        return allies != null and allies.size() > 1  # More than just me
    return false

func _line_ahead_exists(entity, situation) -> bool:
    var frontline = situation.frontline_ally()
    if frontline == null:
        return false
    
    for ally in frontline:
        if ally.player_id == entity.player_id:
            return false  # I am the frontline
    return true  # There's a line ahead of me

func _at_specific_location(entity, location: int) -> bool:
    var my_location = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
    return my_location == location

