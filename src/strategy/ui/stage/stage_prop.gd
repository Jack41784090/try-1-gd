class_name StageProp
extends Resource
## A single piece of set dressing placed in the stage's world space (a tree, a
## pillar, a banner, the great map). Rendered as a Sprite2D in StageView's Scenery
## layer; pans/zooms with the camera. Lower `parallax` makes it read as farther away.

@export var prop_id: String = ""
@export var svg_path: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var scale: float = 1.0
@export var z_index: int = 0
@export var flip_h: bool = false
@export var modulate: Color = Color.WHITE
## 1.0 = locked to the world (moves 1:1 with the camera). < 1.0 = parallax: the
## prop drifts slower than the camera, reading as more distant. 0.0 = locked to screen.
@export var parallax: float = 1.0
## Rasterization scale for the SVG source.
@export var svg_scale: float = 4.0
