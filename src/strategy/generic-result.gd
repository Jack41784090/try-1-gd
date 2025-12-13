class_name GenericResult extends Resource

@export var squad_stat_changes: Dictionary[StrategyTypes.SquadProperty, float] = {}
@export var world_stat_changes: Dictionary[StrategyTypes.GlobalModifier, float] = {}
@export var event_chain_path: String = ""
@export var requires_async: bool

func _to_string() -> String:
    return "GenericResult(squad_stat_changes=%s, world_stat_changes=%s, event_chain_path=%s, requires_async=%s)" % [
        squad_stat_changes,
        world_stat_changes,
        event_chain_path,
        requires_async
    ]

func _init(_config: Dictionary = {}) -> void:
    for key in _config.keys():
        assert(self.get(key) != null)
        # Handle typed dictionaries specially - must iterate and assign
        if key == "squad_stat_changes":
            var raw_dict = _config[key]
            for stat_key in raw_dict:
                squad_stat_changes[stat_key] = raw_dict[stat_key]
        elif key == "world_stat_changes":
            var raw_dict = _config[key]
            for stat_key in raw_dict:
                world_stat_changes[stat_key] = raw_dict[stat_key]
        else:
            self.set(key, _config[key])

func has_event_chain() -> bool:
    return not event_chain_path.is_empty()

func modify_squad_stat(stat_name: StrategyTypes.SquadProperty, value: float) -> void:
    if not squad_stat_changes.has(stat_name):
        squad_stat_changes[stat_name] = value
    else:
        squad_stat_changes[stat_name] += value

func modify_world_stat(stat_name: StrategyTypes.GlobalModifier, value: float) -> void:
    if not world_stat_changes.has(stat_name):
        world_stat_changes[stat_name] = value
    else:
        world_stat_changes[stat_name] += value