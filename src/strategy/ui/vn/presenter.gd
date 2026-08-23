class_name VnPresenter extends Node
## The director: reads EventChain timelines/groups and issues commands to StagePresenter, the theater that executes them.

var _DEBUG: bool = true

var view: VnView
var stage_presenter: StagePresenter

var event_chain_queue: Array[String] = []
var is_playing_chain: bool = false
var current_chain: EventChain
var character_ids_in_chain: Array[String] = []

var _playback: GroupPlayback = GroupPlayback.new()
var _debug_chain_pending: bool = false


func _ready() -> void:
	_playback.instruction_fired.connect(_on_instruction_fired)
	_playback.timeline_complete.connect(_on_timeline_complete)


func _process(delta: float) -> void:
	_playback.process(delta)


func bind_view(v: VnView) -> void:
	view = v


func set_stage_presenter(sp: StagePresenter) -> void:
	stage_presenter = sp

#region Queue Management

func queue_event_chain(chain_path: String) -> void:
	event_chain_queue.append(chain_path)
	MyLog.debug("VnPresenter", "Queued event chain: %s (queue size: %d)" % [chain_path, event_chain_queue.size()])


func play_next_queued_chain() -> bool:
	var empty = event_chain_queue.is_empty()
	if empty:
		return true

	is_playing_chain = true
	var path: String = event_chain_queue.pop_front()
	var chain: EventChain
	if path.ends_with(".json"):
		chain = EventChain.load_from_json_file(path)
	else:
		chain = load(path)
	assert(chain != null, "EventChain resource failed to load: %s" % path)

	if _DEBUG:
		print("[VnPresenter] DEBUG skip: '%s' (%d instructions)" % [chain.chain_id, chain.get_instruction_count()])
		var debug_msg = "This is \"%s\" and is skipped for now because of _DEBUG mode." % chain.chain_id
		view.setup_narrator_typewriter("DEBUG", debug_msg)
		view.set_narrator_visible_characters(-1)
		view.advance_prompt.text = "Click to continue"
		view.advance_prompt.visible = true
		_debug_chain_pending = true
		return false

	print(
		"[VnPresenter] Playing EventChain: %s (%d instructions, %d dialogues)" % [
			chain.chain_id,
			chain.get_instruction_count(),
			chain.get_dialogue_count(),
		],
	)
	load_chain(chain)
	return false


func has_chain() -> bool:
	return current_chain != null


func peek_next_transition_type() -> EventChain.TransitionType:
	if event_chain_queue.is_empty():
		return EventChain.TransitionType.QUICK
	var path: String = event_chain_queue[0]
	var chain: EventChain
	if path.ends_with(".json"):
		chain = EventChain.load_from_json_file(path)
	else:
		chain = load(path)
	if chain:
		return chain.transition_type
	return EventChain.TransitionType.QUICK

#endregion

#region Input

func on_advance() -> void:
	if _debug_chain_pending:
		_debug_chain_pending = false
		is_playing_chain = false
		view.hide_narrator_box()
		view.chain_completed.emit()
		return
	_playback.on_input()

#endregion

#region Chain Loading

func load_chain(chain: EventChain) -> bool:
	assert(chain != null, "Cannot load null EventChain")
	if chain.timeline.is_empty() and not chain.has_root_group():
		push_warning("EventChain '%s' has empty timeline, completing immediately" % chain.chain_id)
		current_chain = null
		view.chain_completed.emit()
		return false
	chain.resolve_after_ids()
	current_chain = chain
	character_ids_in_chain = chain.get_all_character_ids()
	_playback.reset()
	print("[VnPresenter] Loaded chain '%s'" % chain.chain_id)

	if stage_presenter:
		var _rigs_chain = current_chain
		var _rigs_stage_view = stage_presenter.view
		for char_id in _rigs_chain.character_ids:
			if not char_id.is_empty() and not _rigs_stage_view.rigs.has(char_id):
				_rigs_stage_view.presenter.spawn_npc_rig(char_id)
				print("[VnPresenter] Spawned NPC rig for: %s" % char_id)
		stage_presenter.prepare_for_dialogue(character_ids_in_chain)
		if not chain.setting.is_empty():
			stage_presenter.apply_setting(chain.setting)

	if chain.has_root_group():
		_playback.load_group(chain.root_group)
	else:
		var typed_timeline: Array[CinematicInstruction] = []
		for inst in chain.timeline:
			if inst is CinematicInstruction:
				typed_timeline.append(inst)
		_playback.load_timeline(typed_timeline)
	return true

