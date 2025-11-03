extends Resource
class_name PositioningPolicy

@export var rules: Array[PositioningRule] = []
@export var considerations: Array[Consideration] = []
@export var candidate_actions: Array[int] = [
    SquadBattleTypes.SquadEntityAction.FORWARD,
    SquadBattleTypes.SquadEntityAction.RETREAT,
    SquadBattleTypes.SquadEntityAction.IDLE,
]

func suggest_move(entity, situation, context) -> int:
    if considerations.size() > 0:
        return _suggest_with_utility(entity, situation, context)

    for rule in rules:
        var move = rule.evaluate(entity, situation, context)
        if move != SquadBattleTypes.SquadEntityAction.IDLE:
            return move

    return SquadBattleTypes.SquadEntityAction.IDLE

func _suggest_with_utility(entity, situation, context) -> int:
    var best_action := SquadBattleTypes.SquadEntityAction.IDLE
    var best_score := -INF
    for action in candidate_actions:
        var score := 0.0
        for c in considerations:
            score += c.score()
        if score > best_score:
            best_score = score
            best_action = action
    return best_action

