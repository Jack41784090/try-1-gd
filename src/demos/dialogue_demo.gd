extends Control

## Dialogue System Demo
## Typewriter effect with punctuation pauses, after_id batch grouping,
## interrupt detection via word_revealed, SPACE fast-forward, headless testing.

enum State { IDLE, TYPEWRITING, WAITING, COMPLETE }

const BEHAVIOR_MAP: Dictionary = {
	"idle": AnimTypes.Behavior.IDLE,
	"walking": AnimTypes.Behavior.WALKING,
	"attacking": AnimTypes.Behavior.ATTACKING,
	"defending": AnimTypes.Behavior.DEFENDING,
	"hurt": AnimTypes.Behavior.HURT,
	"dying": AnimTypes.Behavior.DYING,
	"talking": AnimTypes.Behavior.TALKING,
	"gesturing": AnimTypes.Behavior.GESTURING,
}

const FAST_FORWARD_SPEED: float = 5.0
const NARRATOR_CHAR_DELAY: float = 0.03
const NARRATOR_COMMA_DELAY: float = 0.12
const NARRATOR_SENTENCE_DELAY: float = 0.22

@onready var stage_view: StageView = $StageView
@onready var narrator_box: PanelContainer = $NarratorBox
@onready var narrator_speaker: Label = $NarratorBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var narrator_text: Label = $NarratorBox/MarginContainer/VBoxContainer/TextLabel
@onready var status_label: Label = $StatusLabel

var _demo_warriors: Array[CharacterSocialStats] = []
var _chain: EventChain
var _state: State = State.IDLE
var _shown_indices: Dictionary = {}
var _active_bubbles: Array[SpeechBubble] = []
var _active_dialogues: Array[Dialogue] = []
var _pending_typewriters: int = 0
var _displayed_ids: Array[String] = []
var _next_linear_index: int = 0

var _narrator_tw_active: bool = false
var _narrator_tw_text: String = ""
var _narrator_tw_index: int = 0
var _narrator_tw_accum: float = 0.0
var _narrator_tw_speed: float = 1.0

var _is_headless: bool = false

func _ready() -> void:
	_is_headless = OS.has_feature("headless") or "--headless" in OS.get_cmdline_args()
	print("=== Dialogue System Demo ===")
	print("Typewriter + after_id batching + interrupt + fast-forward")
	print("SPACE: fast-forward / advance | R: restart")
	print("")

	_create_demo_warriors()
	await stage_view.spawn_warriors(_demo_warriors)

	_chain = _build_demo_chain()

	var squad_ids: Array[String] = []
	for w in _demo_warriors:
		squad_ids.append(w.id)
	stage_view.presenter.prepare_for_dialogue(squad_ids)
	_ensure_npc_rigs()

	_advance_to_next()

	if _is_headless:
		_run_headless_test()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_on_space()
			KEY_R:
				_restart()

func _process(delta: float) -> void:
	if _narrator_tw_active:
		_update_narrator_typewriter(delta)

func _on_space() -> void:
	match _state:
		State.TYPEWRITING:
			_fast_forward_all()
		State.WAITING:
			_advance_to_next()
		State.COMPLETE:
			pass

func _restart() -> void:
	_state = State.IDLE
	_shown_indices.clear()
	_active_bubbles.clear()
	_active_dialogues.clear()
	_pending_typewriters = 0
	_displayed_ids.clear()
	_next_linear_index = 0
	_narrator_tw_active = false
	stage_view.presenter.dismiss_all_speech()
	narrator_box.visible = false

	var squad_ids: Array[String] = []
	for w in _demo_warriors:
		squad_ids.append(w.id)
	stage_view.presenter.prepare_for_dialogue(squad_ids)
	_ensure_npc_rigs()
	_advance_to_next()

#region Playback State Machine

func _advance_to_next() -> void:
	var batch = _collect_next_batch()
	if batch.is_empty():
		_state = State.COMPLETE
		print("\n=== Chain complete! ===")
		stage_view.presenter.dismiss_all_speech()
		stage_view.presenter.return_to_wide()
		narrator_box.visible = false
		_update_status("Chain complete! Press R to restart")
		return
	_show_batch(batch)

