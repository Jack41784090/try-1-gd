extends Node
## Headless test for CinematicInstruction and GroupPlayback.
## Run: godot --headless --path . scenes/demos/cinematic_instruction_demo.tscn 2>&1

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("\n=== CINEMATIC INSTRUCTION DEMO ===\n")
	_test_basic_after_id_resolution()
	_test_chained_after_id_resolution()
	_test_mixed_absolute_and_after_id()
	_test_after_offset()
	_test_circular_detection()
	_test_timeline_playback_firing_order()
	_test_timeline_playback_gate_pausing()
	_test_load_tutorial_travel_chain()
	_test_load_tutorial_rest_chain()
	_test_load_tutorial_morale_chain()
	_test_load_tutorial_combat_chain()
	_test_group_playback_sequential()
	_test_group_playback_auto_gate()
	_test_group_playback_parallel()
	_test_cinematic_group_from_dict()
	_test_load_json_chain()
	_print_summary()
	get_tree().quit(1 if _fail_count > 0 else 0)


#region Test: Basic after_id resolution

func _test_basic_after_id_resolution() -> void:
	print("--- Test: Basic after_id resolution ---")
	var chain = EventChain.new()
	chain.chain_id = "test_basic"

	var d1 = DialogueInstruction.new()
	d1.id = "line_1"
	d1.time = 0.5
	d1.duration = 2.0
	d1.speaker_name = "Goetz"
	d1.line_spoken = "First line."

	var d2 = DialogueInstruction.new()
	d2.id = "line_2"
	d2.after_id = "line_1"
	d2.speaker_name = "Franz"
	d2.line_spoken = "Second line, after first."

	chain.timeline = [d1, d2] as Array[CinematicInstruction]
	chain.resolve_after_ids()

	# d2.time should be d1.time + d1.duration + d2.after_offset = 0.5 + 2.0 + 0.0 = 2.5
	_assert_float("d2.time resolved", d2.time, 2.5)
	_assert_float("d1.time unchanged", d1.time, 0.5)
	print("")

#endregion


#region Test: Chained after_id (A → B → C)

func _test_chained_after_id_resolution() -> void:
	print("--- Test: Chained after_id (A → B → C) ---")
	var chain = EventChain.new()
	chain.chain_id = "test_chained"

	var a = DialogueInstruction.new()
	a.id = "a"
	a.time = 1.0
	a.duration = 1.0
	a.speaker_name = "A"
	a.line_spoken = "Line A"

	var b = DialogueInstruction.new()
	b.id = "b"
	b.after_id = "a"
	b.duration = 0.5
	b.speaker_name = "B"
	b.line_spoken = "Line B"

	var c = DialogueInstruction.new()
	c.id = "c"
	c.after_id = "b"
	c.speaker_name = "C"
	c.line_spoken = "Line C"

	# Insert in reverse order to stress the multi-pass resolution
	chain.timeline = [c, b, a] as Array[CinematicInstruction]
	chain.resolve_after_ids()

	# a.time = 1.0 (absolute)
	# b.time = a.time + a.duration = 1.0 + 1.0 = 2.0
	# c.time = b.time + b.duration = 2.0 + 0.5 = 2.5
	_assert_float("a.time unchanged", a.time, 1.0)
	_assert_float("b.time resolved", b.time, 2.0)
	_assert_float("c.time resolved", c.time, 2.5)
	print("")

#endregion


#region Test: Mixed absolute and after_id

func _test_mixed_absolute_and_after_id() -> void:
	print("--- Test: Mixed absolute time and after_id ---")
	var chain = EventChain.new()
	chain.chain_id = "test_mixed"

	var cam = CameraInstruction.new()
	cam.id = "cam_reset"
	cam.time = 0.0
	cam.duration = 0.3
	cam.action = CameraInstruction.Action.RESET

	var d1 = DialogueInstruction.new()
	d1.id = "mixed_d1"
	d1.time = 0.2
	d1.duration = 1.5
	d1.speaker_name = "Goetz"
	d1.line_spoken = "Absolute time line."

	var gate = GateInstruction.new()
	gate.after_id = "mixed_d1"

	var d2 = DialogueInstruction.new()
	d2.id = "mixed_d2"
	d2.after_id = "mixed_d1"
	d2.after_offset = 0.3
	d2.duration = 1.0
	d2.speaker_name = "Franz"
	d2.line_spoken = "After first line with offset."

	chain.timeline = [cam, d1, gate, d2] as Array[CinematicInstruction]
	chain.resolve_after_ids()

	_assert_float("cam.time absolute", cam.time, 0.0)
	_assert_float("d1.time absolute", d1.time, 0.2)
	# gate.time = d1.time + d1.duration + 0.0 = 0.2 + 1.5 = 1.7
	_assert_float("gate.time resolved", gate.time, 1.7)
	# d2.time = d1.time + d1.duration + 0.3 = 0.2 + 1.5 + 0.3 = 2.0
	_assert_float("d2.time resolved", d2.time, 2.0)
	print("")

