class_name StagePresenter extends Node

enum StageMode {MARCH, VN, HIDDEN}

var view: StageView
var current_mode: StageMode = StageMode.HIDDEN

func bind_view(v: StageView) -> void:
	view = v

func set_mode(mode: StageMode) -> void:
	if current_mode == mode:
		return
	current_mode = mode
	match mode:
		StageMode.MARCH:
			view.visible = true
			view.start_march()
		StageMode.VN:
			view.visible = true
			view.stop_march()
		StageMode.HIDDEN:
			view.visible = false
			view.stop_march()

#region March API

func start_march(squad: SquadStrategicData) -> void:
	view.spawn_warriors(squad.get_living_warriors())
	set_mode(StageMode.MARCH)

func stop_march() -> void:
	set_mode(StageMode.HIDDEN)

func refresh_warriors(squad: SquadStrategicData) -> void:
	view.spawn_warriors(squad.get_living_warriors())
	if current_mode == StageMode.MARCH:
		view.start_march()

#endregion

#region VN API

func prepare_for_dialogue(character_ids: Array[String]) -> void:
	set_mode(StageMode.VN)
	_arrange_for_conversation(character_ids)

func show_speech(character_id: String, speaker_name: String, text: String) -> SpeechBubble:
	var bubble = view.show_bubble(character_id, speaker_name, text)
	bubble.start_typewriter()
	var rig = view.get_rig(character_id)
	if rig:
		rig.play_behavior(AnimTypes.Behavior.TALKING)
	return bubble

func dismiss_speech(character_id: String) -> void:
	for bubble in view.bubbles.duplicate():
		if bubble.target_character_id == character_id:
			view.dismiss_bubble(bubble)
	var rig = view.get_rig(character_id)
	if rig:
		rig.play_behavior(AnimTypes.Behavior.IDLE)

func dismiss_all_speech() -> void:
	view.dismiss_all_bubbles()
	view.set_all_behavior(AnimTypes.Behavior.IDLE)

func focus_speaker(character_id: String) -> void:
	await view.focus_camera_on(character_id, 1.8, 0.4)

func focus_conversation(character_ids: Array[String]) -> void:
	await view.focus_camera_between(character_ids, 0.4)

func return_to_wide() -> void:
	await view.reset_camera(0.4)

func walk_character(character_id: String, target: Vector2) -> void:
	var rig = view.get_rig(character_id)
	if not rig:
		return
	rig.play_behavior(AnimTypes.Behavior.WALKING)
	var tween = create_tween()
	tween.tween_property(rig, "position", target, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	rig.play_behavior(AnimTypes.Behavior.IDLE)

func set_character_facing(character_id: String, direction: int) -> void:
	var rig = view.get_rig(character_id)
	if not rig:
		return
	rig.scale.x = direction

func set_character_behavior(character_id: String, behavior: AnimTypes.Behavior) -> void:
	var rig = view.get_rig(character_id)
	if not rig:
		return
	rig.play_behavior(behavior)

#endregion

func _arrange_for_conversation(character_ids: Array[String]) -> void:
	var spread = 150.0
	var count = character_ids.size()
	for i in count:
		var rig = view.get_rig(character_ids[i])
		if not rig:
			continue
		var target_x = (i - (count - 1) * 0.5) * spread
		var target_y = 50.0
		var tween = create_tween()
		tween.tween_property(rig, "position", Vector2(target_x, target_y), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		if i < count - 1:
			rig.scale.x = 1
		else:
			rig.scale.x = -1

func spawn_npc_rig(character_id: String) -> void:
	if view.rigs.has(character_id):
		return
	var rig = WarriorRigFactory.create_rig_for_npc(character_id)
	view.warrior_container.add_child(rig)
	rig.position = Vector2(300, 50)
	view.rigs[character_id] = rig
