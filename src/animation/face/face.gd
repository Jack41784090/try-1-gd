@tool
class_name Face extends Node2D

## Holds no table of expressions — it announces an intent and every FaceComponent in its subtree answers for itself from its own authored FaceReaction list; a part with nothing to say just stays put.

signal expression_changed(intent: StringName) ## emitted for every intent, answered or not

@export var character: String = "" ## tells a retexture whether the face it's carrying is the one it should be showing

var current_intent: StringName = &"neutral" ## the baked baseline every part resolves to without authoring a reaction


func express(intent: StringName) -> void:
	current_intent = intent
	expression_changed.emit(intent)
