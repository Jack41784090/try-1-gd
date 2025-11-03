class_name ActionConsideration extends Consideration

@export var target_action: SquadBattleTypes.SquadEntityAction
@export var condition_considerations: Array[Consideration] = []

func score(entity, situation, context) -> float:
    var action_name = SquadBattleUtils.get_action_string(target_action)
    print("  [ActionConsideration] Evaluating action: %s (weight=%.2f)" % [action_name, weight])
    
    # Check if all conditions are met
    var all_conditions_met := true
    var conditions_passed := 0
    var total_score := 0.0
    
    for cond in condition_considerations:
        var cond_score = cond.score(entity, situation, context)
        total_score += cond_score
        if cond_score > 0.0:
            conditions_passed += 1
        else:
            all_conditions_met = false
    
    var result: float
    if condition_considerations.size() == 0:
        # No conditions means always applicable
        result = weight
        print("  [ActionConsideration] %s: No conditions → score=%.2f" % [action_name, result])
    else:
        result = weight if all_conditions_met else 0.0
        print("  [ActionConsideration] %s: %d/%d conditions met, total_score=%.2f → final_score=%.2f" % [
            action_name, conditions_passed, condition_considerations.size(), total_score, result])
    
    return result

