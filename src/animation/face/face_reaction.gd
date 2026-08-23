class_name FaceReaction extends Resource

## Deltas are measured from the part's baked baseline, never from whatever it happens to be showing, so switching between intents can't accumulate drift.
@export var intent: StringName = &""

@export var texture: Texture2D ## null leaves the current texture alone, so an intent can move a part without redrawing it

@export var position_delta: Vector2 = Vector2.ZERO
@export var rotation_delta: float = 0.0
## Multiplied onto the baseline scale, so Vector2.ONE is "unchanged".
@export var scale_delta: Vector2 = Vector2.ONE
## Seconds to ease over. Zero snaps.
@export var blend_time: float = 0.0
