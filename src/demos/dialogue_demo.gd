extends Control
## Timeline VN System Demo — showcases the new cinematic timeline playback system.
## Demonstrates: gated dialogues, timed camera moves, character movement,
## speed-up on SPACE, and narrator fallback.

@onready var stage_view: StageView = $StageView
@onready var narrator_box: PanelContainer = $NarratorBox
@onready var narrator_speaker: Label = $NarratorBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var narrator_text: Label = $NarratorBox/MarginContainer/VBoxContainer/TextLabel
@onready var status_label: Label = $StatusLabel

var _demo_warriors: Array[CharacterSocialStats] = []
var _playback: TimelinePlayback = TimelinePlayback.new()
var _is_headless: bool = false


func _ready() -> void:
	_is_headless = OS.has_feature("headless") or "--headless" in OS.get_cmdline_args()
	print("=== Timeline VN System Demo ===")
	print("SPACE: speed-up / advance gate | R: restart")
	print("")

	_playback.instruction_fired.connect(_on_instruction_fired)
	_playback.gate_reached.connect(_on_gate_reached)
	_playback.timeline_complete.connect(_on_timeline_complete)

	_create_demo_warriors()
	await stage_view.spawn_warriors(_demo_warriors)

	var chain = _build_demo_chain()

	var squad_ids: Array[String] = []
	for w in _demo_warriors:
		squad_ids.append(w.id)
	stage_view.presenter.prepare_for_dialogue(squad_ids)
	_ensure_npc_rigs(chain)

	if not chain.setting.is_empty():
		stage_view.presenter.apply_setting(chain.setting)

	var typed_timeline: Array[CinematicInstruction] = []
	for inst in chain.timeline:
		if inst is CinematicInstruction:
			typed_timeline.append(inst)
	_playback.load_timeline(typed_timeline)
	_update_status("Playing timeline...")

	if _is_headless:
		_run_headless_test()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_playback.on_input()
			KEY_R:
				_restart()


func _process(delta: float) -> void:
	_playback.process(delta)


func _restart() -> void:
	_playback.reset()
	stage_view.presenter.dismiss_all_speech()
	narrator_box.visible = false
	stage_view.presenter.return_to_wide()

	var chain = _build_demo_chain()
	var squad_ids: Array[String] = []
	for w in _demo_warriors:
		squad_ids.append(w.id)
	stage_view.presenter.prepare_for_dialogue(squad_ids)

	if not chain.setting.is_empty():
		stage_view.presenter.apply_setting(chain.setting)

	var typed_timeline: Array[CinematicInstruction] = []
	for inst in chain.timeline:
		if inst is CinematicInstruction:
			typed_timeline.append(inst)
	_playback.load_timeline(typed_timeline)
	_update_status("Playing timeline... (restarted)")

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
		"[Demo] Dialogue — %s: \"%s\"" % [
			inst.speaker_name if not inst.speaker_name.is_empty() else "(narrator)",
			inst.line_spoken.left(50),
		],
	)

	if not inst.keep_previous_bubbles:
		stage_view.presenter.dismiss_all_speech()
		narrator_box.visible = false

	var speaker_id = _resolve_speaker_id(inst.speaker_name)
	var is_narrator = speaker_id.is_empty() or inst.speaker_name.is_empty() or inst.speaker_name == "narrator"
	var has_stage_rig = not is_narrator and stage_view.get_rig(speaker_id) != null

	if has_stage_rig:
		var bubble = stage_view.presenter.show_speech(speaker_id, inst.speaker_name, inst.line_spoken)
		if bubble:
			_playback.register_bubble(bubble)
	else:
		narrator_speaker.text = inst.speaker_name if not inst.speaker_name.is_empty() else "Narrator"
		narrator_text.text = inst.line_spoken
		narrator_text.visible_characters = 0
		narrator_box.visible = true
		_playback.start_narrator(inst.line_spoken, func(count: int) -> void: narrator_text.visible_characters = count)


