class_name StagePresenter
extends Node
## The visual theater. Executes commands: place character, move camera, show bubble.
## Knows nothing about EventChains or timelines. Commanded by VnPresenter.

enum StageMode {MARCH, VN, HIDDEN}

var view: StageView
var current_mode: StageMode = StageMode.HIDDEN


func bind_view(v: StageView) -> void:
	view = v


func set_mode(mode: StageMode) -> void:
	# Transitions the stage between visual modes:
	# MARCH: warriors visible, walking animation loop running (strategy overworld)
	# VN: warriors visible, walking stopped (dialogue/cutscene scene)
	# HIDDEN: stage invisible (combat intermission or menu)
	# e.g., set_mode(VN) → stop march walk loop, keep warriors visible for dialogue
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

func start_march(squad: SquadData) -> void:
	# Spawns 2D warrior rigs for each living warrior and starts the march walking animation
	# Called on game start and when warriors change (recruitment, casualties)
	# e.g., squad has 3 living warriors → spawns 3 WarriorRig nodes → sets mode MARCH → rigs walk right
	view.spawn_warriors(squad.get_living_warriors())
	set_mode(StageMode.MARCH)


func stop_march() -> void:
	set_mode(StageMode.HIDDEN)


func refresh_warriors(squad: SquadData) -> void:
	view.spawn_warriors(squad.get_living_warriors())
	if current_mode == StageMode.MARCH:
		view.start_march()

#endregion

#region VN API

func set_background(texture: Texture2D) -> void:
	view.set_background(texture)


func prepare_for_dialogue(_character_ids: Array[String]) -> void:
	# Switches stage to VN mode for dialogue playback (stops march, keeps warriors visible)
	# Called by VnPresenter before loading a timeline
	# e.g., character_ids=["Hans", "Fritz"] → stage mode → VN (march stops)
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
	# Creates a speech bubble above a character rig and starts the typewriter animation
	# Also sets the character's rig to TALKING behavior
	# e.g., show_speech("Hans", "Hans", "Let's camp here") → bubble appears above Hans, text types out letter by letter
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
	# Tweens a character rig to a target position with WALKING animation, then returns to IDLE
	# e.g., walk_character("Hans", Vector2(400, 50), 1.0) → Hans plays WALKING, tweens over 1s, then IDLE
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
