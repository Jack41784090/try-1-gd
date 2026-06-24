class_name VnPresenter extends Node
## Group-driven VN playback engine.
## Reads EventChain timelines/groups, dispatches CinematicInstructions to the Stage,
## manages player interaction gates and speed control via GroupPlayback.
##
## Roles:
##   VnPresenter = the director (reads timelines, issues commands)
##   StagePresenter = the theater (executes visual commands, knows nothing about timelines)

var _DEBUG: bool = true # If true, skips timeline playback for easier debugging of timelines and stage presentation

var view: VnView
var stage_presenter: StagePresenter

var event_chain_queue: Array = []
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
	# Adds an EventChain resource path to the play queue (played FIFO by play_next_queued_chain)
	# e.g., queue_event_chain("res://resources/event_chains/camp_fire.tres") → queue=["camp_fire.tres"]
	event_chain_queue.append(chain_path)
	Log.debug("VnPresenter", "Queued event chain: %s (queue size: %d)" % [chain_path, event_chain_queue.size()])


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
	# Prepares an EventChain for playback:
	# 1. Stores chain reference and extracts character IDs
	# 2. Ensures NPC rigs exist in the stage for all characters
	# 3. Applies initial setting (character positions/facing)
	# 4. Loads the timeline into GroupPlayback which starts advancing the time cursor
	# e.g., chain "camp_fire" with setting=[{Hans, pos(100,50), face_right}, {Fritz, pos(300,50), face_left}]
	#   → spawns rigs → places characters → loads 5 instructions into playback → state=PLAYING
	if not chain:
		push_error("Cannot load null EventChain")
		return false
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
		_ensure_npc_rigs()
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
	# Dispatches a single CinematicInstruction to the appropriate handler
	# Called by GroupPlayback when the time cursor reaches an instruction's timestamp
	# e.g., DialogueInstruction(time=2.0, speaker="Hans", line="Let's camp here")
	#   → _execute_dialogue() → shows speech bubble + typewriter on Hans's rig
	# e.g., CameraInstruction(time=2.0, action=FOCUS_CHARACTER, target="Hans", zoom=1.8)
	#   → _execute_camera() → stage_presenter.focus_speaker("Hans", 1.8)
	if instruction is DialogueInstruction:
		_execute_dialogue(instruction)
	elif instruction is CameraInstruction:
		_execute_camera(instruction)
	elif instruction is CharacterInstruction:
		_execute_character(instruction)
	elif instruction is SceneryInstruction:
		_execute_scenery(instruction)


func _execute_dialogue(inst: DialogueInstruction) -> void:
	# Displays a dialogue line: either as a speech bubble on a character rig or as narrator text
	# Steps:
	#   1. If keep_previous_bubbles=false, dismiss existing bubbles and narrator box
	#   2. Resolve speaker_id from speaker_name (match against character_ids_in_chain)
	#   3. If speaker has a stage rig: show speech bubble with typewriter, set TALKING animation
	#   4. If narrator or no rig: show narrator box with typewriter text
	# e.g., DialogueInstruction(speaker="Hans", line="Let's camp here", keep_previous=false)
	#   → dismiss all → find Hans rig → show_speech("Hans", "Let's camp here") → Hans plays TALKING
	# e.g., DialogueInstruction(speaker="narrator", line="The sun was setting...")
	#   → no rig → show narrator box with typewriter
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
	var stage_view: StageView = null
	if stage_presenter:
		stage_view = stage_presenter.view as StageView
	var has_stage_rig = not is_narrator and stage_view and stage_view.get_rig(speaker_id) != null

	if has_stage_rig:
		if not inst.expression_override.is_empty():
			stage_presenter.set_character_expression(speaker_id, inst.expression_override)

		var bubble = stage_presenter.show_speech(speaker_id, inst.speaker_name, inst.line_spoken)
		if bubble:
			_playback.register_bubble(bubble)
	else:
		view.setup_narrator_typewriter(inst.speaker_name, inst.line_spoken)
		_playback.start_narrator(inst.line_spoken, view.set_narrator_visible_characters)


func _execute_camera(inst: CameraInstruction) -> void:
	if not stage_presenter:
		return

	var ids: Array[String] = inst.include_character_ids.duplicate()
	if not inst.target_character_id.is_empty() and not ids.has(inst.target_character_id):
		ids.append(inst.target_character_id)

	if not ids.is_empty():
		Log.info("VnPresenter", "Camera → include %s" % [str(ids)])
		stage_presenter.set_camera_include(ids, maxf(inst.duration, 0.4))

	if inst.zoom_level != 1.0 and ids.is_empty():
		Log.info("VnPresenter", "Camera → zoom %.1f over %.1fs" % [inst.zoom_level, inst.duration])
		stage_presenter.zoom_camera(inst.zoom_level, maxf(inst.duration, 0.01))

	if inst.action == CameraInstruction.Action.RESET:
		Log.info("VnPresenter", "Camera → reset")
		stage_presenter.return_to_wide()

	if inst.move_offset != Vector2.ZERO:
		Log.info("VnPresenter", "Camera → move %s over %.1fs" % [str(inst.move_offset), inst.duration])
		stage_presenter.move_camera(inst.move_offset, maxf(inst.duration, 0.01))

	if inst.target_screen_position >= 0.0 and not inst.target_character_id.is_empty():
		Log.info("VnPresenter", "Camera → pan to %s at screen %.1f" % [inst.target_character_id, inst.target_screen_position])
		stage_presenter.pan_to_character_at_screen_position(inst.target_character_id, inst.target_screen_position, maxf(inst.duration, 0.4))

