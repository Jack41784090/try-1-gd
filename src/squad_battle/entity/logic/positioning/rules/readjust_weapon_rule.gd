extends PostioningRule
class_name ReadjustWeaponRule

func evaluate(entity, situation, context) -> int:
    var unwrapped = situation.unwrap()
    var my_location = unwrapped["my_location"]
    var weapon = entity.weapon

    var front_opts = weapon.get_range_at_location(Types.SquadEntityInSquadLocation.Front)
    var mid_opts = weapon.get_range_at_location(Types.SquadEntityInSquadLocation.Middle)
    var back_opts = weapon.get_range_at_location(Types.SquadEntityInSquadLocation.Back)

    var front_total := 0
    for opt in front_opts:
        match opt:
            Types.SquadEntityInSquadLocation.Front:
                front_total += unwrapped.get("frontline_enemy_count", 0)
            Types.SquadEntityInSquadLocation.Middle:
                front_total += unwrapped.get("midline_enemy_count", 0)
            Types.SquadEntityInSquadLocation.Back:
                front_total += unwrapped.get("backline_enemy_count", 0)

    var mid_total := 0
    for opt in mid_opts:
        match opt:
            Types.SquadEntityInSquadLocation.Front:
                mid_total += unwrapped.get("frontline_enemy_count", 0)
            Types.SquadEntityInSquadLocation.Middle:
                mid_total += unwrapped.get("midline_enemy_count", 0)
            Types.SquadEntityInSquadLocation.Back:
                mid_total += unwrapped.get("backline_enemy_count", 0)

    var back_total := 0
    for opt in back_opts:
        match opt:
            Types.SquadEntityInSquadLocation.Front:
                back_total += unwrapped.get("frontline_enemy_count", 0)
            Types.SquadEntityInSquadLocation.Middle:
                back_total += unwrapped.get("midline_enemy_count", 0)
            Types.SquadEntityInSquadLocation.Back:
                back_total += unwrapped.get("backline_enemy_count", 0)

    var max_count = max(front_total, mid_total, back_total)
    var current_range_size = weapon.get_range_at_location(my_location).size()

    if max_count == current_range_size:
        return null

    match my_location:
        Types.SquadEntityInSquadLocation.Front:
            if mid_total > front_total:
                return Types.SquadEntityAction.RETREAT
        Types.SquadEntityInSquadLocation.Middle:
            var maximum = max(front_total, back_total)
            if maximum == front_total:
                return Types.SquadEntityAction.FORWARD
            if maximum == back_total:
                return Types.SquadEntityAction.RETREAT
        Types.SquadEntityInSquadLocation.Back:
            if mid_total > back_total:
                return Types.SquadEntityAction.FORWARD
    return Types.SquadEntityAction.IDLE


