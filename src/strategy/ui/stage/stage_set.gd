class_name StageSet
extends Resource
## Static set dressing for a scene: a backdrop plus a list of props. Applied once
## by StageView.apply_stage_set(); cutscenes can still mutate props afterward via
## SceneryInstruction. Round-trips as a standalone .tres.

@export var backdrop_svg_path: String = ""
@export var backdrop_position: Vector2 = Vector2.ZERO
@export var backdrop_scale: float = 1.0
@export var backdrop_z: int = -100
## See StageProp.parallax. Backdrops typically sit below 1.0 to drift behind the action.
@export var backdrop_parallax: float = 1.0
@export var backdrop_svg_scale: float = 4.0
@export var props: Array[StageProp] = []
