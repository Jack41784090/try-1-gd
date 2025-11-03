class_name HealOthersIfAroundRule extends PositioningRule

func evaluate(entity, situation, context) -> int:
    var my_location = situation.my_location()
    var allies = null
    if context["our_squad"].has(my_location):
        allies = context["our_squad"][my_location]
    if allies and allies.size() > 0:
        return SquadBattleTypes.SquadEntityAction.HEAL
    return SquadBattleTypes.SquadEntityAction.IDLE


