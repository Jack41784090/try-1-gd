class_name CinematicInstruction extends Resource

const SEQUENTIAL_CHILDREN: float = 0.0
const OCCUPATION_FILL: float = -2.0
const OCCUPATION_UNSET: float = -1.0

## Optional identifier so other instructions can reference this one via after_id.
@export var id: String = ""

## Absolute seconds from timeline start when this instruction fires.
@export var time: float = 0.0

## How long the action takes in seconds. 0 = instant.
@export var duration: float = 0.0

## If set, resolution overwrites time to ref.time + ref.duration + after_offset.
@export var after_id: String = ""

## Additional delay in seconds after the referenced instruction ends.
@export var after_offset: float = 0.0

## Fraction of parent group's duration this child occupies (parallel mode). -1 = unset, -2 = FILL (takes remaining time).
@export var occupation: float = OCCUPATION_UNSET


func _init(config: Dictionary = {}) -> void:
	if config.is_empty():
		return
	id = config.get("id", "")
	time = config.get("time", 0.0)
	duration = config.get("duration", 0.0)
	after_id = config.get("after_id", "")
	after_offset = config.get("after_offset", 0.0)
	occupation = config.get("occupation", OCCUPATION_UNSET)


func has_after_dependency() -> bool:
	return not after_id.is_empty()