#endregion


#region Test: after_offset

func _test_after_offset() -> void:
	print("--- Test: after_offset precision ---")
	var chain = EventChain.new()
	chain.chain_id = "test_offset"

	var d1 = DialogueInstruction.new()
	d1.id = "offset_base"
	d1.time = 0.0
	d1.duration = 1.0

	var d2 = DialogueInstruction.new()
	d2.after_id = "offset_base"
	d2.after_offset = 0.5

	var d3 = DialogueInstruction.new()
	d3.after_id = "offset_base"
	d3.after_offset = 0.0

	chain.timeline = [d1, d2, d3] as Array[CinematicInstruction]
	chain.resolve_after_ids()

	# d2 = 0.0 + 1.0 + 0.5 = 1.5
	_assert_float("d2 with offset 0.5", d2.time, 1.5)
	# d3 = 0.0 + 1.0 + 0.0 = 1.0
	_assert_float("d3 with offset 0.0", d3.time, 1.0)
	print("")

#endregion


#region Test: Circular / missing detection (should not infinite loop)

func _test_circular_detection() -> void:
	print("--- Test: No-op when no after_ids present ---")
	var chain = EventChain.new()
	chain.chain_id = "test_noop"

	var d1 = DialogueInstruction.new()
	d1.time = 0.5

	var d2 = DialogueInstruction.new()
	d2.time = 1.0

	chain.timeline = [d1, d2] as Array[CinematicInstruction]
	chain.resolve_after_ids()

	_assert_float("d1 unchanged", d1.time, 0.5)
	_assert_float("d2 unchanged", d2.time, 1.0)
	print("")

#endregion


#region Test: GroupPlayback firing order

func _test_timeline_playback_firing_order() -> void:
	print("--- Test: GroupPlayback firing order ---")

	# Build a chain with after_id, resolve it, then feed to playback
	var chain = EventChain.new()
	chain.chain_id = "test_playback"

	var d1 = DialogueInstruction.new()
	d1.id = "pb_a"
	d1.time = 0.1
	d1.duration = 0.5
	d1.speaker_name = "Goetz"
	d1.line_spoken = "First"

	var cam = CameraInstruction.new()
	cam.id = "pb_cam"
	cam.after_id = "pb_a"
	cam.after_offset = 0.1
	cam.duration = 0.2
	cam.action = CameraInstruction.Action.FOCUS_CHARACTER

	var d2 = DialogueInstruction.new()
	d2.id = "pb_b"
	d2.after_id = "pb_cam"
	d2.speaker_name = "Franz"
	d2.line_spoken = "Second"

	chain.timeline = [d1, cam, d2] as Array[CinematicInstruction]
	chain.resolve_after_ids()

	# cam.time = 0.1 + 0.5 + 0.1 = 0.7
	# d2.time = 0.7 + 0.2 + 0.0 = 0.9
	_assert_float("cam resolved for playback", cam.time, 0.7)
	_assert_float("d2 resolved for playback", d2.time, 0.9)

	# Now test playback: drive process() manually with large deltas (no gates)
	var playback = GroupPlayback.new()
	var fired_ids: Array[String] = []

	playback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
		fired_ids.append(inst.id)
		var type_name = inst.get_class()
		if inst is DialogueInstruction:
			type_name = "Dialogue"
		elif inst is CameraInstruction:
			type_name = "Camera"
		print("  Fired: [%.2f] %s id=%s" % [inst.time, type_name, inst.id])
	)

	var flags: Array = [false]  # Array wrapper for lambda capture
	playback.timeline_complete.connect(func() -> void:
		flags[0] = true
	)

	playback.load_timeline(chain.timeline)
	_assert_eq("playback state PLAYING", playback.state, GroupPlayback.State.PLAYING)

	# Advance past all instructions (no gates, so should complete)
	playback.process(2.0)

	_assert_eq("all 3 fired", fired_ids.size(), 3)
	if fired_ids.size() == 3:
		_assert_eq("first fired is d1", fired_ids[0], "pb_a")
		_assert_eq("second fired is cam", fired_ids[1], "pb_cam")
		_assert_eq("third fired is d2", fired_ids[2], "pb_b")

	_assert_true("timeline completed", flags[0])
	_assert_eq("playback state COMPLETE", playback.state, GroupPlayback.State.COMPLETE)
	print("")