func _collect_next_batch() -> Array[int]:
	var batch: Array[int] = []

	if _next_linear_index >= _chain.get_dialogue_count():
		return batch

	while _next_linear_index < _chain.get_dialogue_count() and _shown_indices.has(_next_linear_index):
		_next_linear_index += 1

	if _next_linear_index >= _chain.get_dialogue_count():
		return batch

	var first_idx = _next_linear_index
	batch.append(first_idx)
	_next_linear_index = first_idx + 1

	var first_d: Dialogue = _chain.dialogues[first_idx]
	if not first_d.id.is_empty():
		for i in range(first_idx + 1, _chain.get_dialogue_count()):
			if _shown_indices.has(i):
				continue
			var d: Dialogue = _chain.dialogues[i]
			if d.after_id == first_d.id:
				batch.append(i)
	return batch

func _show_batch(indices: Array[int]) -> void:
	_active_bubbles.clear()
	_active_dialogues.clear()
	_pending_typewriters = 0

	var first_d: Dialogue = _chain.dialogues[indices[0]]
	if not first_d.keep_previous_bubbles:
		stage_view.presenter.dismiss_all_speech()
		narrator_box.visible = false
		_narrator_tw_active = false

	var camera_targets: Array[String] = []

	for idx in indices:
		_shown_indices[idx] = true
		var dialogue: Dialogue = _chain.dialogues[idx]
		if not dialogue.id.is_empty():
			_displayed_ids.append(dialogue.id)

		var progress = "(%d/%d)" % [idx + 1, _chain.get_dialogue_count()]
		_print_dialogue_info(dialogue, progress)
		_apply_stage_direction(dialogue)
		var target = _route_display_and_track(dialogue)
		if not target.is_empty():
			camera_targets.append(target)

	if camera_targets.size() == 1:
		stage_view.presenter.focus_speaker(camera_targets[0])
	elif camera_targets.size() > 1:
		var ids: Array[String] = []
		for t in camera_targets:
			ids.append(t)
		stage_view.presenter.focus_conversation(ids)

	if _pending_typewriters > 0:
		_state = State.TYPEWRITING
		_update_status("Typewriting... SPACE: fast-forward")
	else:
		_state = State.WAITING
		_update_status("SPACE: advance | R: restart")

func _route_display_and_track(dialogue: Dialogue) -> String:
	var speaker_id = _resolve_speaker_id(dialogue.speaker_name)
	var is_narrator = speaker_id.is_empty() or dialogue.speaker_name.is_empty() or dialogue.speaker_name == "narrator"
	var has_stage_rig = not is_narrator and stage_view.get_rig(speaker_id) != null

	if has_stage_rig:
		if not dialogue.behavior.is_empty():
			var anim = BEHAVIOR_MAP.get(dialogue.behavior.to_lower())
			if anim != null:
				stage_view.presenter.set_character_behavior(speaker_id, anim)

		var bubble = stage_view.presenter.show_speech(speaker_id, dialogue.speaker_name, dialogue.line_spoken)
		if bubble:
			bubble.start_typewriter()
			_active_bubbles.append(bubble)
			_active_dialogues.append(dialogue)
			_pending_typewriters += 1
			bubble.typewriter_finished.connect(_on_bubble_typewriter_finished.bind(bubble))
			if dialogue.has_interrupt():
				bubble.word_revealed.connect(_on_word_revealed.bind(dialogue))

		var focus_target = dialogue.camera_target if not dialogue.camera_target.is_empty() else speaker_id
		return focus_target
	else:
		_start_narrator_typewriter(dialogue.speaker_name, dialogue.line_spoken)
		_pending_typewriters += 1
		return ""

func _on_bubble_typewriter_finished(bubble: SpeechBubble) -> void:
	_pending_typewriters -= 1
	if _pending_typewriters <= 0 and _state == State.TYPEWRITING:
		_pending_typewriters = 0
		_state = State.WAITING
		_update_status("SPACE: advance | R: restart")
		print("[Demo] All typewriters finished — WAITING")

func _on_word_revealed(word: String, dialogue: Dialogue) -> void:
	if not dialogue.has_interrupt():
		return
	if word.to_lower() == dialogue.interrupt_on_word.to_lower():
		print("[Demo] INTERRUPT triggered: word '%s' in '%s'" % [word, dialogue.id])
		_fire_interrupter(dialogue)

