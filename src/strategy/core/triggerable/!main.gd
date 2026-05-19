class_name Triggerable extends Resource

@export var trigger_id: String = ""
@export var trigger_name: String = ""
@export var description: String = ""
@export var conditions: Array[TriggerCondition] = []
@export var trigger_chains: Array = [] # Can't use typed array - Godot resource loader doesn't support custom typed arrays
@export var repeats: int = -1
@export var emergency_priority: int = 0
@export var chance: float = 1.0 # Probability of triggering when conditions are met (0.0 to 1.0)
# @export var event_chain_path: String

signal triggered(result: Dictionary)

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

func check_conditions(context: Dictionary) -> bool: # Evaluates all conditions against the provided context dict
	# ALL conditions must pass (AND logic) for the triggerable to fire
	# e.g., conditions: [LOCATION="salzburg", ACTIVITY_TYPE=FORAGE]
	#   → context={location: "salzburg", activity: FORAGE} → both pass → true
	#   → context={location: "vienna", activity: FORAGE} → LOCATION fails → false
	Log.trace("Triggerable", "Checking conditions for: %s" % trigger_name)
	for condition in conditions:
		var e = condition.evaluate(context)
		if not e:
			Log.trace("Triggerable", "  ❎ %s" % condition._to_string())
			return false
		else:
			Log.trace("Triggerable", "  ✅ %s" % condition._to_string())
	return true

func can_trigger(context: Dictionary) -> bool:
	return check_conditions(context)

func trigger(context: Dictionary) -> Array[Variant]:
	# Fires this triggerable: signal → execute() → signal. Returns results wrapped in array.
	# Flow: execution_started → execute(context) → triggered(result_dict) → execution_completed (if sync)
	# e.g., GameEvent "bandit_ambush" → execute() returns {trigger_id: "bandit_ambush", morale: -10, ...}
	var result = execute(context)
	var result_dict: Dictionary = {}
	result_dict = result


	return [result]

func execute(context: Dictionary) -> Variant:
	push_error("Triggerable.execute() must be overridden in subclass")
	return {
		"trigger_id": trigger_id,
		"trigger_name": trigger_name,
		"requires_async": false,
	}

func add_condition(condition: TriggerCondition) -> void:
	conditions.append(condition)
