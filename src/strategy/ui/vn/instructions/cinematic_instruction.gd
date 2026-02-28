extends Resource

class_name CinematicInstruction

## Base class for all timeline instructions in an EventChain.
## Each instruction fires at a specific point in the timeline and optionally
## takes a duration to complete (camera pans, character walks, etc.).

## Absolute seconds from timeline start when this instruction fires.
@export var time: float = 0.0

## How long the action takes in seconds. 0 = instant.
@export var duration: float = 0.0


func _init(config: Dictionary = { }) -> void:
	if config.is_empty():
		return
	time = config.get("time", 0.0)
	duration = config.get("duration", 0.0)
