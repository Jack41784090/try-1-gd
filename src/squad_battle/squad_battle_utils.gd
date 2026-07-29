class_name SquadBattleUtils extends RefCounted


static var _action_keys = SquadBattleTypes.SquadEntityAction.keys()
static func get_action_string(action: SquadBattleTypes.SquadEntityAction) -> String:
    return _action_keys[action]