class_name GroupPlayback
extends RefCounted
## Group-based cinematic playback engine. Replaces TimelinePlayback.
## Processes a tree of CinematicGroups and CinematicInstructions.
## Groups with duration > 0 run children in parallel (occupation-based).
## Groups with duration <= 0 run children sequentially.

enum State {IDLE, PLAYING, WAITING_FOR_GATE, FAST_FORWARDING, COMPLETE}

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
var speed_multiplier: float = 1.0

var _pending_typewriters: int = 0
var _active_bubbles: Array[SpeechBubble] = []

var _narrator_tw_active: bool = false
var _narrator_tw_text: String = ""
var _narrator_tw_index: int = 0
var _narrator_tw_accum: float = 0.0
var _narrator_tw_speed: float = 1.0
var _narrator_update_callback: Callable

var _root_node: _GroupNode = null
var _all_nodes: Array[_PlayNode] = []
var _gate_pending: bool = false


func load_group(group: CinematicGroup) -> void:
	reset()
	_root_node = _build_group_node(group, 0.0)
	_flatten_nodes(_root_node)
	_all_nodes.sort_custom(func(a: _PlayNode, b: _PlayNode) -> bool: return a.start_time < b.start_time)
	state = State.PLAYING


func load_timeline(instructions: Array[CinematicInstruction]) -> void:
	reset()
	var wrapper = CinematicGroup.new()
	for inst in instructions:
		wrapper.children.append(inst)
	if _has_gates(instructions):
		_load_flat_timeline(instructions)
	else:
		load_group(wrapper)


func _has_gates(instructions: Array[CinematicInstruction]) -> bool:
	for inst in instructions:
		if inst is GateInstruction:
			return true
	return false


func _load_flat_timeline(instructions: Array[CinematicInstruction]) -> void:
	reset()
	var sorted = instructions.duplicate()
	sorted.sort_custom(func(a: CinematicInstruction, b: CinematicInstruction) -> bool: return a.time < b.time)
	for inst in sorted:
		var node = _InstructionNode.new()
		node.instruction = inst
		node.start_time = inst.time
		node.computed_duration = inst.duration
		node.is_gate = inst is GateInstruction
		if inst is GateInstruction:
			node.wait_for_typewriter = inst.wait_for_typewriter
		_all_nodes.append(node)
	state = State.PLAYING


func process(delta: float) -> void:
	if _narrator_tw_active:
		_update_narrator_typewriter(delta)

	match state:
		State.PLAYING, State.FAST_FORWARDING:
			_advance(delta)
		State.WAITING_FOR_GATE:
			_check_gate_release()


func _advance(delta: float) -> void:
	var effective_delta = delta * speed_multiplier
	var any_pending = false

	for node in _all_nodes:
		if node.completed:
			continue
		if node.is_gate and not node.fired:
			node.elapsed += effective_delta
			if node.elapsed >= node.start_time:
				node.fired = true
				_hit_gate(node)
				return
			any_pending = true
			continue

		node.elapsed += effective_delta
		if node.elapsed >= node.start_time and not node.fired:
			node.fired = true
			if node is _InstructionNode:
				instruction_fired.emit(node.instruction)
			elif node is _GroupNode and node.group.gated_group:
				pass

		if node.fired and not node.completed:
			var end_time = node.start_time + node.computed_duration
			if node.elapsed >= end_time:
				node.completed = true
				if node is _GroupNode and node.group.gated_group:
					_gate_pending = true
					_hit_auto_gate()
					return
			else:
				any_pending = true
		elif not node.fired:
			any_pending = true

	if not any_pending and _pending_typewriters <= 0 and not _narrator_tw_active:
		_complete()


func _hit_gate(node: _PlayNode) -> void:
	speed_multiplier = 1.0
	if node is _InstructionNode and node.wait_for_typewriter and (_pending_typewriters > 0 or _narrator_tw_active):
		state = State.WAITING_FOR_GATE
	else:
		state = State.WAITING_FOR_GATE
	node.completed = true
	gate_reached.emit()


