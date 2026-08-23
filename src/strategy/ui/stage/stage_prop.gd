class_name StageProp
extends Resource
## A single piece of set dressing (tree, pillar, banner, map) rendered as a Sprite2D that pans/zooms with the camera.

@export var prop_id: String = ""
@export var svg_path: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var scale: float = 1.0
@export var z_index: int = 0
@export var flip_h: bool = false
@export var modulate: Color = Color.WHITE
## 1.0 = locked to world (moves with camera); lower drifts slower, reading as farther away; 0.0 = locked to screen.
@export var parallax: float = 1.0
## Rasterization scale for the SVG source.
@export var svg_scale: float = 4.0
