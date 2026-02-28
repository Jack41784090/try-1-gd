class_name TimelinePlayback
extends RefCounted
## Timeline-driven cinematic playback engine. Replaces DialoguePlayback.
## Advances a time cursor each frame, firing CinematicInstructions as their
## timestamps are reached. GateInstructions pause the timeline for player input.
##
## Speed-up: If the player clicks during auto-play, the speed multiplier
## increases (5x) until the next gate, then pauses.
##
## Usage:
##   load_timeline(instructions) → process(delta) each frame → on_input() on click/space

enum State { IDLE, PLAYING, WAITING_FOR_GATE, FAST_FORWARDING, COMPLETE }

const FAST_FORWARD_SPEED: float = 5.0
const NARRATOR_CHAR_DELAY: float = 0.03
const NARRATOR_COMMA_DELAY: float = 0.12
const NARRATOR_SENTENCE_DELAY: float = 0.22

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

signal instruction_fired(instruction: CinematicInstruction)
signal timeline_complete
signal gate_reached

var state: State = State.IDLE
var time_cursor: float = 0.0
var speed_multiplier: float = 1.0
var _timeline: Array[CinematicInstruction] = []
var _next_index: int = 0

var _pending_typewriters: int = 0
var _active_bubbles: Array[SpeechBubble] = []
var _current_gate: GateInstruction = null

var _narrator_tw_active: bool = false
var _narrator_tw_text: String = ""
var _narrator_tw_index: int = 0
var _narrator_tw_accum: float = 0.0
var _narrator_tw_speed: float = 1.0
var _narrator_update_callback: Callable


func load_timeline(instructions: Array[CinematicInstruction]) -> void:
	_timeline = instructions
	_timeline.sort_custom(
		func(a: CinematicInstruction, b: CinematicInstruction) -> bool:
			return a.time < b.time
	)
	_next_index = 0
	time_cursor = 0.0
	speed_multiplier = 1.0
	_pending_typewriters = 0
	_active_bubbles.clear()
	_current_gate = null
	_narrator_tw_active = false
	state = State.PLAYING


func process(delta: float) -> void:
	if _narrator_tw_active:
		_update_narrator_typewriter(delta)

	match state:
		State.PLAYING, State.FAST_FORWARDING:
			_advance_cursor(delta)
		State.WAITING_FOR_GATE:
			_check_gate_release()


func _advance_cursor(delta: float) -> void:
	time_cursor += delta * speed_multiplier

	while _next_index < _timeline.size():
		var instruction = _timeline[_next_index]

		if instruction.time > time_cursor:
			break

		if instruction is GateInstruction:
			_hit_gate(instruction)
			return

		_next_index += 1
		instruction_fired.emit(instruction)

	if _next_index >= _timeline.size() and _pending_typewriters <= 0 and not _narrator_tw_active:
		_complete()


func _hit_gate(gate: GateInstruction) -> void:
	_current_gate = gate
	_next_index += 1
	time_cursor = gate.time
	speed_multiplier = 1.0

	if gate.wait_for_typewriter and (_pending_typewriters > 0 or _narrator_tw_active):
		state = State.WAITING_FOR_GATE
	else:
		state = State.WAITING_FOR_GATE
	gate_reached.emit()


func _check_gate_release() -> void:
	if _current_gate and _current_gate.wait_for_typewriter:
		if _pending_typewriters > 0 or _narrator_tw_active:
			return


## Handle user input (SPACE/click).
## Returns true if the caller should do nothing (timeline handles advancement).
## The instruction_fired signal drives all actions — caller just needs to dispatch.
func on_input() -> bool:
	match state:
		State.PLAYING:
			speed_multiplier = FAST_FORWARD_SPEED
			_fast_forward_typewriters()
			state = State.FAST_FORWARDING
			return true
		State.FAST_FORWARDING:
			return true
		State.WAITING_FOR_GATE:
			if _current_gate and _current_gate.wait_for_typewriter:
				if _pending_typewriters > 0 or _narrator_tw_active:
					_fast_forward_typewriters()
					return true
			_current_gate = null
			state = State.PLAYING
			return true
		_:
			return false

#region Typewriter Tracking

func register_bubble(bubble: SpeechBubble) -> void:
	_active_bubbles.append(bubble)
	_pending_typewriters += 1
	bubble.typewriter_finished.connect(_on_bubble_finished.bind(bubble), CONNECT_ONE_SHOT)


func start_narrator(text: String, update_callback: Callable) -> void:
	_narrator_update_callback = update_callback
	_narrator_tw_text = text
	_narrator_tw_index = 0
	_narrator_tw_accum = 0.0
	_narrator_tw_speed = 1.0
	_narrator_tw_active = true
	_pending_typewriters += 1


func get_active_bubbles() -> Array[SpeechBubble]:
	return _active_bubbles


func is_narrator_active() -> bool:
	return _narrator_tw_active


func stop_all_typewriters() -> void:
	for b in _active_bubbles:
		if is_instance_valid(b) and b.is_typewriting():
			b.stop_typewriter()
	_pending_typewriters = 0
	_narrator_tw_active = false


func dismiss_bubbles() -> void:
	_active_bubbles.clear()
	_pending_typewriters = 0

#endregion

#region Reset / Complete

func reset() -> void:
	state = State.IDLE
	time_cursor = 0.0
	speed_multiplier = 1.0
	_next_index = 0
	_timeline.clear()
	_pending_typewriters = 0
	_active_bubbles.clear()
	_current_gate = null
	_narrator_tw_active = false
	_narrator_tw_text = ""


func _complete() -> void:
	state = State.COMPLETE
	_narrator_tw_active = false
	_active_bubbles.clear()
	timeline_complete.emit()

#endregion

#region Narrator Typewriter

func _fast_forward_typewriters() -> void:
	for bubble in _active_bubbles:
		if is_instance_valid(bubble) and bubble.is_typewriting():
			bubble.set_speed(FAST_FORWARD_SPEED)
	_narrator_tw_speed = FAST_FORWARD_SPEED


func _on_bubble_finished(_bubble: SpeechBubble) -> void:
	_pending_typewriters -= 1
	if _pending_typewriters < 0:
		_pending_typewriters = 0


func _update_narrator_typewriter(delta: float) -> void:
	var effective_speed = _narrator_tw_speed
	if state == State.FAST_FORWARDING:
		effective_speed = FAST_FORWARD_SPEED

	_narrator_tw_accum += delta * effective_speed
	while _narrator_tw_accum > 0.0 and _narrator_tw_index < _narrator_tw_text.length():
		var ch = _narrator_tw_text[_narrator_tw_index]
		_narrator_tw_index += 1
		if _narrator_update_callback.is_valid():
			_narrator_update_callback.call(_narrator_tw_index)
		_narrator_tw_accum -= _get_narrator_delay(ch)

	if _narrator_tw_index >= _narrator_tw_text.length():
		_narrator_tw_active = false
		_pending_typewriters -= 1
		if _pending_typewriters < 0:
			_pending_typewriters = 0


static func _get_narrator_delay(ch: String) -> float:
	match ch:
		".", "!", "?":
			return NARRATOR_SENTENCE_DELAY
		",", ";", ":":
			return NARRATOR_COMMA_DELAY
		_:
			return NARRATOR_CHAR_DELAY

#endregion