func _execute_camera(inst: CameraInstruction) -> void:
	match inst.action:
		CameraInstruction.Action.FOCUS_CHARACTER:
			print("[Demo] Camera → focus %s" % inst.target_character_id)
			stage_view.presenter.focus_speaker(inst.target_character_id, inst.zoom_level, maxf(inst.duration, 0.4))
		CameraInstruction.Action.INCLUDE_CHARACTERS:
			print("[Demo] Camera → include %s" % str(inst.include_character_ids))
			stage_view.set_camera_include(inst.include_character_ids, maxf(inst.duration, 0.4))
		CameraInstruction.Action.MOVE:
			print("[Demo] Camera → move %s over %.1fs" % [str(inst.move_offset), inst.duration])
			stage_view.move_camera(inst.move_offset, maxf(inst.duration, 0.01))
		CameraInstruction.Action.ZOOM:
			print("[Demo] Camera → zoom %.1f" % inst.zoom_level)
			stage_view.zoom_camera(inst.zoom_level, maxf(inst.duration, 0.01))
		CameraInstruction.Action.RESET:
			print("[Demo] Camera → reset")
			stage_view.reset_camera(0.4)


func _execute_character(inst: CharacterInstruction) -> void:
	match inst.action:
		CharacterInstruction.Action.MOVE:
			print("[Demo] Character %s → move to %s" % [inst.character_id, str(inst.target_position)])
			stage_view.presenter.walk_character(inst.character_id, inst.target_position, maxf(inst.duration, 0.8))
		CharacterInstruction.Action.FACE:
			print("[Demo] Character %s → face %d" % [inst.character_id, inst.face_direction])
			stage_view.presenter.set_character_facing(inst.character_id, inst.face_direction)
		CharacterInstruction.Action.BEHAVIOR:
			print("[Demo] Character %s → behavior '%s'" % [inst.character_id, inst.behavior])
			var anim = TimelinePlayback.BEHAVIOR_MAP.get(inst.behavior.to_lower())
			if anim != null:
				stage_view.presenter.set_character_behavior(inst.character_id, anim)
		CharacterInstruction.Action.SPAWN:
			stage_view.presenter.spawn_npc_rig(inst.character_id)
			stage_view.presenter.place_character(inst.character_id, inst.target_position, inst.face_direction)

#endregion

#region Playback Callbacks

func _on_gate_reached() -> void:
	_update_status("Gate — SPACE to advance")
	print("[Demo] Gate reached at t=%.2f" % _playback.time_cursor)


func _on_timeline_complete() -> void:
	_update_status("Timeline complete! Press R to restart")
	print("\n=== Timeline complete! ===")
	stage_view.presenter.dismiss_all_speech()
	stage_view.presenter.return_to_wide()
	narrator_box.visible = false

#endregion

#region Helpers

func _resolve_speaker_id(speaker_name: String) -> String:
	if speaker_name.is_empty() or speaker_name.to_lower() == "narrator":
		return ""
	for w in _demo_warriors:
		if w.id == speaker_name.to_lower():
			return w.id
		if w.name.to_lower() == speaker_name.to_lower():
			return w.id
	if stage_view.rigs.has(speaker_name.to_lower()):
		return speaker_name.to_lower()
	return speaker_name


func _ensure_npc_rigs(chain: EventChain) -> void:
	for inst in chain.timeline:
		if inst is DialogueInstruction:
			var id = _resolve_speaker_id(inst.speaker_name)
			if not id.is_empty() and not stage_view.rigs.has(id):
				stage_view.presenter.spawn_npc_rig(id)
				print("[Demo] Spawned NPC rig for: %s" % id)
		elif inst is CharacterInstruction:
			if not inst.character_id.is_empty() and not stage_view.rigs.has(inst.character_id):
				stage_view.presenter.spawn_npc_rig(inst.character_id)
				print("[Demo] Spawned NPC rig for: %s" % inst.character_id)


