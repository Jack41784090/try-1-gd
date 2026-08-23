extends CinematicInstruction

class_name GateInstruction

## Clicking before reaching a gate fast-forwards (5x) to it; wait_for_typewriter then holds until active typewriters finish before advancing.
@export var wait_for_typewriter: bool = true


func _init(config: Dictionary = { }) -> void:
	super(config)
	if config.is_empty():
		return
	wait_for_typewriter = config.get("wait_for_typewriter", true)
