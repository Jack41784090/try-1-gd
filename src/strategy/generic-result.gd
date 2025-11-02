class_name GenericResult extends Resource

@export var squad_stat_changes: Dictionary[StrategyTypes.SquadProperty, float] = {}
@export var world_stat_changes: Dictionary[StrategyTypes.GlobalModifier, float] = {}
@export var event_chain_path: String = ""
@export var requires_async: bool
@export var triggered_event_ids: Array[String] = []

func _init(_config: Dictionary) -> void:
    for key in _config.keys():
        if self.get(key) != null:
            self.set(key, _config[key])
    pass;

func trigger_event(event_id: String) -> void:
    triggered_event_ids.append(event_id)

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