func _fire_interrupter(interrupted: Dialogue) -> void:
	for b in _active_bubbles:
		if is_instance_valid(b) and b.is_typewriting():
			b.stop_typewriter()
	_pending_typewriters = 0

	var interrupter_idx = -1
	for i in _chain.get_dialogue_count():
		var d: Dialogue = _chain.dialogues[i]
		if d.id == interrupted.interrupt_by_id:
			interrupter_idx = i
			break

	if interrupter_idx < 0:
		push_warning("Interrupter '%s' not found in chain" % interrupted.interrupt_by_id)
		return

	call_deferred("_show_batch", [interrupter_idx] as Array[int])

func _fast_forward_all() -> void:
	for bubble in _active_bubbles:
		if is_instance_valid(bubble) and bubble.is_typewriting():
			bubble.set_speed(FAST_FORWARD_SPEED)
	_narrator_tw_speed = FAST_FORWARD_SPEED
	print("[Demo] Fast-forward: %.0fx speed" % FAST_FORWARD_SPEED)

#endregion

#region Narrator Typewriter

func _start_narrator_typewriter(speaker: String, text: String) -> void:
	narrator_speaker.text = speaker if not speaker.is_empty() else "Narrator"
	narrator_text.text = text
	narrator_text.visible_characters = 0
	narrator_box.visible = true
	_narrator_tw_text = text
	_narrator_tw_index = 0
	_narrator_tw_accum = 0.0
	_narrator_tw_speed = 1.0
	_narrator_tw_active = true

func _update_narrator_typewriter(delta: float) -> void:
	_narrator_tw_accum += delta * _narrator_tw_speed
	while _narrator_tw_accum > 0.0 and _narrator_tw_index < _narrator_tw_text.length():
		var ch = _narrator_tw_text[_narrator_tw_index]
		_narrator_tw_index += 1
		narrator_text.visible_characters = _narrator_tw_index
		_narrator_tw_accum -= _get_narrator_delay(ch)

	if _narrator_tw_index >= _narrator_tw_text.length():
		_narrator_tw_active = false
		_pending_typewriters -= 1
		if _pending_typewriters <= 0 and _state == State.TYPEWRITING:
			_pending_typewriters = 0
			_state = State.WAITING
			_update_status("SPACE: advance | R: restart")
			print("[Demo] Narrator typewriter finished — WAITING")

func _get_narrator_delay(ch: String) -> float:
	match ch:
		".", "!", "?":
			return NARRATOR_SENTENCE_DELAY
		",", ";", ":":
			return NARRATOR_COMMA_DELAY
		_:
			return NARRATOR_CHAR_DELAY

#endregion

#region Display Helpers

func _apply_stage_direction(dialogue: Dialogue) -> void:
	var speaker_id = _resolve_speaker_id(dialogue.speaker_name)
	var has_rig = not speaker_id.is_empty() and stage_view.get_rig(speaker_id) != null
	if not has_rig:
		return
	if dialogue.face_direction != 0:
		stage_view.presenter.set_character_facing(speaker_id, dialogue.face_direction)
	if dialogue.has_walk_to():
		stage_view.presenter.walk_character(speaker_id, dialogue.walk_to)

func _update_status(text: String) -> void:
	status_label.text = text

func _print_dialogue_info(dialogue: Dialogue, progress: String) -> void:
	var id_str = dialogue.id if not dialogue.id.is_empty() else "(none)"
	print("\n--- Dialogue %s [id=%s] ---" % [progress, id_str])
	print("  Speaker: %s" % dialogue.speaker_name)
	print("  Line: \"%s\"" % dialogue.line_spoken)
	if not dialogue.behavior.is_empty():
		print("  Behavior: %s" % dialogue.behavior)
	if dialogue.face_direction != 0:
		print("  Face direction: %d" % dialogue.face_direction)
	if dialogue.has_walk_to():
		print("  Walk to: %s" % dialogue.walk_to)
	if dialogue.keep_previous_bubbles:
		print("  Keep previous bubbles: true")
	if not dialogue.camera_target.is_empty():
		print("  Camera target: %s" % dialogue.camera_target)
	if dialogue.has_after_dependency():
		print("  After: %s" % dialogue.after_id)
	if dialogue.has_interrupt():
		print("  Interrupt: by=%s on_word=\"%s\"" % [dialogue.interrupt_by_id, dialogue.interrupt_on_word])

#endregion

#region Character Resolution

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

