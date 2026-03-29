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
var source: CombatEntity
var affected: CombatEntity;
@export var triggers: Array[StatusEffectEventBus.Signals]

var battle_context: BattleContext = null
var updates_collector = null

func set_attacker_and_target(attacker: CombatEntity, target: CombatEntity, _context: BattleContext = null) -> void:
	source = attacker
	affected = target
	battle_context = _context
	if source and affected:
		_debug_id = "[%s→%s:%s]" % [source.entity_name, affected.entity_name, name]

func setup_connections(collector = null) -> void:
	"""Call this after the resource is loaded to connect triggers to the event bus.
	If collector is provided, updates from signal-triggered commits will be appended to it."""
	updates_collector = collector
	if triggers.size() != 0:
		print("  [effect] %s — on: %s" % [_debug_id, _format_triggers(triggers)])
	for trigger in triggers:
		StatusEffectEventBus.Connect(trigger, commit)

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
