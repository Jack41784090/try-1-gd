extends Node2D

signal TargetTookDamage(val)
signal OnBasicAttackHit(val)
signal OnCastSkill()

enum Signals {
	TargetTookDamage = 1,
	OnBasicAttackHit = 2,
	OnCastSkill = 3,
}

func _get_signal(signal_enum: Signals) -> Signal:
	match signal_enum:
		Signals.TargetTookDamage: return TargetTookDamage
		Signals.OnBasicAttackHit: return OnBasicAttackHit
		Signals.OnCastSkill: return OnCastSkill
		_: assert(false, "Unknown signal enum: %s" % signal_enum); return TargetTookDamage  # Fallback

func EmitSignal(nameOfSignal: Signals, ...args: Array):
	var _signal = _get_signal(nameOfSignal)
	if args.size() == 0:
		_signal.emit()
	elif args.size() == 1:
		_signal.emit(args[0])
	else:
		_signal.emit.callv(args)

func Connect(nameOfSignal: Signals, function):
	var _signal = _get_signal(nameOfSignal)
	return _signal.connect(function)

func Disconnect(nameOfSignal: Signals, function):
	var _signal = _get_signal(nameOfSignal)
	_signal.disconnect(function)
