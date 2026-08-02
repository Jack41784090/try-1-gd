@tool
class_name Face extends Node2D

## Broadcasts what the character means; the parts below decide what it looks like.
##
## The Face holds no table of expressions and knows nothing about what any intent
## stands for. It announces one, and every FaceComponent in its subtree answers
## for itself — brows tilt, pupils shrink, lashes swap art — each from its own
## authored FaceReaction list. A part that has nothing to say about an intent
## stays put, and a character whose rig never composed that part in the first
## place has nothing listening at all. Missing features cost no special case.

## Emitted for every intent, answered or not. StringName so cinematic
## instructions and demos can name intents as plain text.
signal expression_changed(intent: StringName)

## The character these parts were baked from. Every rig currently shares one
## scene, so this is what tells a retexture whether the face it's carrying is the
## one it should be showing.
@export var character: String = ""

## The last intent broadcast. &"neutral" is the baked baseline, which every part
## resolves to without authoring a reaction for it.
var current_intent: StringName = &"neutral"


func express(intent: StringName) -> void:
	current_intent = intent
	expression_changed.emit(intent)
