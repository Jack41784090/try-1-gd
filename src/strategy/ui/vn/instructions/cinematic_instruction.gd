extends Resource

class_name CinematicInstruction

## Base class for all timeline instructions in an EventChain.
## Each instruction fires at a specific point in the timeline and optionally
## takes a duration to complete (camera pans, character walks, etc.).

## Optional identifier so other instructions can reference this one via after_id.
@export var id: String = ""

## Absolute seconds from timeline start when this instruction fires.
@export var time: float = 0.0

## How long the action takes in seconds. 0 = instant.
@export var duration: float = 0.0

## If set, this instruction fires after the referenced instruction ends.
## The time field is overwritten during resolution: time = ref.time + ref.duration + after_offset.
@export var after_id: String = ""

## Additional delay in seconds after the referenced instruction ends.
@export var after_offset: float = 0.0


func _init(config: Dictionary = { }) -> void:
	if config.is_empty():
		return
	id = config.get("id", "")
	time = config.get("time", 0.0)
	duration = config.get("duration", 0.0)
	after_id = config.get("after_id", "")
	after_offset = config.get("after_offset", 0.0)


func has_after_dependency() -> bool:
	return not after_id.is_empty()
