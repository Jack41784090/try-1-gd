extends Control

@onready var stage_view: StageView = $StageView

var _demo_warriors: Array[StrategyEntity] = []

func _ready() -> void:
	_create_demo_warriors()
	stage_view.spawn_warriors(_demo_warriors)
	stage_view.presenter.set_mode(StagePresenter.StageMode.MARCH)
	print("[StageDemo] Spawned %d warriors in march mode" % _demo_warriors.size())

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				stage_view.presenter.set_mode(StagePresenter.StageMode.MARCH)
				print("[StageDemo] Switched to MARCH mode")
			KEY_2:
				var ids: Array[String] = []
				for w in _demo_warriors:
					ids.append(w.id)
				stage_view.presenter.prepare_for_dialogue(ids)
				print("[StageDemo] Switched to VN mode")
			KEY_3:
				stage_view.presenter.set_mode(StagePresenter.StageMode.HIDDEN)
				print("[StageDemo] Switched to HIDDEN mode")
			KEY_SPACE:
				if stage_view.presenter.current_mode == StagePresenter.StageMode.VN:
					var speaker = _demo_warriors[randi() % _demo_warriors.size()]
					stage_view.presenter.dismiss_all_speech()
					stage_view.presenter.show_speech(speaker.id, speaker.name, "This is a test speech bubble from %s!" % speaker.name)
					print("[StageDemo] Showing speech bubble for %s" % speaker.name)
			KEY_C:
				if stage_view.presenter.current_mode == StagePresenter.StageMode.VN and not _demo_warriors.is_empty():
					var speaker = _demo_warriors[randi() % _demo_warriors.size()]
					stage_view.presenter.focus_speaker(speaker.id)
					print("[StageDemo] Camera focus on %s" % speaker.name)
			KEY_R:
				stage_view.presenter.return_to_wide()
				print("[StageDemo] Camera reset to wide")
			KEY_D:
				stage_view.presenter.dismiss_all_speech()
				print("[StageDemo] Dismissed all speech")

func _create_demo_warriors() -> void:
	var names = ["Faust", "Heinrich", "Elara", "Konrad"]
	var classes = [EntityClasses.Types.Landsknecht, EntityClasses.Types.Healer, EntityClasses.Types.Landsknecht, EntityClasses.Types.Healer]
	for i in names.size():
		var warrior = StrategyEntity.new()
		warrior.id = names[i].to_lower()
		warrior.name = names[i]
		warrior.class_id = classes[i]
		_demo_warriors.append(warrior)
