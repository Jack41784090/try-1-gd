class_name ActivityResult extends GenericResult

@export var location_changed: String = ""
@export var requires_combat: bool = false
@export var combat_target_squad_id: String = ""
@export var clues_left: int = 0

func _to_string() -> String:
	return "ActivityResult(location_changed=%s, requires_combat=%s, combat_target=%s, %s)" % [location_changed, requires_combat, combat_target_squad_id, super._to_string()]

func _init(config: Dictionary = {}) -> void:
	super._init(config)
	location_changed = config.get("location_changed", "")