func _hit_auto_gate() -> void:
	speed_multiplier = 1.0
	state = State.WAITING_FOR_GATE
	gate_reached.emit()


func _check_gate_release() -> void:
	if _pending_typewriters > 0 or _narrator_tw_active:
		return


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
			if _pending_typewriters > 0 or _narrator_tw_active:
				_fast_forward_typewriters()
				return true
			_gate_pending = false
			state = State.PLAYING
			return true
		_:
			return false


#region Node Tree Building

func _build_group_node(group: CinematicGroup, parent_start: float) -> _GroupNode:
	var gnode = _GroupNode.new()
	gnode.group = group
	gnode.start_time = parent_start
	gnode.elapsed = 0.0

	if group.is_parallel():
		gnode.computed_duration = group.duration
		var fill_children: Array[_PlayNode] = []
		var occupied: float = 0.0

		for child in group.children:
			var cnode = _build_child(child, parent_start, group.duration)
			if child is CinematicInstruction and is_equal_approx(child.occupation, CinematicInstruction.OCCUPATION_FILL):
				fill_children.append(cnode)
			else:
				var occ = _get_occupation(child)
				if occ > 0.0:
					occupied += occ
			gnode.child_nodes.append(cnode)

		var remaining = maxf(0.0, 1.0 - occupied)
		if not fill_children.is_empty():
			var fill_each = remaining / float(fill_children.size())
			for fc in fill_children:
				fc.computed_duration = fill_each * group.duration
	else:
		var cursor: float = parent_start
		for child in group.children:
			var cnode = _build_child(child, cursor, 0.0)
			gnode.child_nodes.append(cnode)
			cursor += cnode.computed_duration

		gnode.computed_duration = cursor - parent_start

	return gnode


func _build_child(child, parent_start: float, parent_duration: float) -> _PlayNode:
	if child is CinematicGroup:
		var occ = _get_occupation(child)
		var child_dur = child.duration if child.duration > 0.0 else (occ * parent_duration if occ > 0.0 and parent_duration > 0.0 else 0.0)
		var cg = child.duplicate() if child.duration <= 0.0 and child_dur > 0.0 else child
		if child_dur > 0.0 and child.duration <= 0.0:
			cg.duration = child_dur
		return _build_group_node(cg, parent_start)
	elif child is CinematicInstruction:
		var inode = _InstructionNode.new()
		inode.instruction = child
		inode.start_time = parent_start if child.time <= 0.0 else child.time
		inode.is_gate = child is GateInstruction
		if child is GateInstruction:
			inode.wait_for_typewriter = child.wait_for_typewriter

		var occ = child.occupation
		if occ > 0.0 and parent_duration > 0.0:
			inode.computed_duration = occ * parent_duration
		elif child.duration > 0.0:
			inode.computed_duration = child.duration
		elif child is DialogueInstruction:
			inode.computed_duration = CinematicGroup._estimate_typewriter_duration(child.line_spoken)
		else:
			inode.computed_duration = 0.0
		return inode
	return null


func _get_occupation(child) -> float:
	if child is CinematicInstruction:
		return child.occupation if child.occupation > 0.0 else 0.0
	return 0.0


func _flatten_nodes(node: _PlayNode) -> void:
	if node is _GroupNode:
		for child in node.child_nodes:
			_flatten_nodes(child)
		if node != _root_node:
			_all_nodes.append(node)
	elif node is _InstructionNode:
		_all_nodes.append(node)

#endregion

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
	speed_multiplier = 1.0
	_all_nodes.clear()
	_root_node = null
	_pending_typewriters = 0
	_active_bubbles.clear()
	_gate_pending = false
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

#region Internal Node Types

class _PlayNode extends RefCounted:
	var start_time: float = 0.0
	var computed_duration: float = 0.0
	var elapsed: float = 0.0
	var fired: bool = false
	var completed: bool = false
	var is_gate: bool = false
	var wait_for_typewriter: bool = true


class _InstructionNode extends _PlayNode:
	var instruction: CinematicInstruction


class _GroupNode extends _PlayNode:
	var group: CinematicGroup
	var child_nodes: Array = []

#endregion