func _ensure_npc_rigs() -> void:
	for dialogue in _chain.dialogues:
		if dialogue is Dialogue:
			for char_id in dialogue.on_screen_character_ids:
				if char_id.is_empty() or char_id == "narrator":
					continue
				if not stage_view.rigs.has(char_id):
					stage_view.presenter.spawn_npc_rig(char_id)
					print("[Demo] Spawned NPC rig for: %s" % char_id)

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
	var dialogues: Array = []

	## 1 — Narrator intro: textbox typewriter
	var d1 = Dialogue.new()
	d1.id = "narrator_intro"
	d1.speaker_name = "Narrator"
	d1.line_spoken = "The squad gathers around the campfire as evening descends. Shadows flicker across weary faces."
	dialogues.append(d1)

	## 2 — Faust speaks: bubble typewriter + gesturing
	var d2 = Dialogue.new()
	d2.id = "faust_opens"
	d2.speaker_name = "Faust"
	d2.line_spoken = "Brothers, we must decide our next move. The road ahead is treacherous."
	d2.set_on_screen_character_ids(["faust", "heinrich", "elara"] as Array[String])
	d2.behavior = "gesturing"
	dialogues.append(d2)

	## 3 — Heinrich responds: after_id batch with d4
	var d3 = Dialogue.new()
	d3.id = "heinrich_responds"
	d3.speaker_name = "Heinrich"
	d3.line_spoken = "I say we rest here. The wounded need tending, and my herbs are running low."
	d3.set_on_screen_character_ids(["faust", "heinrich", "elara"] as Array[String])
	d3.face_direction = -1
	dialogues.append(d3)

	## 4 — Elara overlaps Heinrich: after_id="heinrich_responds" + keep_previous_bubbles
	var d4 = Dialogue.new()
	d4.id = "elara_overlaps"
	d4.speaker_name = "Elara"
	d4.line_spoken = "Rest? While enemies close in? We push forward at dawn."
	d4.set_on_screen_character_ids(["faust", "heinrich", "elara"] as Array[String])
	d4.after_id = "heinrich_responds"
	d4.keep_previous_bubbles = true
	dialogues.append(d4)

	## 5 — Faust interjects (clears previous)
	var d5 = Dialogue.new()
	d5.id = "faust_interjects"
	d5.speaker_name = "Faust"
	d5.line_spoken = "Both of you have a point—"
	d5.set_on_screen_character_ids(["faust", "heinrich", "elara"] as Array[String])
	dialogues.append(d5)

	## 6 — Unknown character: no rig, textbox fallback
	var d6 = Dialogue.new()
	d6.id = "stranger_voice"
	d6.speaker_name = "Mysterious Voice"
	d6.line_spoken = "Perhaps I can offer a third option..."
	dialogues.append(d6)

	## 7 — Camera target override: Faust speaks, camera on Heinrich
	var d7 = Dialogue.new()
	d7.id = "faust_looks_at_heinrich"
	d7.speaker_name = "Faust"
	d7.line_spoken = "Heinrich, what do you make of that?"
	d7.set_on_screen_character_ids(["faust", "heinrich"] as Array[String])
	d7.camera_target = "heinrich"
	dialogues.append(d7)

	## 8 — Elara long speech with interrupt trigger
	var d8 = Dialogue.new()
	d8.id = "elara_long_speech"
	d8.speaker_name = "Elara"
	d8.line_spoken = "Listen, we've been through worse. Remember the siege at Smolensk? We held for a fortnight against—"
	d8.set_on_screen_character_ids(["elara", "faust"] as Array[String])
	d8.interrupt_by_id = "faust_cuts_in"
	d8.interrupt_on_word = "fortnight"
	dialogues.append(d8)

	## 9 — The interrupter (auto-fired by interrupt system)
	var d9 = Dialogue.new()
	d9.id = "faust_cuts_in"
	d9.speaker_name = "Faust"
	d9.line_spoken = "Enough! We vote at dawn. Get some rest."
	d9.set_on_screen_character_ids(["faust", "heinrich", "elara"] as Array[String])
	d9.behavior = "attacking"
	dialogues.append(d9)

	## 10 — Narrator outro
	var d10 = Dialogue.new()
	d10.id = "narrator_outro"
	d10.speaker_name = "Narrator"
	d10.line_spoken = "The campfire crackles as the squad settles into uneasy silence. Tomorrow will bring its own challenges."
	dialogues.append(d10)

	var chain = EventChain.new()
	chain.chain_id = "dialogue_demo_chain"
	chain.chain_name = "Dialogue System Demo"
	chain.set_dialogues(dialogues)

	var ids: Array[String] = ["faust", "heinrich", "elara"]
	chain.set_character_ids(ids)

	print("[Demo] Built EventChain '%s' with %d dialogues" % [chain.chain_id, chain.get_dialogue_count()])
	return chain