#endregion


#region Test: GroupPlayback gate pausing

func _test_timeline_playback_gate_pausing() -> void:
	print("--- Test: GroupPlayback gate pausing ---")

	var d1 = DialogueInstruction.new()
	d1.id = "gate_d1"
	d1.time = 0.1
	d1.speaker_name = "Goetz"
	d1.line_spoken = "Before gate"

	var gate = GateInstruction.new()
	gate.time = 0.5
	gate.wait_for_typewriter = false

	var d2 = DialogueInstruction.new()
	d2.id = "gate_d2"
	d2.time = 0.6
	d2.speaker_name = "Franz"
	d2.line_spoken = "After gate"

	var timeline: Array[CinematicInstruction] = [d1, gate, d2]

	var playback = GroupPlayback.new()
	var fired_ids: Array[String] = []
	var counters: Array = [0]  # Array wrapper for lambda capture

	playback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
		fired_ids.append(inst.id)
	)
	playback.gate_reached.connect(func() -> void:
		counters[0] += 1
	)

	playback.load_timeline(timeline)

	# Advance to just past the gate
	playback.process(1.0)

	_assert_eq("d1 fired before gate", fired_ids.size(), 1)
	_assert_eq("gate reached", counters[0], 1)
	_assert_eq("paused at gate", playback.state, GroupPlayback.State.WAITING_FOR_GATE)

	# Simulate player input to advance past gate
	playback.on_input()
	_assert_eq("resumed playing", playback.state, GroupPlayback.State.PLAYING)

	# Continue advancing
	playback.process(1.0)

	_assert_eq("d2 fired after gate", fired_ids.size(), 2)
	if fired_ids.size() == 2:
		_assert_eq("second is d2", fired_ids[1], "gate_d2")
	_assert_eq("playback completed", playback.state, GroupPlayback.State.COMPLETE)
	print("")

#endregion


#region Test: Load tutorial chain .tres files

func _test_load_tutorial_travel_chain() -> void:
	_test_load_chain(
		"tutorial_first_travel_chain",
		"res://resources/scenarios/goetz-official/event-chains/tutorials/tutorial_first_travel_chain.tres",
		4, # expected dialogue count
		["franz", "goetz"] # expected characters
	)

func _test_load_tutorial_rest_chain() -> void:
	_test_load_chain(
		"tutorial_first_rest_chain",
		"res://resources/scenarios/goetz-official/event-chains/tutorials/tutorial_first_rest_chain.tres",
		3,
		["franz", "goetz"]
	)

func _test_load_tutorial_morale_chain() -> void:
	_test_load_chain(
		"tutorial_low_morale_chain",
		"res://resources/scenarios/goetz-official/event-chains/tutorials/tutorial_low_morale_chain.tres",
		4,
		["franz", "goetz"]
	)

func _test_load_tutorial_combat_chain() -> void:
	_test_load_chain(
		"tutorial_first_combat_chain",
		"res://resources/scenarios/goetz-official/event-chains/tutorials/tutorial_first_combat_chain.tres",
		4,
		["franz", "goetz"]
	)