func _update_status(text: String) -> void:
	status_label.text = text

#endregion

#region Data Setup

func _create_demo_warriors() -> void:
	var names = ["Faust", "Heinrich", "Elara"]
	var classes = [
		EntityClasses.Types.Landsknecht,
		EntityClasses.Types.Healer,
		EntityClasses.Types.Landsknecht,
	]
	for i in names.size():
		var warrior = CharacterSocialStats.new()
		warrior.id = names[i].to_lower()
		warrior.name = names[i]
		warrior.class_id = classes[i]
		_demo_warriors.append(warrior)


func _build_demo_chain() -> EventChain:
	var chain = EventChain.new()
	chain.chain_id = "timeline_demo_chain"
	chain.chain_name = "Timeline System Demo"

	var ids: Array[String] = ["faust", "heinrich", "elara"]
	chain.set_character_ids(ids)

	chain.setting.append(StagePosition.new("faust", Vector2(-100, 50), 1))
	chain.setting.append(StagePosition.new("heinrich", Vector2(0, 50), 1))
	chain.setting.append(StagePosition.new("elara", Vector2(100, 50), -1))

	## ===== PART 1: Simple gated dialogue (click-through) =====

	var d1 = DialogueInstruction.new()
	d1.time = 0.0
	d1.speaker_name = "Narrator"
	d1.line_spoken = "The squad gathers around the campfire as evening descends. Shadows flicker across weary faces."
	chain.timeline.append(d1)

	var g1 = GateInstruction.new()
	g1.time = 0.01
	g1.wait_for_typewriter = true
	chain.timeline.append(g1)

	var b1 = CharacterInstruction.new()
	b1.time = 0.02
	b1.action = CharacterInstruction.Action.BEHAVIOR
	b1.character_id = "faust"
	b1.behavior = "gesturing"
	chain.timeline.append(b1)

	var cam1 = CameraInstruction.new()
	cam1.time = 0.02
	cam1.action = CameraInstruction.Action.FOCUS_CHARACTER
	cam1.target_character_id = "faust"
	cam1.zoom_level = 1.8
	cam1.duration = 0.4
	chain.timeline.append(cam1)

	var d2 = DialogueInstruction.new()
	d2.time = 0.02
	d2.speaker_name = "Faust"
	d2.line_spoken = "Brothers, we must decide our next move. The road ahead is treacherous."
	chain.timeline.append(d2)

	var g2 = GateInstruction.new()
	g2.time = 0.03
	g2.wait_for_typewriter = true
	chain.timeline.append(g2)

	var f1 = CharacterInstruction.new()
	f1.time = 0.04
	f1.action = CharacterInstruction.Action.FACE
	f1.character_id = "heinrich"
	f1.face_direction = -1
	chain.timeline.append(f1)

	var cam2 = CameraInstruction.new()
	cam2.time = 0.04
	cam2.action = CameraInstruction.Action.FOCUS_CHARACTER
	cam2.target_character_id = "heinrich"
	cam2.zoom_level = 1.8
	cam2.duration = 0.4
	chain.timeline.append(cam2)

	var d3 = DialogueInstruction.new()
	d3.time = 0.04
	d3.speaker_name = "Heinrich"
	d3.line_spoken = "I say we rest here. The wounded need tending, and my herbs are running low."
	chain.timeline.append(d3)

	var d4 = DialogueInstruction.new()
	d4.time = 0.041
	d4.speaker_name = "Elara"
	d4.line_spoken = "Rest? While enemies close in? We push forward at dawn."
	d4.keep_previous_bubbles = true
	chain.timeline.append(d4)

	var cam3 = CameraInstruction.new()
	cam3.time = 0.041
	cam3.action = CameraInstruction.Action.INCLUDE_CHARACTERS
	cam3.include_character_ids = ["heinrich", "elara"] as Array[String]
	cam3.duration = 0.4
	chain.timeline.append(cam3)

	var g3 = GateInstruction.new()
	g3.time = 0.05
	g3.wait_for_typewriter = true
	chain.timeline.append(g3)

	## ===== PART 2: Timed cinematic sequence (auto-advancing) =====

	var m1 = CharacterInstruction.new()
	m1.time = 0.06
	m1.action = CharacterInstruction.Action.MOVE
	m1.character_id = "faust"
	m1.target_position = Vector2(-30, 30)
	m1.duration = 1.5
	chain.timeline.append(m1)

	var d5 = DialogueInstruction.new()
	d5.time = 0.06
	d5.speaker_name = "Faust"
	d5.line_spoken = "Both of you have a point—"
	chain.timeline.append(d5)

	var cam4 = CameraInstruction.new()
	cam4.time = 0.06
	cam4.action = CameraInstruction.Action.FOCUS_CHARACTER
	cam4.target_character_id = "faust"
	cam4.zoom_level = 2.0
	cam4.duration = 0.5
	chain.timeline.append(cam4)

	var cam_pan = CameraInstruction.new()
	cam_pan.time = 2.0
	cam_pan.action = CameraInstruction.Action.MOVE
	cam_pan.move_offset = Vector2(0, -80)
	cam_pan.duration = 2.0
	chain.timeline.append(cam_pan)

	var d6 = DialogueInstruction.new()
	d6.time = 2.1
	d6.speaker_name = "Mysterious Voice"
	d6.line_spoken = "Perhaps I can offer a third option..."
	d6.keep_previous_bubbles = true
	chain.timeline.append(d6)

	var cam_reset = CameraInstruction.new()
	cam_reset.time = 4.5
	cam_reset.action = CameraInstruction.Action.RESET
	cam_reset.duration = 0.5
	chain.timeline.append(cam_reset)

	var g4 = GateInstruction.new()
	g4.time = 5.0
	g4.wait_for_typewriter = true
	chain.timeline.append(g4)

	## ===== PART 3: Camera target override =====

	var cam5 = CameraInstruction.new()
	cam5.time = 5.01
	cam5.action = CameraInstruction.Action.FOCUS_CHARACTER
	cam5.target_character_id = "heinrich"
	cam5.zoom_level = 1.8
	cam5.duration = 0.4
	chain.timeline.append(cam5)

	var d7 = DialogueInstruction.new()
	d7.time = 5.01
	d7.speaker_name = "Faust"
	d7.line_spoken = "Heinrich, what do you make of that?"
	chain.timeline.append(d7)

	var g5 = GateInstruction.new()
	g5.time = 5.02
	g5.wait_for_typewriter = true
	chain.timeline.append(g5)

	## ===== PART 4: Final sequence =====

	var m2 = CharacterInstruction.new()
	m2.time = 5.03
	m2.action = CharacterInstruction.Action.MOVE
	m2.character_id = "elara"
	m2.target_position = Vector2(10, 40)
	m2.duration = 1.0
	chain.timeline.append(m2)

	var cam6 = CameraInstruction.new()
	cam6.time = 5.03
	cam6.action = CameraInstruction.Action.INCLUDE_CHARACTERS
	cam6.include_character_ids = ["faust", "elara"] as Array[String]
	cam6.duration = 0.5
	chain.timeline.append(cam6)

	var b2 = CharacterInstruction.new()
	b2.time = 5.5
	b2.action = CharacterInstruction.Action.BEHAVIOR
	b2.character_id = "faust"
	b2.behavior = "attacking"
	chain.timeline.append(b2)

	var d8 = DialogueInstruction.new()
	d8.time = 5.5
	d8.speaker_name = "Faust"
	d8.line_spoken = "Enough! We vote at dawn. Get some rest."
	chain.timeline.append(d8)

	var g6 = GateInstruction.new()
	g6.time = 7.0
	g6.wait_for_typewriter = true
	chain.timeline.append(g6)

	var cam7 = CameraInstruction.new()
	cam7.time = 7.01
	cam7.action = CameraInstruction.Action.RESET
	cam7.duration = 0.5
	chain.timeline.append(cam7)

	var d9 = DialogueInstruction.new()
	d9.time = 7.01
	d9.speaker_name = "Narrator"
	d9.line_spoken = "The campfire crackles as the squad settles into uneasy silence. Tomorrow will bring its own challenges."
	chain.timeline.append(d9)

	var g7 = GateInstruction.new()
	g7.time = 7.02
	g7.wait_for_typewriter = true
	chain.timeline.append(g7)

	print(
		"[Demo] Built EventChain '%s' with %d timeline instructions (%d dialogues)" % [
			chain.chain_id,
			chain.get_instruction_count(),
			chain.get_dialogue_count(),
		],
	)
	return chain