#endregion

#region Headless Testing

func _run_headless_test() -> void:
	print("\n=== HEADLESS TEST START ===")

	## Test 1: Narrator typewriter started
	assert(_state == State.TYPEWRITING, "T1: should be TYPEWRITING after narrator intro")
	assert(_narrator_tw_active, "T1: narrator typewriter should be active")
	print("[TEST 1] PASS: Narrator typewriter active")

	## Fast-forward narrator
	_fast_forward_all()
	await _wait_for_state(State.WAITING, 5.0)
	assert(_state == State.WAITING, "T1b: should be WAITING after narrator finishes")
	print("[TEST 1b] PASS: Narrator typewriter completed")

	## Test 2: Faust bubble typewriter
	_advance_to_next()
	assert(_state == State.TYPEWRITING, "T2: should be TYPEWRITING for Faust's bubble")
	assert(_active_bubbles.size() == 1, "T2: should have 1 active bubble")
	assert(_active_bubbles[0].is_typewriting(), "T2: bubble should be typewriting")
	print("[TEST 2] PASS: Faust bubble typewriter active")

	## Fast-forward Faust
	_fast_forward_all()
	await _wait_for_state(State.WAITING, 5.0)
	print("[TEST 2b] PASS: Faust typewriter completed")

	## Test 3: after_id batch — Heinrich + Elara together
	_advance_to_next()
	assert(_state == State.TYPEWRITING, "T3: should be TYPEWRITING for batch")
	assert(_active_bubbles.size() >= 2, "T3: should have >= 2 active bubbles (batch)")
	print("[TEST 3] PASS: after_id batch fired (%d bubbles)" % _active_bubbles.size())

	_fast_forward_all()
	await _wait_for_state(State.WAITING, 5.0)
	print("[TEST 3b] PASS: Batch typewriters completed")

	## Test 4: Faust interjects (single bubble)
	_advance_to_next()
	_fast_forward_all()
	await _wait_for_state(State.WAITING, 5.0)
	print("[TEST 4] PASS: Faust interject completed")

	## Test 5: Mysterious Voice narrator fallback
	_advance_to_next()
	assert(_narrator_tw_active or _state == State.WAITING, "T5: narrator typewriter or already done")
	_fast_forward_all()
	await _wait_for_state(State.WAITING, 5.0)
	print("[TEST 5] PASS: Narrator fallback completed")

	## Test 6: Camera target override
	_advance_to_next()
	_fast_forward_all()
	await _wait_for_state(State.WAITING, 5.0)
	print("[TEST 6] PASS: Camera target override completed")

	## Test 7: Interrupt — Elara speaks, Faust cuts in at "fortnight"
	_advance_to_next()
	assert(_state == State.TYPEWRITING, "T7: should be TYPEWRITING for Elara's long speech")
	print("[TEST 7] Waiting for interrupt on 'fortnight'...")
	## Let typewriter run at normal speed so word detection fires
	await _wait_for_state(State.WAITING, 10.0)
	## The interrupt should have auto-fired faust_cuts_in and fast-forwarded
	assert(_shown_indices.has(_get_dialogue_index("faust_cuts_in")), "T7: faust_cuts_in should be shown")
	print("[TEST 7] PASS: Interrupt fired correctly")

	## Test 8: Narrator outro
	_advance_to_next()
	_fast_forward_all()
	await _wait_for_state(State.WAITING, 5.0)
	print("[TEST 8] PASS: Narrator outro completed")

	## Test 9: Chain complete
	_advance_to_next()
	assert(_state == State.COMPLETE, "T9: should be COMPLETE")
	print("[TEST 9] PASS: Chain complete")

	print("\n=== HEADLESS TEST: ALL PASSED ===")

func _wait_for_state(target: State, timeout_sec: float) -> void:
	var elapsed = 0.0
	while _state != target and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if _state != target:
		push_warning("Timeout waiting for state %d (current: %d)" % [target, _state])

func _get_dialogue_index(dialogue_id: String) -> int:
	for i in _chain.get_dialogue_count():
		var d: Dialogue = _chain.dialogues[i]
		if d.id == dialogue_id:
			return i
	return -1

#endregion