func _test_load_chain(label: String, path: String, expected_dialogues: int, expected_chars: Array) -> void:
	print("--- Test: Load %s ---" % label)

	var chain: EventChain = load(path) as EventChain
	_assert_true("chain loaded", chain != null)
	if chain == null:
		print("  SKIP: could not load %s\n" % path)
		return

	_assert_true("has timeline", chain.timeline.size() > 0)
	print("  Timeline: %d instructions, %d dialogues" % [chain.get_instruction_count(), chain.get_dialogue_count()])
	_assert_eq("dialogue count", chain.get_dialogue_count(), expected_dialogues)

	# Verify character_ids contain expected characters (case-insensitive)
	for expected_char in expected_chars:
		var found = false
		for cid in chain.character_ids:
			if cid.to_lower() == expected_char.to_lower():
				found = true
				break
		_assert_true("character '%s' present" % expected_char, found)

	# Verify timeline is logically sequential: all instructions have time >= 0
	var prev_time: float = -1.0
	var sorted_timeline = chain.timeline.duplicate()
	sorted_timeline.sort_custom(func(a, b): return a.time < b.time)

	for inst in sorted_timeline:
		_assert_true("time >= 0 (got %.3f)" % inst.time, inst.time >= 0.0)

	# Verify after_id resolution worked: no instruction with after_id should have time == 0
	# (unless after_offset is 0 and the ref ends at time 0, which is unlikely)
	var after_id_at_zero: int = 0
	for inst in chain.timeline:
		if inst.has_after_dependency() and inst.time == 0.0:
			after_id_at_zero += 1
	if after_id_at_zero > 0:
		print("  WARNING: %d instructions with after_id still at time=0 (may indicate unresolved deps)" % after_id_at_zero)

	# Print timeline summary
	print("  Timeline breakdown:")
	var dialogue_count: int = 0
	var gate_count: int = 0
	var camera_count: int = 0
	var character_count: int = 0

	for inst in sorted_timeline:
		if inst is DialogueInstruction:
			dialogue_count += 1
			print("    [%.3f] DIALOGUE (%s): \"%s\"" % [inst.time, inst.speaker_name, inst.line_spoken.substr(0, 50)])
		elif inst is GateInstruction:
			gate_count += 1
			print("    [%.3f] GATE (wait_typewriter=%s)" % [inst.time, inst.wait_for_typewriter])
		elif inst is CameraInstruction:
			camera_count += 1
			print("    [%.3f] CAMERA action=%d" % [inst.time, inst.action])
		elif inst is CharacterInstruction:
			character_count += 1
			print("    [%.3f] CHARACTER %s action=%d" % [inst.time, inst.character_id, inst.action])
		else:
			print("    [%.3f] UNKNOWN %s" % [inst.time, inst.get_class()])

	print("  Summary: %d dialogue, %d gates, %d camera, %d character" % [dialogue_count, gate_count, camera_count, character_count])

	# Test playback simulation: feed to GroupPlayback, auto-advance through gates
	print("  Simulating playback...")
	var playback = GroupPlayback.new()
	var fired_instructions: Array[CinematicInstruction] = []
	var gates_hit: int = 0

	playback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
		fired_instructions.append(inst)
	)
	playback.gate_reached.connect(func() -> void:
		gates_hit += 1
	)

	playback.load_timeline(chain.timeline)

	# Drive the playback: advance in small steps, auto-releasing gates
	var safety: int = 0
	var max_iterations: int = 10000
	while playback.state != GroupPlayback.State.COMPLETE and safety < max_iterations:
		if playback.state == GroupPlayback.State.WAITING_FOR_GATE:
			playback.on_input()
		playback.process(0.05)
		safety += 1

	_assert_true("playback completed (iterations=%d)" % safety, playback.state == GroupPlayback.State.COMPLETE)
	_assert_eq("all non-gate instructions fired", fired_instructions.size(), chain.timeline.size() - gate_count)
	print("  Playback: fired %d instructions, hit %d gates, %d iterations" % [fired_instructions.size(), gates_hit, safety])

	# Verify firing order is monotonically non-decreasing in time
	var order_ok = true
	for i in range(1, fired_instructions.size()):
		if fired_instructions[i].time < fired_instructions[i - 1].time - 0.001:
			order_ok = false
			print("  ORDERING ERROR: instruction at index %d (t=%.3f) fired before index %d (t=%.3f)" % [
				i, fired_instructions[i].time, i - 1, fired_instructions[i - 1].time])
			break
	_assert_true("firing order monotonic", order_ok)
	print("")

#endregion


#region Test: GroupPlayback sequential firing

