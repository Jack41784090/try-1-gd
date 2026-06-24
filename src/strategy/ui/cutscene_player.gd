class_name CutscenePlayer extends Control
## Bundles the StageView (the theater) and VnView (the director UI) into one
## reusable scene and self-wires the VnPresenter to the StagePresenter.
##
## Consumers instance ONE node (cutscene_player.tscn) to get a fully-wired
## cutscene player — no need to fetch and cross-connect the two presenters by
## hand. Read access to the inner views/presenters is exposed for callers that
## still need to drive playback (e.g. the cutscene_test harness, StrategyView).

@onready var stage_view: StageView = $StageView
@onready var vn_view: VnView = $VnLayer/VnView

var stage_presenter: StagePresenter:
	get: return stage_view.presenter

var vn_presenter: VnPresenter:
	get: return vn_view.presenter


func _ready() -> void:
	vn_presenter.stage_presenter = stage_presenter
