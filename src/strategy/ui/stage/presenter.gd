class_name StagePresenter
extends Node
## Knows nothing about EventChains or timelines — only executes placement/camera/bubble commands sent by VnPresenter.

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

func start_march(squad: StrategySquad) -> void:
	view.spawn_warriors(squad.get_living_warriors())
	set_mode(StageMode.MARCH)


func stop_march() -> void:
	set_mode(StageMode.HIDDEN)


func refresh_warriors(squad: StrategySquad) -> void:
	view.spawn_warriors(squad.get_living_warriors())
	if current_mode == StageMode.MARCH:
		view.start_march()

#endregion

#region VN API

func set_background(texture: Texture2D) -> void:
	view.set_background(texture)

#region Scenery passthrough

func apply_stage_set(stage_set: StageSet) -> void:
	view.apply_stage_set(stage_set)


func clear_scenery() -> void:
	view.clear_scenery()


func add_prop(prop: StageProp) -> void:
	view.add_prop(prop)


func remove_prop(prop_id: String) -> void:
	view.remove_prop(prop_id)


func move_prop(prop_id: String, target: Vector2, duration: float) -> void:
	view.move_prop(prop_id, target, duration)


func modulate_prop(prop_id: String, color: Color, duration: float) -> void:
	view.modulate_prop(prop_id, color, duration)


func set_prop_visible(prop_id: String, is_visible: bool) -> void:
	view.set_prop_visible(prop_id, is_visible)


func set_backdrop(svg_path: String, position: Vector2, scale: float, z: int, parallax: float, svg_scale: float = 4.0) -> void:
	view.set_backdrop(svg_path, position, scale, z, parallax, svg_scale)

#endregion


func prepare_for_dialogue(_character_ids: Array[String]) -> void:
	set_mode(StageMode.VN)


func apply_setting(positions: Array[StagePosition]) -> void:
	for pos in positions:
		var resolved_pos = pos.position
		if pos.anchor != CharacterInstruction.StageAnchor.NONE:
			resolved_pos = view.resolve_anchor(pos.anchor) + pos.anchor_offset
		place_character(pos.character_id, resolved_pos, pos.face_direction)
		if not pos.visible_on_start:
			hide_character(pos.character_id)


func place_character(character_id: String, target_position: Vector2, face_dir: int = 1) -> void:
	var rig = view.get_rig(character_id)
	if not rig:
		return
	rig.position = target_position
	rig.scale.x = face_dir


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
	view.reset_talking_to_idle()


func focus_speaker(character_id: String, zoom_val: float = 1.8, duration: float = 0.4) -> void:
	view.focus_camera_on(character_id, zoom_val, duration)


func focus_conversation(character_ids: Array[String]) -> void:
	view.focus_camera_between(character_ids, 0.4)


func return_to_wide() -> void:
	view.reset_camera(0.4)


func set_camera_include(character_ids: Array[String], duration: float = 0.4) -> void:
	view.set_camera_include(character_ids, duration)


func move_camera(offset: Vector2, duration: float) -> void:
	view.move_camera(offset, duration)


func zoom_camera(zoom_level: float, duration: float) -> void:
	view.zoom_camera(zoom_level, duration)


func walk_character(character_id: String, target: Vector2, duration: float = 0.8) -> void:
	var rig = view.get_rig(character_id)
	if not rig:
		return

	if duration <= 0.0:
		rig.position = target
		return

	rig.play_behavior(AnimTypes.Behavior.WALKING)
	var tween = create_tween()
	tween.tween_property(rig, "position", target, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void: rig.play_behavior(AnimTypes.Behavior.IDLE))


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


func set_character_expression(character_id: String, expression_id: String) -> void:
	var rig = view.get_rig(character_id)
	if not rig:
		return
	rig.set_expression_by_name(expression_id)


func show_character(character_id: String) -> void:
	var rig = view.get_rig(character_id)
	if not rig:
		return
	rig.visible = true


func hide_character(character_id: String) -> void:
	var rig = view.get_rig(character_id)
	if not rig:
		return
	rig.visible = false


func pan_to_character_at_screen_position(character_id: String, screen_fraction: float, duration: float) -> void:
	var rig = view.get_rig(character_id)
	if not rig:
		return
	view.stage_camera.pan_to_world_at_screen_fraction(rig.global_position, screen_fraction, duration)

#endregion

func spawn_npc_rig(character_id: String) -> void:
	if view.rigs.has(character_id):
		return
	var rig = WarriorRigFactory.create_rig_for_npc(character_id)
	view.warrior_container.add_child(rig)
	rig.position = Vector2(300, 50)
	view.rigs[character_id] = rig
