class_name SceneryInstruction
extends CinematicInstruction
## Fires through GroupPlayback's generic instruction path; dispatched by VnPresenter._execute_scenery onto the StagePresenter.

enum Action {ADD, REMOVE, MOVE, MODULATE, SHOW, HIDE, SET_BACKDROP}

@export var action: Action = Action.ADD
@export var prop_id: String = ""
@export var svg_path: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var scale: float = 1.0
@export var z_index: int = 0
@export var flip_h: bool = false
@export var parallax: float = 1.0
@export var svg_scale: float = 4.0
@export var modulate_color: Color = Color.WHITE


func _init(config: Dictionary = {}) -> void:
	super(config)
