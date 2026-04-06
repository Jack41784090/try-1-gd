class_name GenericResult extends Resource

@export var priority = 10
@export var squad_stat_changes: Dictionary[StrategyTypes.SquadProperty, float] = {}
@export var event_chain_path: String = ""
@export var requires_async: bool
@export var new_recruits: Array[Warrior] = []
# @export var triggered_event_ids: Array[String] = []

func _to_string() -> String:
    return "GenericResult(squad_stat_changes=%s, event_chain_path=%s, requires_async=%s)" % [
        squad_stat_changes,
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
        else:
            self.set(key, _config[key])

func has_event_chain() -> bool:
    return not event_chain_path.is_empty()

func append_new_recruits(recruits: Array[Warrior]) -> void:
    for recruit in recruits:
        new_recruits.append(recruit)

func modify_squad_stat(stat_name: StrategyTypes.SquadProperty, value: float) -> void:
    if not squad_stat_changes.has(stat_name):
        squad_stat_changes[stat_name] = value
    else:
        squad_stat_changes[stat_name] += value