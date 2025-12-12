## Status effects are persistent versions of skill effect. They are always committed when certain events under StatusEffectEventBus is emitted.
class_name StatusEffect extends Resource

@export var name: String;
@export var duration: int
@export var effects: Array[SkillEffect]
@export var triggers: Array[StatusEffectEventBus.Signals]

func _init(
	_name: String = '',
	_duration: int = -1,
	_triggers: Array[StatusEffectEventBus.Signals] = []) -> void:
	if _name == '':
		return
	
	name = _name;
	effects = [];
	duration = _duration;
	triggers = _triggers
	
	for t in _triggers:
		StatusEffectEventBus.Connect(t, commit);
	pass

func _format_triggers(trigger_array: Array) -> String:
	if trigger_array.is_empty():
		return "None"
	var names = []
	for t in trigger_array:
		match t:
			StatusEffectEventBus.Signals.HelloWorld: names.append("HelloWorld")
			StatusEffectEventBus.Signals.TargetTookDamage: names.append("TargetTookDamage")
			_: names.append("Signal_%d" % t)
	return ", ".join(names)

func commit():
	print("  [StatusEffect] '%s' triggered (Duration: %d)" % [name, duration])
	
	if duration < 0:
		print("    ✗ Error: Status effect applied more than it should")
		assert(false, "Critical error: status effect '%s' has negative duration" % name)
		return
	
	# Execute all effects
	print("    → Executing %d effect(s)" % effects.size())
	for i in range(effects.size()):
		var effect = effects[i]
		print("    → Effect %d/%d:" % [i + 1, effects.size()])
		effect.commit()
	
	# Decrease duration
	duration -= 1
	print("    → Duration remaining: %d" % duration)
	
	# Clean up if expired
	if duration == 0:
		print("    → Status effect '%s' expired, disconnecting triggers" % name)
		for t in triggers:
			StatusEffectEventBus.Disconnect(t, commit)
	pass
