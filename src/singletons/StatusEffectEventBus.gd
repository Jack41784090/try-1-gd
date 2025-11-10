extends Node2D

signal HelloWorld(val)
signal TargetTookDamage(val)
signal OnBasicAttackHit(val)
signal OnCastSkill()

enum Signals {
	HelloWorld,
	
	TargetTookDamage,
	OnBasicAttackHit,
	OnCastSkill,
	TestSignal,
}

func _get_signal(signal_enum: Signals) -> Signal:
	match signal_enum:
		Signals.HelloWorld: return HelloWorld
		Signals.TargetTookDamage: return TargetTookDamage
		Signals.OnBasicAttackHit: return OnBasicAttackHit
		Signals.OnCastSkill: return OnCastSkill
		_: assert(false, "Unknown signal enum: %s" % signal_enum); return HelloWorld  # Fallback

func EmitSignal(nameOfSignal: Signals, ...args: Array):
	var _signal = _get_signal(nameOfSignal)
	print("  [EventBus] Emitting signal: %s with %d args" % [_signal, args.size()])
	if args.size() == 0:
		_signal.emit()
	elif args.size() == 1:
		_signal.emit(args[0])
	else:
		_signal.emit.callv(args)

func Connect(nameOfSignal: Signals, function):
	var _signal = _get_signal(nameOfSignal)
	print("  [EventBus] Connected: %s" % _signal)
	return _signal.connect(function)

func Disconnect(nameOfSignal: Signals, function):
	var _signal = _get_signal(nameOfSignal)
	print("  [EventBus] Disconnected: %s" % _signal)
	_signal.disconnect(function)

# #button.gd
# var worldName := "Earth"
# func helloWorld()-> void:
#     SignalBus.emit_signal("_hello_world", worldName)

# Connect the node that should trigger event.

# #player.gd
# func _ready()-> void:
#     SignalBus.connect("_hello_world", helloWorld) 

# func helloWorld(val):
#     print("Hello ", val)
