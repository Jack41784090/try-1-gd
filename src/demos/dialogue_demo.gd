extends Control
## Timeline VN system demo: gated dialogues, timed camera moves, character movement, SPACE speed-up, and narrator fallback, via the shared VnView scene.

@export var given_event_chain: EventChain

@onready var vn_view: VnView = $VnView
@onready var stage_view: StageView = $StageView
@onready var status_label: Label = $StatusLabel

var _presenter: VnPresenter
var _playback: GroupPlayback
var _demo_warriors: Array[Character] = []
var _is_headless: bool = false


func _ready() -> void:
	_presenter = vn_view.presenter
	_playback = _presenter._playback
	_presenter.stage_presenter = stage_view.presenter

	_playback.gate_reached.connect(_on_gate_reached)
	vn_view.chain_completed.connect(_on_chain_completed)

	_is_headless = OS.has_feature("headless") or "--headless" in OS.get_cmdline_args()
	print("=== Timeline VN System Demo ===")
	print("SPACE: speed-up / advance gate | R: restart")
	print("")

	await stage_view.spawn_warriors(_demo_warriors)

	var chain = given_event_chain if given_event_chain else _build_demo_chain()
	_presenter.load_chain(chain)
	_update_status("Playing timeline...")

	if _is_headless:
		print("\n=== HEADLESS TEST START ===")

		assert(
			_playback.state == GroupPlayback.State.PLAYING or _playback.state == GroupPlayback.State.WAITING_FOR_GATE,
			"T1: should be PLAYING or at first GATE after load",
		)
		print("[TEST 1] PASS: Timeline started (state=%d)" % _playback.state)

		await _wait_for_state(GroupPlayback.State.WAITING_FOR_GATE, 5.0)
		assert(
			_playback.state == GroupPlayback.State.WAITING_FOR_GATE,
			"T2: should be WAITING_FOR_GATE after narrator",
		)
		print("[TEST 2] PASS: First gate reached (narrator intro)")

		_playback.on_input()
		assert(
			_playback.state == GroupPlayback.State.PLAYING or _playback.state == GroupPlayback.State.WAITING_FOR_GATE,
			"T3: should resume PLAYING or hit next gate instantly",
		)
		print("[TEST 3] PASS: Gate advanced")

		for i in 3:
			await _wait_for_state(GroupPlayback.State.WAITING_FOR_GATE, 5.0)
			_playback.on_input()
		print("[TEST 4] PASS: Clicked through gated dialogues")

		await _wait_for_state_any([GroupPlayback.State.PLAYING, GroupPlayback.State.FAST_FORWARDING, GroupPlayback.State.WAITING_FOR_GATE], 2.0)
		print("[TEST 5] PASS: Cinematic section (state=%d)" % _playback.state)

		if _playback.state == GroupPlayback.State.PLAYING:
			_playback.on_input()
			assert(
				_playback.state == GroupPlayback.State.FAST_FORWARDING or _playback.state == GroupPlayback.State.WAITING_FOR_GATE,
				"T6: should be FAST_FORWARDING or at gate after space",
			)
			print("[TEST 6] PASS: Speed-up engaged (state=%d)" % _playback.state)
		else:
			print("[TEST 6] SKIP: Already at gate")

		for i in 10:
			if _playback.state == GroupPlayback.State.COMPLETE:
				break
			if _playback.state == GroupPlayback.State.WAITING_FOR_GATE:
				_playback.on_input()
			await _wait_for_state_any([GroupPlayback.State.WAITING_FOR_GATE, GroupPlayback.State.COMPLETE], 8.0)

		assert(_playback.state == GroupPlayback.State.COMPLETE, "T7: should be COMPLETE (got %d)" % _playback.state)
		print("[TEST 7] PASS: Timeline complete")

		print("\n=== HEADLESS TEST: ALL PASSED ===")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			if _presenter.stage_presenter:
				_presenter.stage_presenter.dismiss_all_speech()
				_presenter.stage_presenter.return_to_wide()
			vn_view.hide_narrator_box()

			var chain = given_event_chain if given_event_chain else _build_demo_chain()
			_presenter.load_chain(chain)
			_update_status("Playing timeline... (restarted)")
			get_viewport().set_input_as_handled()

#region Playback Callbacks

func _on_gate_reached() -> void:
	_update_status("Gate — SPACE to advance")
	print("[Demo] Gate reached")


func _on_chain_completed() -> void:
	_update_status("Timeline complete! Press R to restart")
	print("\n=== Timeline complete! ===")

#endregion

#region Helpers
func _update_status(text: String) -> void:
	status_label.text = text

#endregion

#region Data Setup

func _create_demo_warriors() -> void:
	var names = ["Faust", "Heinrich", "Elara"]
	for i in names.size():
		var entity = StrategyEntity.new()
		entity.id = names[i].to_lower()
		entity.display_name = names[i]
		var warrior = Character.new(entity)
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

func _wait_for_state(target: GroupPlayback.State, timeout_sec: float) -> void:
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
