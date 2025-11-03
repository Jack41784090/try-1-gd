class_name RetreatIfOutnumberedRule extends PositioningRule

func evaluate(_entity, situation, _context) -> int:
    var unwrapped = situation.unwrap()
    var my_location = unwrapped["my_location"]
    var my_allies = (unwrapped.get("frontline_ally_count", 0)
        + unwrapped.get("midline_ally_count", 0)
        + unwrapped.get("backline_ally_count", 0))
    var my_enemies = (unwrapped.get("frontline_enemy_count", 0)
        + unwrapped.get("midline_enemy_count", 0)
        + unwrapped.get("backline_enemy_count", 0))

    if my_enemies > my_allies * 2:
        if my_location == Types.SquadEntityInSquadLocation.Back:
            return Types.SquadEntityAction.CAPITULATE
        return Types.SquadEntityAction.RETREAT
    return Types.SquadEntityAction.IDLE


