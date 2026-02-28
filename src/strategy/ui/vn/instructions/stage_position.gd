extends Resource

class_name StagePosition

## Initial character position for an EventChain's setting.
## Read by the presenter to place characters before the timeline starts.

## Which character to place.
@export var character_id: String = ""

## Where on the stage to place them.
@export var position: Vector2 = Vector2.ZERO

## Initial facing: -1 = left, 1 = right.
@export_range(-1, 1) var face_direction: int = 1


func _init(p_id: String = "", p_pos: Vector2 = Vector2.ZERO, p_face: int = 1) -> void:
	character_id = p_id
	position = p_pos
	face_direction = p_face
