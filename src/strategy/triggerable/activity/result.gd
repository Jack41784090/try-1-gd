class_name ActivityResult extends GenericResult

@export var location_changed: String = ""

func _to_string() -> String:
	return "ActivityResult(location_changed=%s, %s)" % [location_changed, super._to_string()]

func _init(config: Dictionary = {}) -> void:
	print("config", config)
	super._init(config)
	location_changed = config.get("location_changed", "")
