class_name  TriggerChain extends Resource
@export var another_trigger: Triggerable
@export var chance: float = 1.0
# @export var conditions : Array[TriggerCondition] = []

func _to_string() -> String:
	return "TriggerChain(Another Trigger: %s, Chance: %.2f)" % [
		another_trigger if "another_trigger" else "None",
		chance
	]

func _init(_at: Triggerable = null, _c: float = 1.0) -> void:
	if _at != null:
		another_trigger = _at
		chance = _c
