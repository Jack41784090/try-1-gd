class_name VnPresenter
extends Node
## Timeline-driven VN playback engine.
## Reads EventChain timelines, dispatches CinematicInstructions to the Stage,
## manages player interaction gates and speed control via TimelinePlayback.
##
## Roles:
##   VnPresenter = the director (reads timelines, issues commands)
##   StagePresenter = the theater (executes visual commands, knows nothing about timelines)

var view: VnView
var stage_presenter: StagePresenter

var event_chain_queue: Array = []
var is_playing_chain: bool = false
var current_chain: EventChain
var character_ids_in_chain: Array[String] = []

var _playback: TimelinePlayback = TimelinePlayback.new()


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
	print("[VnPresenter] Queued event chain: %s (queue size: %d)" % [chain_path, event_chain_queue.size()])


func play_next_queued_chain() -> bool:
	var empty = event_chain_queue.is_empty()
	if not empty:
		is_playing_chain = true
		var path: String = event_chain_queue.pop_front()
		var chain = load(path)
		assert(chain != null, "EventChain resource failed to load: %s" % path)
		print(
			"[VnPresenter] Playing EventChain: %s (%d instructions, %d dialogues)" % [
				chain.chain_id,
				chain.get_instruction_count(),
				chain.get_dialogue_count(),
			],
		)
		_load_chain(chain)
	return empty


func has_chain() -> bool:
	return current_chain != null

#endregion

#region Input

func on_advance() -> void:
	_playback.on_input()

#endregion

#region Chain Loading

func _load_chain(chain: EventChain) -> bool:
	if not chain:
		push_error("Cannot load null EventChain")
		return false
	if chain.timeline.is_empty():
		push_warning("EventChain '%s' has empty timeline, completing immediately" % chain.chain_id)
		current_chain = null
		view.chain_completed.emit()
		return false
	current_chain = chain
	character_ids_in_chain = chain.get_all_character_ids()
	_playback.reset()
	print("[VnPresenter] Loaded chain '%s' with %d instructions" % [chain.chain_id, chain.timeline.size()])

	if stage_presenter:
		_ensure_npc_rigs()
		stage_presenter.prepare_for_dialogue(character_ids_in_chain)
		if not chain.setting.is_empty():
			stage_presenter.apply_setting(chain.setting)

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
		_execute_dialogue(instruction)
	elif instruction is CameraInstruction:
		_execute_camera(instruction)
	elif instruction is CharacterInstruction:
		_execute_character(instruction)


func _execute_dialogue(inst: DialogueInstruction) -> void:
	print(
		"[VnPresenter] Dialogue — %s: \"%s\"" % [
			inst.speaker_name if not inst.speaker_name.is_empty() else "(narrator)",
			inst.line_spoken.left(50),
		],
	)

	if not inst.keep_previous_bubbles:
		if stage_presenter:
			stage_presenter.dismiss_all_speech()
		view.hide_narrator_box()

	var speaker_id = _resolve_speaker_id(inst.speaker_name)
	var is_narrator = speaker_id.is_empty() or inst.speaker_name.is_empty() or inst.speaker_name == "narrator"
	var has_stage_rig = not is_narrator and stage_presenter and stage_presenter.view.get_rig(speaker_id) != null

	if has_stage_rig:
		if not inst.expression_override.is_empty():
			var anim = TimelinePlayback.BEHAVIOR_MAP.get(inst.expression_override.to_lower())
			if anim != null:
				stage_presenter.set_character_behavior(speaker_id, anim)

		var bubble = stage_presenter.show_speech(speaker_id, inst.speaker_name, inst.line_spoken)
		if bubble:
			_playback.register_bubble(bubble)
	else:
		view.setup_narrator_typewriter(inst.speaker_name, inst.line_spoken)
		_playback.start_narrator(inst.line_spoken, view.set_narrator_visible_characters)


func _execute_camera(inst: CameraInstruction) -> void:
	if not stage_presenter:
		return
	match inst.action:
		CameraInstruction.Action.FOCUS_CHARACTER:
			print("[VnPresenter] Camera → focus %s (zoom %.1f)" % [inst.target_character_id, inst.zoom_level])
			stage_presenter.focus_speaker(inst.target_character_id, inst.zoom_level, inst.duration)
		CameraInstruction.Action.INCLUDE_CHARACTERS:
			print("[VnPresenter] Camera → include %s" % [str(inst.include_character_ids)])
			stage_presenter.set_camera_include(inst.include_character_ids, inst.duration)
		CameraInstruction.Action.MOVE:
			print("[VnPresenter] Camera → move %s over %.1fs" % [str(inst.move_offset), inst.duration])
			stage_presenter.move_camera(inst.move_offset, maxf(inst.duration, 0.01))
		CameraInstruction.Action.ZOOM:
			print("[VnPresenter] Camera → zoom %.1f over %.1fs" % [inst.zoom_level, inst.duration])
			stage_presenter.zoom_camera(inst.zoom_level, maxf(inst.duration, 0.01))
		CameraInstruction.Action.RESET:
			print("[VnPresenter] Camera → reset")
			stage_presenter.return_to_wide()


func _execute_character(inst: CharacterInstruction) -> void:
	if not stage_presenter:
		return
	match inst.action:
		CharacterInstruction.Action.MOVE:
			print("[VnPresenter] Character %s → move to %s" % [inst.character_id, str(inst.target_position)])
			stage_presenter.walk_character(inst.character_id, inst.target_position, maxf(inst.duration, 0.8))
		CharacterInstruction.Action.FACE:
			print("[VnPresenter] Character %s → face %d" % [inst.character_id, inst.face_direction])
			stage_presenter.set_character_facing(inst.character_id, inst.face_direction)
		CharacterInstruction.Action.BEHAVIOR:
			print("[VnPresenter] Character %s → behavior '%s'" % [inst.character_id, inst.behavior])
			var anim = TimelinePlayback.BEHAVIOR_MAP.get(inst.behavior.to_lower())
			if anim != null:
				stage_presenter.set_character_behavior(inst.character_id, anim)
		CharacterInstruction.Action.SPAWN:
			print("[VnPresenter] Character %s → spawn at %s" % [inst.character_id, str(inst.target_position)])
			stage_presenter.spawn_npc_rig(inst.character_id)
			stage_presenter.place_character(inst.character_id, inst.target_position, inst.face_direction)

#endregion

#region Completion

func _on_timeline_complete() -> void:
	print("[VnPresenter] Chain '%s' complete" % current_chain.chain_id)
	if stage_presenter:
		stage_presenter.dismiss_all_speech()
		stage_presenter.return_to_wide()
	view.hide_narrator_box()
	view.chain_completed.emit()
	_reset()

#endregion

#region Helpers

func _resolve_speaker_id(speaker_name: String) -> String:
	if speaker_name.is_empty() or speaker_name == "narrator":
		return ""
	for char_id in character_ids_in_chain:
		if char_id == speaker_name or char_id.to_lower() == speaker_name.to_lower():
			return char_id
	return speaker_name


func _reset() -> void:
	current_chain = null
	character_ids_in_chain.clear()
	_playback.reset()


func _ensure_npc_rigs() -> void:
	if not stage_presenter:
		return
	for char_id in character_ids_in_chain:
		if char_id.is_empty() or char_id == "narrator":
			continue
		if not stage_presenter.view.rigs.has(char_id):
			stage_presenter.spawn_npc_rig(char_id)

#endregion
