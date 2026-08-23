@tool
class_name FaceComponent extends Sprite2D

## Nesting composes: an "eyes widen" reaction on White moves Pupil for free, then Pupil's own reaction layers a further delta on top. Reactions are always computed against the baseline captured at _ready(), so switching intents never drifts.

@export var reactions: Array[FaceReaction] = [] ## an intent with no entry here is ignored, not an error

var _baseline_position: Vector2
var _baseline_rotation: float
var _baseline_scale: Vector2
var _baseline_texture: Texture2D
var _tween: Tween


func _ready() -> void:
	_baseline_position = position
	_baseline_rotation = rotation
	_baseline_scale = scale
	_baseline_texture = texture
	## Checks for the signal rather than the Face class, so a part stays usable under any future broadcaster and one hung outside a Face simply never connects.
	var node := get_parent()
	while node:
		if node.has_signal(&"expression_changed"):
			node.expression_changed.connect(_on_expression_changed)
			return
		node = node.get_parent()


func _on_expression_changed(intent: StringName) -> void:
	var reaction: FaceReaction = null
	for candidate in reactions:
		if candidate and candidate.intent == intent:
			reaction = candidate
			break
	if reaction == null and intent != &"neutral":
		return

	var to_position := _baseline_position
	var to_rotation := _baseline_rotation
	var to_scale := _baseline_scale
	var blend := 0.0
	if reaction:
		to_position += reaction.position_delta
		to_rotation += reaction.rotation_delta
		to_scale *= reaction.scale_delta
		blend = reaction.blend_time
		if reaction.texture:
			texture = reaction.texture
	else:
		texture = _baseline_texture

	if _tween:
		_tween.kill()
	## Tweens need a running scene tree; editor preview and headless assertions both want the result immediately anyway.
	if blend <= 0.0 or Engine.is_editor_hint():
		position = to_position
		rotation = to_rotation
		scale = to_scale
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position", to_position, blend)
	_tween.tween_property(self, "rotation", to_rotation, blend)
	_tween.tween_property(self, "scale", to_scale, blend)
