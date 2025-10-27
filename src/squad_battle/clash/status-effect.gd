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

func commit():
	print(name % " triggered commit")
	duration -= 1;
	for e in effects:
		e.commit()
	if duration == 0:
		for t in triggers:
			StatusEffectEventBus.Disconnect(t, commit)
	elif duration < 0:
		assert(false, "Critical error: status effect " % name % " applied more than once");
	pass
