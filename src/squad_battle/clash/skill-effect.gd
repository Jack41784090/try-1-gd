## SkillEffects go along with Skill. Always commits the moment a Skill a committed. If commit fails, it wouldn't stay in the queue of statuses within the entity.
class_name SkillEffect extends Resource

var _debug_id: String = ""

# enum Targeting {
# 	SENTINEL,
# 	Self,
# 	Target,
# }

@export var name: String
@export var stacks: int = 0
var source: SquadEntity
var affected: SquadEntity; 
@export var at_signal: Array[StatusEffectEventBus.Signals]

var updates_collector = null

func set_attacker_and_target(attacker: SquadEntity, target: SquadEntity) -> void:
	source = attacker
	affected = target

func setup_connections(collector = null) -> void:
	"""Call this after the resource is loaded to connect at_signal to the event bus.
	If collector is provided, updates from signal-triggered commits will be appended to it."""
	updates_collector = collector
	print("%s Setting up connections" % _debug_id)
	print("    → Triggers to connect: %d" % at_signal.size())
	print("    → Triggers: %s" % _format_triggers(at_signal))

func _format_trigger_name(trigger) -> String:
	return StatusEffectEventBus.Signals.keys()[trigger]

func _format_triggers(trigger_array: Array) -> String:
	if trigger_array.is_empty():
		return "None"
	var names = []
	for t in trigger_array:
		names.append(_format_trigger_name(t))
	return ", ".join(names)

func commit(_data = null) -> Array[EntityUpdate]:
	assert(false, "Don't call this function directly.")
	return [];