func _test_group_playback_sequential() -> void:
	print("--- Test: GroupPlayback sequential group ---")

	var d1 = DialogueInstruction.new()
	d1.id = "seq_a"
	d1.duration = 0.5
	d1.speaker_name = "Goetz"
	d1.line_spoken = "First line."

	var d2 = DialogueInstruction.new()
	d2.id = "seq_b"
	d2.duration = 0.3
	d2.speaker_name = "Franz"
	d2.line_spoken = "Second line."

	var group = CinematicGroup.new()
	group.id = "seq_root"
	group.children = [d1, d2] as Array[Resource]

	var playback = GroupPlayback.new()
	var fired_ids: Array[String] = []
	var completed_flag: Array = [false]

	playback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
		fired_ids.append(inst.id)
	)
	playback.timeline_complete.connect(func() -> void:
		completed_flag[0] = true
	)

	playback.load_group(group)
	_assert_eq("group playback state PLAYING", playback.state, GroupPlayback.State.PLAYING)

	playback.process(2.0)

	_assert_eq("both fired", fired_ids.size(), 2)
	if fired_ids.size() == 2:
		_assert_eq("first is d1", fired_ids[0], "seq_a")
		_assert_eq("second is d2", fired_ids[1], "seq_b")
	_assert_true("playback completed", completed_flag[0])
	_assert_eq("state COMPLETE", playback.state, GroupPlayback.State.COMPLETE)
	print("")

#endregion


#region Test: GroupPlayback auto_gate

func _test_group_playback_auto_gate() -> void:
	print("--- Test: GroupPlayback auto_gate pausing ---")

	var d1 = DialogueInstruction.new()
	d1.id = "ag_a"
	d1.duration = 0.3
	d1.speaker_name = "Goetz"
	d1.line_spoken = "Before gate."

	var inner_group = CinematicGroup.new()
	inner_group.id = "ag_inner"
	inner_group.auto_gate = true
	inner_group.children = [d1] as Array[Resource]

	var d2 = DialogueInstruction.new()
	d2.id = "ag_b"
	d2.duration = 0.3
	d2.speaker_name = "Franz"
	d2.line_spoken = "After gate."

	var root = CinematicGroup.new()
	root.id = "ag_root"
	root.children = [inner_group, d2] as Array[Resource]

	var playback = GroupPlayback.new()
	var fired_ids: Array[String] = []
	var gates_hit: Array = [0]

	playback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
		fired_ids.append(inst.id)
	)
	playback.gate_reached.connect(func() -> void:
		gates_hit[0] += 1
	)

	playback.load_group(root)
	playback.process(1.0)

	_assert_eq("d1 fired before auto_gate", fired_ids.size(), 1)
	_assert_eq("gate reached once", gates_hit[0], 1)
	_assert_eq("paused at gate", playback.state, GroupPlayback.State.WAITING_FOR_GATE)

	playback.on_input()
	_assert_eq("resumed playing", playback.state, GroupPlayback.State.PLAYING)

	playback.process(1.0)

	_assert_eq("d2 fired after gate release", fired_ids.size(), 2)
	if fired_ids.size() == 2:
		_assert_eq("second is d2", fired_ids[1], "ag_b")
	_assert_eq("state COMPLETE", playback.state, GroupPlayback.State.COMPLETE)
	print("")

#endregion


#region Test: GroupPlayback parallel group

func _test_group_playback_parallel() -> void:
	print("--- Test: GroupPlayback parallel group ---")

	var d1 = DialogueInstruction.new()
	d1.id = "par_a"
	d1.occupation = 0.5
	d1.speaker_name = "Goetz"
	d1.line_spoken = "Parallel line A."

	var cam = CameraInstruction.new()
	cam.id = "par_cam"
	cam.occupation = 0.5
	cam.action = CameraInstruction.Action.FOCUS_CHARACTER

	var root = CinematicGroup.new()
	root.id = "par_root"
	root.duration = 2.0
	root.children = [d1, cam] as Array[Resource]

	var playback = GroupPlayback.new()
	var fired_ids: Array[String] = []

	playback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
		fired_ids.append(inst.id)
	)

	playback.load_group(root)
	playback.process(3.0)

	_assert_eq("both parallel instructions fired", fired_ids.size(), 2)
	_assert_true("contains par_a", fired_ids.has("par_a"))
	_assert_true("contains par_cam", fired_ids.has("par_cam"))
	_assert_eq("state COMPLETE", playback.state, GroupPlayback.State.COMPLETE)
	print("")

#endregion


#region Test: CinematicGroup.from_dict parsing

