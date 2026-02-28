extends CinematicInstruction

class_name GateInstruction

## A control gate in the timeline. When the time cursor reaches a gate, the
## timeline pauses and waits for player input (SPACE / click) to continue.
##
## If the player clicks before reaching a gate, the timeline fast-forwards
## (5x speed on timer + typewriters) until this gate, then pauses.
##
## When wait_for_typewriter is true, the gate waits for all active typewriters
## to finish before allowing the player to advance. This preserves the classic
## "click after text finishes" behavior for simple dialogue chains.

## If true, gate won't activate until all active typewriters finish.
@export var wait_for_typewriter: bool = true


func _init(config: Dictionary = { }) -> void:
	super(config)
	if config.is_empty():
		return
	wait_for_typewriter = config.get("wait_for_typewriter", true)
