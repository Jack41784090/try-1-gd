class_name ActivityResult extends GenericResult

@export var location_changed: String = ""

func _init(config: Dictionary = {}) -> void:
	super._init(config)
	location_changed = config.get("location_changed", "")
