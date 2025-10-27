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

func emitSignal(nameOFSignal: Signals, ...args: Array):
	#print(_signals.get(nameOFSignal))
	#print("Emitting signal: " % str(nameOFSignal) ) #% " with " % str(args))
	self.emit_signal(_signals.get(nameOFSignal), args)

func Connect(nameOfSignal: Signals, function):
	#print("Connected: " % str(nameOfSignal)) # % " with " % str(function))
	self.connect(_signals.get(nameOfSignal), function)

func Disconnect(nameOfSignal: Signals, function):
	#print("Disconnected: " % str(nameOfSignal) ) #% " with " % str(function))
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