#endregion

#region Instruction Dispatch

func _on_instruction_fired(instruction: CinematicInstruction) -> void:
	if instruction is DialogueInstruction:
		print(
			"[VnPresenter] Dialogue — %s: \"%s\"" % [
				instruction.speaker_name if not instruction.speaker_name.is_empty() else "(narrator)",
				instruction.line_spoken.left(50),
			],
		)

		if not instruction.keep_previous_bubbles:
			if stage_presenter:
				stage_presenter.dismiss_all_speech()
			view.hide_narrator_box()

		var speaker_id: String = ""
		if not (instruction.speaker_name.is_empty() or instruction.speaker_name == "narrator"):
			speaker_id = instruction.speaker_name
			for _sid_char_id in character_ids_in_chain:
				if _sid_char_id == instruction.speaker_name or _sid_char_id.to_lower() == instruction.speaker_name.to_lower():
					speaker_id = _sid_char_id
					break
		var is_narrator = speaker_id.is_empty() or instruction.speaker_name.is_empty() or instruction.speaker_name == "narrator"
		var stage_view: StageView = null
		if stage_presenter:
			stage_view = stage_presenter.view as StageView
		var has_stage_rig = not is_narrator and stage_view and stage_view.get_rig(speaker_id) != null

		if has_stage_rig:
			if not instruction.expression_override.is_empty():
				stage_presenter.set_character_expression(speaker_id, instruction.expression_override)

			var bubble = stage_presenter.show_speech(speaker_id, instruction.speaker_name, instruction.line_spoken)
			if bubble:
				_playback.register_bubble(bubble)
		else:
			view.setup_narrator_typewriter(instruction.speaker_name, instruction.line_spoken)
			_playback.start_narrator(instruction.line_spoken, view.set_narrator_visible_characters)
	elif instruction is CameraInstruction:
		if stage_presenter:
			var ids: Array[String] = instruction.include_character_ids.duplicate()
			if not instruction.target_character_id.is_empty() and not ids.has(instruction.target_character_id):
				ids.append(instruction.target_character_id)

			if not ids.is_empty():
				MyLog.info("VnPresenter", "Camera → include %s" % [str(ids)])
				stage_presenter.set_camera_include(ids, maxf(instruction.duration, 0.4))

			if instruction.zoom_level != 1.0 and ids.is_empty():
				MyLog.info("VnPresenter", "Camera → zoom %.1f over %.1fs" % [instruction.zoom_level, instruction.duration])
				stage_presenter.zoom_camera(instruction.zoom_level, maxf(instruction.duration, 0.01))

			if instruction.action == CameraInstruction.Action.RESET:
				MyLog.info("VnPresenter", "Camera → reset")
				stage_presenter.return_to_wide()

			if instruction.move_offset != Vector2.ZERO:
				MyLog.info("VnPresenter", "Camera → move %s over %.1fs" % [str(instruction.move_offset), instruction.duration])
				stage_presenter.move_camera(instruction.move_offset, maxf(instruction.duration, 0.01))

			if instruction.target_screen_position >= 0.0 and not instruction.target_character_id.is_empty():
				MyLog.info("VnPresenter", "Camera → pan to %s at screen %.1f" % [instruction.target_character_id, instruction.target_screen_position])
				stage_presenter.pan_to_character_at_screen_position(instruction.target_character_id, instruction.target_screen_position, maxf(instruction.duration, 0.4))
	elif instruction is CharacterInstruction:
		if stage_presenter:
			match instruction.action:
				CharacterInstruction.Action.MOVE:
					print("[VnPresenter] Character %s → move to %s" % [instruction.character_id, str(instruction.target_position)])
					stage_presenter.walk_character(instruction.character_id, instruction.target_position, maxf(instruction.duration, 0.8))
				CharacterInstruction.Action.FACE:
					print("[VnPresenter] Character %s → face %d" % [instruction.character_id, instruction.face_direction])
					stage_presenter.set_character_facing(instruction.character_id, instruction.face_direction)
				CharacterInstruction.Action.BEHAVIOR:
					print("[VnPresenter] Character %s → behavior '%s'" % [instruction.character_id, instruction.behavior])
					var anim = GroupPlayback.BEHAVIOR_MAP.get(instruction.behavior.to_lower())
					if anim != null:
						stage_presenter.set_character_behavior(instruction.character_id, anim)
				CharacterInstruction.Action.SPAWN:
					print("[VnPresenter] Character %s → spawn at %s" % [instruction.character_id, str(instruction.target_position)])
					stage_presenter.spawn_npc_rig(instruction.character_id)
					stage_presenter.place_character(instruction.character_id, instruction.target_position, instruction.face_direction)
				CharacterInstruction.Action.SHOW:
					print("[VnPresenter] Character %s → show" % instruction.character_id)
					stage_presenter.show_character(instruction.character_id)
				CharacterInstruction.Action.HIDE:
					print("[VnPresenter] Character %s → hide" % instruction.character_id)
					stage_presenter.hide_character(instruction.character_id)
				CharacterInstruction.Action.EXPRESSION:
					print("[VnPresenter] Character %s → expression '%s'" % [instruction.character_id, instruction.expression])
					stage_presenter.set_character_expression(instruction.character_id, instruction.expression)
	elif instruction is SceneryInstruction:
		if stage_presenter:
			match instruction.action:
				SceneryInstruction.Action.ADD:
					var prop := StageProp.new()
					prop.prop_id = instruction.prop_id
					prop.svg_path = instruction.svg_path
					prop.position = instruction.position
					prop.scale = instruction.scale
					prop.z_index = instruction.z_index
					prop.flip_h = instruction.flip_h
					prop.parallax = instruction.parallax
					prop.svg_scale = instruction.svg_scale
					prop.modulate = instruction.modulate_color
					print("[VnPresenter] Scenery %s → add" % instruction.prop_id)
					stage_presenter.add_prop(prop)
				SceneryInstruction.Action.REMOVE:
					print("[VnPresenter] Scenery %s → remove" % instruction.prop_id)
					stage_presenter.remove_prop(instruction.prop_id)
				SceneryInstruction.Action.MOVE:
					print("[VnPresenter] Scenery %s → move to %s" % [instruction.prop_id, str(instruction.position)])
					stage_presenter.move_prop(instruction.prop_id, instruction.position, maxf(instruction.duration, 0.01))
				SceneryInstruction.Action.MODULATE:
					print("[VnPresenter] Scenery %s → modulate %s" % [instruction.prop_id, str(instruction.modulate_color)])
					stage_presenter.modulate_prop(instruction.prop_id, instruction.modulate_color, maxf(instruction.duration, 0.01))
				SceneryInstruction.Action.SHOW:
					stage_presenter.set_prop_visible(instruction.prop_id, true)
				SceneryInstruction.Action.HIDE:
					stage_presenter.set_prop_visible(instruction.prop_id, false)
				SceneryInstruction.Action.SET_BACKDROP:
					print("[VnPresenter] Scenery → set backdrop %s" % instruction.svg_path)
					stage_presenter.set_backdrop(instruction.svg_path, instruction.position, instruction.scale, instruction.z_index, instruction.parallax, instruction.svg_scale)

#endregion

#region Completion

func _on_timeline_complete() -> void:
	print("[VnPresenter] Chain '%s' complete" % current_chain.chain_id)
	if stage_presenter:
		stage_presenter.dismiss_all_speech()
	view.hide_narrator_box()
	
	if stage_presenter.view.stage_camera.tweening():
		## If camera is still tweening, delay completion signal until done to avoid jarring cuts
		var tween = stage_presenter.view.stage_camera._active_tween
		tween.tween_callback(func() -> void: view.chain_completed.emit())
	else: view.chain_completed.emit()
	current_chain = null
	character_ids_in_chain.clear()
	_playback.reset()

#endregion
