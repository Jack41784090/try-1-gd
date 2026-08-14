class_name Triggerable extends Resource

@export var trigger_id: String = ""
@export var trigger_name: String = ""
@export var description: String = ""
@export var conditions: Array[TriggerCondition] = []
@export var trigger_chains: Array = [] # Can't use typed array - Godot resource loader doesn't support custom typed arrays
@export var repeats: int = -1
@export var emergency_priority: int = 0
@export var chance: float = 1.0

func _to_string() -> String:
	return "Triggerable: %s (ID: %s), Repeats: %d, Conditions: %d, Trigger Chains: %s, Priority: %d, %s" % [
		trigger_name,
		trigger_id,
		repeats,
		conditions.size(),
		trigger_chains,
		emergency_priority,
		description,
	]

func _init() -> void:
	pass

## Evaluates all conditions against the provided context dict.
## ALL conditions must pass (AND logic) for the triggerable to fire.
func check_conditions(context: Dictionary) -> bool:
	MyLog.trace("Triggerable", "Checking conditions for: %s" % trigger_name)
	for condition in conditions:
		var e = condition.evaluate(context)
		if not e:
			MyLog.trace("Triggerable", "  ❎ %s" % condition._to_string())
			return false
		else:
			MyLog.trace("Triggerable", "  ✅ %s" % condition._to_string())
	return true

func can_trigger(context: Dictionary) -> bool:
	return check_conditions(context)

func trigger(context: Dictionary) -> Array[Variant]:
	var result = execute(context)
	return [result]

func execute(_context: Dictionary) -> Variant:
	assert(false, "Triggerable.execute() must be overridden in subclass")
	return {}
