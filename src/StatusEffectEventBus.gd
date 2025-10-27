extends Node2D

signal _hello_world(val)
signal _target_took_damage(val)

enum Signals {
	HelloWorld,
	
	TargetTookDamage
}

const _signals: Dictionary = {
	Signals.HelloWorld: "_hello_world",
	Signals.TargetTookDamage: "_target_took_damage"
}

func _get_signal_name(signal_enum: Signals) -> String:
	match signal_enum:
		Signals.HelloWorld: return "HelloWorld"
		Signals.TargetTookDamage: return "TargetTookDamage"
		_: return "Unknown_%d" % signal_enum

func emitSignal(nameOFSignal: Signals, ...args: Array):
	print("  [EventBus] Emitting signal: %s with %d args" % [_get_signal_name(nameOFSignal), args.size()])
	var signal_name = _signals.get(nameOFSignal)
	
	# Use emit_signal with proper argument spreading
	if args.size() == 0:
		return self.emit_signal(signal_name)
	elif args.size() == 1:
		return self.emit_signal(signal_name, args[0])
	else:
		# For multiple args, use callv to spread them
		return self.callv("emit_signal", [signal_name] + args)

func Connect(nameOfSignal: Signals, function):
	print("  [EventBus] Connected: %s" % _get_signal_name(nameOfSignal))
	return self.connect(_signals.get(nameOfSignal), function)

func Disconnect(nameOfSignal: Signals, function):
	print("  [EventBus] Disconnected: %s" % _get_signal_name(nameOfSignal))
	self.disconnect(_signals.get(nameOfSignal), function)

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