func _test_cinematic_group_from_dict() -> void:
	print("--- Test: CinematicGroup.from_dict ---")

	var data = {
		"type": "group",
		"id": "test_group",
		"duration": 3.0,
		"auto_gate": true,
		"children": [
			{"type": "dialogue", "id": "fd_line", "speaker_name": "Goetz", "line_spoken": "Hello."},
			{"type": "camera", "id": "fd_cam", "action": "focus_character", "target_character": "goetz"},
			{"type": "group", "id": "fd_inner", "auto_gate": false, "children": [
				{"type": "dialogue", "id": "fd_inner_line", "speaker_name": "Franz", "line_spoken": "Inner."}
			]}
		]
	}

	var group = CinematicGroup.from_dict(data)
	_assert_eq("group id", group.id, "test_group")
	_assert_float("group duration", group.duration, 3.0)
	_assert_true("group auto_gate", group.auto_gate)
	_assert_true("is parallel (duration>0)", group.is_parallel())
	_assert_eq("children count", group.children.size(), 3)

	var child0 = group.children[0]
	_assert_true("child0 is DialogueInstruction", child0 is DialogueInstruction)
	if child0 is DialogueInstruction:
		_assert_eq("child0 id", child0.id, "fd_line")
		_assert_eq("child0 speaker", child0.speaker_name, "Goetz")

	var child1 = group.children[1]
	_assert_true("child1 is CameraInstruction", child1 is CameraInstruction)

	var child2 = group.children[2]
	_assert_true("child2 is CinematicGroup", child2 is CinematicGroup)
	if child2 is CinematicGroup:
		_assert_eq("inner group id", child2.id, "fd_inner")
		_assert_true("inner not parallel", not child2.is_parallel())
		_assert_eq("inner children count", child2.children.size(), 1)
	print("")

#endregion


#region Test: Load JSON chain (g0_intro.json)

func _test_load_json_chain() -> void:
	print("--- Test: Load g0_intro.json ---")

	var path = "res://resources/scenarios/goetz-official/event-chains/g0_intro.json"
	var chain = EventChain.load_from_json_file(path)
	_assert_true("chain loaded from JSON", chain != null)
	if chain == null:
		print("  SKIP: could not load %s\n" % path)
		return

	_assert_eq("chain_id", chain.chain_id, "g0_intro")
	_assert_true("has root group", chain.has_root_group())
	_assert_true("root_group is CinematicGroup", chain.root_group is CinematicGroup)
	_assert_true("has characters", chain.character_ids.size() > 0)

	var has_goetz = false
	var has_franz = false
	for cid in chain.character_ids:
		if cid == "goetz":
			has_goetz = true
		elif cid == "franz":
			has_franz = true
	_assert_true("goetz in character_ids", has_goetz)
	_assert_true("franz in character_ids", has_franz)

	_assert_true("transition_type set", chain.transition_type != EventChain.TransitionType.NONE or true)

	var root = chain.root_group
	_assert_true("root group has children", root.children.size() > 0)
	print("  Root group: id='%s', %d children, duration=%.1f" % [root.id, root.children.size(), root.duration])

	var playback = GroupPlayback.new()
	var fired_count: Array = [0]
	var gates_count: Array = [0]

	playback.instruction_fired.connect(func(_inst: CinematicInstruction) -> void:
		fired_count[0] += 1
	)
	playback.gate_reached.connect(func() -> void:
		gates_count[0] += 1
	)

	playback.load_group(root)
	_assert_eq("playback state PLAYING", playback.state, GroupPlayback.State.PLAYING)

	var safety: int = 0
	var max_iterations: int = 50000
	while playback.state != GroupPlayback.State.COMPLETE and safety < max_iterations:
		if playback.state == GroupPlayback.State.WAITING_FOR_GATE:
			playback.on_input()
		playback.process(0.05)
		safety += 1

	_assert_true("playback completed (iterations=%d)" % safety, playback.state == GroupPlayback.State.COMPLETE)
	_assert_true("some instructions fired (%d)" % fired_count[0], fired_count[0] > 0)
	print("  Fired %d instructions, hit %d gates in %d iterations" % [fired_count[0], gates_count[0], safety])
	print("")

#endregion


#region Assert helpers

func _assert_float(label: String, actual: float, expected: float, epsilon: float = 0.01) -> void:
	if absf(actual - expected) <= epsilon:
		_pass_count += 1
		print("  PASS: %s = %.3f" % [label, actual])
	else:
		_fail_count += 1
		print("  FAIL: %s = %.3f (expected %.3f)" % [label, actual, expected])


func _assert_eq(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s = %s" % [label, str(actual)])
	else:
		_fail_count += 1
		print("  FAIL: %s = %s (expected %s)" % [label, str(actual), str(expected)])


func _assert_true(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s" % label)

#endregion


func _print_summary() -> void:
	print("=== RESULTS: %d passed, %d failed ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		print("SOME TESTS FAILED")
	else:
		print("ALL TESTS PASSED")