func _execute_character(inst: CharacterInstruction) -> void:
	# Dispatches character movement/behavior commands to the stage presenter
	# e.g., MOVE("Hans", target=Vector2(400,50), duration=0.8) → Hans walks to new position over 0.8s
	# e.g., FACE("Fritz", direction=-1) → Fritz faces left
	# e.g., BEHAVIOR("Hans", "attacking") → Hans plays attack animation
	# e.g., SPAWN("NewChar", pos=Vector2(300,50)) → creates new NPC rig and places it
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
			var anim = GroupPlayback.BEHAVIOR_MAP.get(inst.behavior.to_lower())
			if anim != null:
				stage_presenter.set_character_behavior(inst.character_id, anim)
		CharacterInstruction.Action.SPAWN:
			print("[VnPresenter] Character %s → spawn at %s" % [inst.character_id, str(inst.target_position)])
			stage_presenter.spawn_npc_rig(inst.character_id)
			stage_presenter.place_character(inst.character_id, inst.target_position, inst.face_direction)
		CharacterInstruction.Action.SHOW:
			print("[VnPresenter] Character %s → show" % inst.character_id)
			stage_presenter.show_character(inst.character_id)
		CharacterInstruction.Action.HIDE:
			print("[VnPresenter] Character %s → hide" % inst.character_id)
			stage_presenter.hide_character(inst.character_id)
		CharacterInstruction.Action.EXPRESSION:
			print("[VnPresenter] Character %s → expression '%s'" % [inst.character_id, inst.expression])
			stage_presenter.set_character_expression(inst.character_id, inst.expression)

func _execute_scenery(inst: SceneryInstruction) -> void:
	# Mutates stage set dressing during playback (add/remove/move/tint props, swap backdrop).
	if not stage_presenter:
		return
	match inst.action:
		SceneryInstruction.Action.ADD:
			var prop := StageProp.new()
			prop.prop_id = inst.prop_id
			prop.svg_path = inst.svg_path
			prop.position = inst.position
			prop.scale = inst.scale
			prop.z_index = inst.z_index
			prop.flip_h = inst.flip_h
			prop.parallax = inst.parallax
			prop.svg_scale = inst.svg_scale
			prop.modulate = inst.modulate_color
			print("[VnPresenter] Scenery %s → add" % inst.prop_id)
			stage_presenter.add_prop(prop)
		SceneryInstruction.Action.REMOVE:
			print("[VnPresenter] Scenery %s → remove" % inst.prop_id)
			stage_presenter.remove_prop(inst.prop_id)
		SceneryInstruction.Action.MOVE:
			print("[VnPresenter] Scenery %s → move to %s" % [inst.prop_id, str(inst.position)])
			stage_presenter.move_prop(inst.prop_id, inst.position, maxf(inst.duration, 0.01))
		SceneryInstruction.Action.MODULATE:
			print("[VnPresenter] Scenery %s → modulate %s" % [inst.prop_id, str(inst.modulate_color)])
			stage_presenter.modulate_prop(inst.prop_id, inst.modulate_color, maxf(inst.duration, 0.01))
		SceneryInstruction.Action.SHOW:
			stage_presenter.set_prop_visible(inst.prop_id, true)
		SceneryInstruction.Action.HIDE:
			stage_presenter.set_prop_visible(inst.prop_id, false)
		SceneryInstruction.Action.SET_BACKDROP:
			print("[VnPresenter] Scenery → set backdrop %s" % inst.svg_path)
			stage_presenter.set_backdrop(inst.svg_path, inst.position, inst.scale, inst.z_index, inst.parallax, inst.svg_scale)

#endregion

#region Completion

func _on_timeline_complete() -> void:
	print("[VnPresenter] Chain '%s' complete" % current_chain.chain_id)
	if stage_presenter:
		stage_presenter.dismiss_all_speech()
	view.hide_narrator_box()
	
	if stage_presenter.view.stage_camera.tweening():
		# If camera is still tweening, delay completion signal until done to avoid jarring cuts
		var tween = stage_presenter.view.stage_camera._active_tween
		tween.tween_callback(func() -> void: view.chain_completed.emit())
	else: view.chain_completed.emit()
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
	var chain = current_chain
	var stage_view = stage_presenter.view
	for char_id in chain.character_ids:
		if not char_id.is_empty() and not stage_view.rigs.has(char_id):
			stage_view.presenter.spawn_npc_rig(char_id)
			print("[VnPresenter] Spawned NPC rig for: %s" % char_id)

#endregion
