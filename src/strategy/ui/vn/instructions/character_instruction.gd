extends CinematicInstruction

class_name CharacterInstruction

## Character stage direction in the timeline. Replaces walk_to, face_direction,
## and behavior fields that were previously baked into Dialogue.

enum Action {
	MOVE, ## Walk character to a position over duration
	FACE, ## Change character facing direction (instant)
	BEHAVIOR, ## Play an animation behavior on the character
	SPAWN, ## Spawn an NPC rig at a position
	SHOW, ## Make character visible
	HIDE, ## Make character invisible
}

enum StageAnchor {
	NONE,
	OFFSCREEN_LEFT,
	OFFSCREEN_RIGHT,
	OFFSCREEN_TOP,
	OFFSCREEN_BOTTOM,
	CENTER,
	LEFT_QUARTER,
	RIGHT_QUARTER,
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

## Named anchor for position resolution. Overrides raw target_position when set.
@export var anchor: StageAnchor = StageAnchor.NONE

## Offset from the anchor position.
@export var anchor_offset: Vector2 = Vector2.ZERO


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
		"show":
			action = Action.SHOW
		"hide":
			action = Action.HIDE

	character_id = config.get("character_id", "")

	var pos = config.get("target_position", null)
	if pos is Vector2:
		target_position = pos
	elif pos is Dictionary:
		target_position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
	elif pos is Array and pos.size() >= 2:
		target_position = Vector2(float(pos[0]), float(pos[1]))

	face_direction = config.get("face_direction", 1)
	behavior = config.get("behavior", "")

	var anchor_str: String = config.get("anchor", "")
	if not anchor_str.is_empty():
		anchor = _parse_anchor(anchor_str)

	var ao = config.get("anchor_offset", null)
	if ao is Array and ao.size() >= 2:
		anchor_offset = Vector2(float(ao[0]), float(ao[1]))
	elif ao is Dictionary:
		anchor_offset = Vector2(ao.get("x", 0.0), ao.get("y", 0.0))


static func _parse_anchor(s: String) -> StageAnchor:
	match s.to_upper():
		"OFFSCREEN_LEFT":
			return StageAnchor.OFFSCREEN_LEFT
		"OFFSCREEN_RIGHT":
			return StageAnchor.OFFSCREEN_RIGHT
		"OFFSCREEN_TOP":
			return StageAnchor.OFFSCREEN_TOP
		"OFFSCREEN_BOTTOM":
			return StageAnchor.OFFSCREEN_BOTTOM
		"CENTER":
			return StageAnchor.CENTER
		"LEFT_QUARTER":
			return StageAnchor.LEFT_QUARTER
		"RIGHT_QUARTER":
			return StageAnchor.RIGHT_QUARTER
		_:
			return StageAnchor.NONE
