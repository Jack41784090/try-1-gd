extends CinematicInstruction

class_name CharacterInstruction

## Character stage direction in the timeline. Replaces walk_to, face_direction,
## and behavior fields that were previously baked into Dialogue.

enum Action {
	MOVE, ## Walk character to a position over duration
	FACE, ## Change character facing direction (instant)
	BEHAVIOR, ## Play an animation behavior on the character
	SPAWN, ## Spawn an NPC rig at a position
}

@export var action: Action = Action.MOVE

## Which character this instruction targets.
@export var character_id: String = ""

## Target position for MOVE / SPAWN.
@export var target_position: Vector2 = Vector2.ZERO

## Facing direction for FACE: -1 = left, 1 = right.
@export_range(-1, 1) var face_direction: int = 1

## Animation behavior name for BEHAVIOR action.
## Valid: idle, walking, attacking, defending, hurt, dying, talking, gesturing
@export var behavior: String = ""


func _init(config: Dictionary = { }) -> void:
	super(config)
	if config.is_empty():
		return

	var action_str: String = config.get("action", "move")
	match action_str:
		"move":
			action = Action.MOVE
		"face":
			action = Action.FACE
		"behavior":
			action = Action.BEHAVIOR
		"spawn":
			action = Action.SPAWN

	character_id = config.get("character_id", "")

	var pos = config.get("target_position", null)
	if pos is Vector2:
		target_position = pos
	elif pos is Dictionary:
		target_position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))

	face_direction = config.get("face_direction", 1)
	behavior = config.get("behavior", "")
