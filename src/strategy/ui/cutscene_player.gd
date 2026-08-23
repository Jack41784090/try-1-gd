class_name CutscenePlayer extends Control
## Self-wires VnPresenter to StagePresenter so consumers get one pre-wired node instead of cross-connecting both presenters by hand.

@onready var stage_view: StageView = $StageView
@onready var vn_view: VnView = $VnLayer/VnView

var stage_presenter: StagePresenter:
	get: return stage_view.presenter

var vn_presenter: VnPresenter:
	get: return vn_view.presenter


func _ready() -> void:
	vn_presenter.stage_presenter = stage_presenter