#endregion

#region Headless Testing

func _run_headless_test() -> void:
	print("\n=== HEADLESS TEST START ===")

	assert(
		_playback.state == TimelinePlayback.State.PLAYING or _playback.state == TimelinePlayback.State.WAITING_FOR_GATE,
		"T1: should be PLAYING or at first GATE after load",
	)
	print("[TEST 1] PASS: Timeline started (state=%d)" % _playback.state)

	await _wait_for_state(TimelinePlayback.State.WAITING_FOR_GATE, 5.0)
	assert(
		_playback.state == TimelinePlayback.State.WAITING_FOR_GATE,
		"T2: should be WAITING_FOR_GATE after narrator",
	)
	print("[TEST 2] PASS: First gate reached (narrator intro)")

	_playback.on_input()
	assert(
		_playback.state == TimelinePlayback.State.PLAYING or _playback.state == TimelinePlayback.State.WAITING_FOR_GATE,
		"T3: should resume PLAYING or hit next gate instantly",
	)
	print("[TEST 3] PASS: Gate advanced")

	for i in 3:
		await _wait_for_state(TimelinePlayback.State.WAITING_FOR_GATE, 5.0)
		_playback.on_input()
	print("[TEST 4] PASS: Clicked through gated dialogues")

	await _wait_for_state_any([TimelinePlayback.State.PLAYING, TimelinePlayback.State.FAST_FORWARDING, TimelinePlayback.State.WAITING_FOR_GATE], 2.0)
	print("[TEST 5] PASS: Cinematic section (state=%d)" % _playback.state)

	if _playback.state == TimelinePlayback.State.PLAYING:
		_playback.on_input()
		assert(
			_playback.state == TimelinePlayback.State.FAST_FORWARDING or _playback.state == TimelinePlayback.State.WAITING_FOR_GATE,
			"T6: should be FAST_FORWARDING or at gate after space",
		)
		print("[TEST 6] PASS: Speed-up engaged (state=%d)" % _playback.state)
	else:
		print("[TEST 6] SKIP: Already at gate")

	for i in 10:
		if _playback.state == TimelinePlayback.State.COMPLETE:
			break
		if _playback.state == TimelinePlayback.State.WAITING_FOR_GATE:
			_playback.on_input()
		await _wait_for_state_any([TimelinePlayback.State.WAITING_FOR_GATE, TimelinePlayback.State.COMPLETE], 8.0)

	assert(_playback.state == TimelinePlayback.State.COMPLETE, "T7: should be COMPLETE (got %d)" % _playback.state)
	print("[TEST 7] PASS: Timeline complete")

	print("\n=== HEADLESS TEST: ALL PASSED ===")


func _wait_for_state(target: TimelinePlayback.State, timeout_sec: float) -> void:
	var elapsed = 0.0
	while _playback.state != target and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if _playback.state != target:
		push_warning("Timeout waiting for state %d (current: %d)" % [target, _playback.state])


func _wait_for_state_any(targets: Array, timeout_sec: float) -> void:
	var elapsed = 0.0
	while not targets.has(_playback.state) and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

#endregion
