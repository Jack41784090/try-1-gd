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

## Named anchor for position resolution.
var anchor: int = 0  # CharacterInstruction.StageAnchor.NONE

## Offset from anchor.
var anchor_offset: Vector2 = Vector2.ZERO

## Whether the character is initially visible.
var visible_on_start: bool = true


func _init(p_id: String = "", p_pos: Vector2 = Vector2.ZERO, p_face: int = 1) -> void:
	character_id = p_id
	position = p_pos
	face_direction = p_face


static func from_dict(data: Dictionary) -> StagePosition:
	var sp = StagePosition.new(
		data.get("character_id", ""),
		Vector2(data.get("x", 0.0), data.get("y", 0.0)),
		data.get("face_direction", 1),
	)
	sp.visible_on_start = data.get("visible", true)
	var anchor_str: String = data.get("anchor", "")
	if not anchor_str.is_empty():
		sp.anchor = CharacterInstruction._parse_anchor(anchor_str)
	var ao = data.get("anchor_offset", null)
	if ao is Array and ao.size() >= 2:
		sp.anchor_offset = Vector2(float(ao[0]), float(ao[1]))
	elif ao is Dictionary:
		sp.anchor_offset = Vector2(ao.get("x", 0.0), ao.get("y", 0.0))
	return sp
