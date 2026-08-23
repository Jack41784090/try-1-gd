extends CinematicInstruction

class_name CameraInstruction

## Multiple CameraInstructions at the same timestamp compose naturally (e.g. clear includes + start a pan simultaneously).

enum Action {
	FOCUS_CHARACTER, ## Zoom onto a specific character
	INCLUDE_CHARACTERS, ## Auto-frame to keep listed characters visible (empty = free camera)
	MOVE, ## Relative pixel offset over duration
	ZOOM, ## Set zoom level over duration
	RESET, ## Return to default wide view
}

@export var action: Action = Action.FOCUS_CHARACTER

@export var target_character_id: String = ""

@export var include_character_ids: Array[String] = []

@export var move_offset: Vector2 = Vector2.ZERO

@export var zoom_level: float = 1.0

## Normalized screen fraction (0=left, 1=right) the camera pans target_character_id to; -1 = not set.
@export var target_screen_position: float = -1.0


func _init(config: Dictionary = {}) -> void:
	super (config)
	if config.is_empty():
		return

	var action_str: String = config.get("action", "focus_character")
	match action_str:
		"focus_character":
			action = Action.FOCUS_CHARACTER
		"include_characters":
			action = Action.INCLUDE_CHARACTERS
		"move":
			action = Action.MOVE
		"zoom":
			action = Action.ZOOM
		"reset":
			action = Action.RESET

	target_character_id = config.get("target_character_id", "")

	var ids = config.get("include_character_ids", [])
	if ids is Array:
		for id in ids:
			if id is String:
				include_character_ids.append(id)

	var offset = config.get("move_offset", null)
	if offset is Vector2:
		move_offset = offset
	elif offset is Dictionary:
		move_offset = Vector2(offset.get("x", 0.0), offset.get("y", 0.0))

	zoom_level = config.get("zoom_level", 1.0)
	target_screen_position = config.get("target_screen_position", -1.0)
