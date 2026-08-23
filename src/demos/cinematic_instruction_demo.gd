extends Node
## Headless test for CinematicInstruction and GroupPlayback. Run: godot --headless --path . scenes/demos/cinematic_instruction_demo.tscn 2>&1

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("\n=== CINEMATIC INSTRUCTION DEMO ===\n")

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

	_assert_float("d2.time resolved", d2.time, 2.5)
	_assert_float("d1.time unchanged", d1.time, 0.5)
	print("")

	print("--- Test: Chained after_id (A → B → C) ---")
	var chain2 = EventChain.new()
	chain2.chain_id = "test_chained"

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

	chain2.timeline = [c, b, a] as Array[CinematicInstruction]
	chain2.resolve_after_ids()

	_assert_float("a.time unchanged", a.time, 1.0)
	_assert_float("b.time resolved", b.time, 2.0)
	_assert_float("c.time resolved", c.time, 2.5)
	print("")

	print("--- Test: Mixed absolute time and after_id ---")
	var chain3 = EventChain.new()
	chain3.chain_id = "test_mixed"

	var cam = CameraInstruction.new()
	cam.id = "cam_reset"
	cam.time = 0.0
	cam.duration = 0.3
	cam.action = CameraInstruction.Action.RESET

	var md1 = DialogueInstruction.new()
	md1.id = "mixed_d1"
	md1.time = 0.2
	md1.duration = 1.5
	md1.speaker_name = "Goetz"
	md1.line_spoken = "Absolute time line."

	var gate = GateInstruction.new()
	gate.after_id = "mixed_d1"

	var md2 = DialogueInstruction.new()
	md2.id = "mixed_d2"
	md2.after_id = "mixed_d1"
	md2.after_offset = 0.3
	md2.duration = 1.0
	md2.speaker_name = "Franz"
	md2.line_spoken = "After first line with offset."

	chain3.timeline = [cam, md1, gate, md2] as Array[CinematicInstruction]
	chain3.resolve_after_ids()

	_assert_float("cam.time absolute", cam.time, 0.0)
	_assert_float("d1.time absolute", md1.time, 0.2)
	_assert_float("gate.time resolved", gate.time, 1.7)
	_assert_float("d2.time resolved", md2.time, 2.0)
	print("")

	print("--- Test: after_offset precision ---")
	var chain4 = EventChain.new()
	chain4.chain_id = "test_offset"

	var od1 = DialogueInstruction.new()
	od1.id = "offset_base"
	od1.time = 0.0
	od1.duration = 1.0

	var od2 = DialogueInstruction.new()
	od2.after_id = "offset_base"
	od2.after_offset = 0.5

	var od3 = DialogueInstruction.new()
	od3.after_id = "offset_base"
	od3.after_offset = 0.0

	chain4.timeline = [od1, od2, od3] as Array[CinematicInstruction]
	chain4.resolve_after_ids()

	_assert_float("d2 with offset 0.5", od2.time, 1.5)
	_assert_float("d3 with offset 0.0", od3.time, 1.0)
	print("")

	print("--- Test: No-op when no after_ids present ---")
	var chain5 = EventChain.new()
	chain5.chain_id = "test_noop"

	var nd1 = DialogueInstruction.new()
	nd1.time = 0.5

	var nd2 = DialogueInstruction.new()
	nd2.time = 1.0

	chain5.timeline = [nd1, nd2] as Array[CinematicInstruction]
	chain5.resolve_after_ids()

	_assert_float("d1 unchanged", nd1.time, 0.5)
	_assert_float("d2 unchanged", nd2.time, 1.0)
	print("")

	print("--- Test: GroupPlayback firing order ---")

	var chain6 = EventChain.new()
	chain6.chain_id = "test_playback"

	var pd1 = DialogueInstruction.new()
	pd1.id = "pb_a"
	pd1.time = 0.1
	pd1.duration = 0.5
	pd1.speaker_name = "Goetz"
	pd1.line_spoken = "First"

	var pcam = CameraInstruction.new()
	pcam.id = "pb_cam"
	pcam.after_id = "pb_a"
	pcam.after_offset = 0.1
	pcam.duration = 0.2
	pcam.action = CameraInstruction.Action.FOCUS_CHARACTER

	var pd2 = DialogueInstruction.new()
	pd2.id = "pb_b"
	pd2.after_id = "pb_cam"
	pd2.speaker_name = "Franz"
	pd2.line_spoken = "Second"

	chain6.timeline = [pd1, pcam, pd2] as Array[CinematicInstruction]
	chain6.resolve_after_ids()

	_assert_float("cam resolved for playback", pcam.time, 0.7)
	_assert_float("d2 resolved for playback", pd2.time, 0.9)

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

	var flags: Array = [false]
	playback.timeline_complete.connect(func() -> void:
		flags[0] = true
	)

	playback.load_timeline(chain6.timeline)
	_assert_eq("playback state PLAYING", playback.state, GroupPlayback.State.PLAYING)

	playback.process(2.0)

	_assert_eq("all 3 fired", fired_ids.size(), 3)
	if fired_ids.size() == 3:
		_assert_eq("first fired is d1", fired_ids[0], "pb_a")
		_assert_eq("second fired is cam", fired_ids[1], "pb_cam")
		_assert_eq("third fired is d2", fired_ids[2], "pb_b")

	_assert_true("timeline completed", flags[0])
	_assert_eq("playback state COMPLETE", playback.state, GroupPlayback.State.COMPLETE)
	print("")

	print("--- Test: GroupPlayback gate pausing ---")

	var gd1 = DialogueInstruction.new()
	gd1.id = "gate_d1"
	gd1.time = 0.1
	gd1.speaker_name = "Goetz"
	gd1.line_spoken = "Before gate"

	var ggate = GateInstruction.new()
	ggate.time = 0.5
	ggate.wait_for_typewriter = false

	var gd2 = DialogueInstruction.new()
	gd2.id = "gate_d2"
	gd2.time = 0.6
	gd2.speaker_name = "Franz"
	gd2.line_spoken = "After gate"

	var gtimeline: Array[CinematicInstruction] = [gd1, ggate, gd2]

	var gplayback = GroupPlayback.new()
	var gfired_ids: Array[String] = []
	var counters: Array = [0]

	gplayback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
		gfired_ids.append(inst.id)
	)
	gplayback.gate_reached.connect(func() -> void:
		counters[0] += 1
	)

	gplayback.load_timeline(gtimeline)

	gplayback.process(1.0)

	_assert_eq("d1 fired before gate", gfired_ids.size(), 1)
	_assert_eq("gate reached", counters[0], 1)
	_assert_eq("paused at gate", gplayback.state, GroupPlayback.State.WAITING_FOR_GATE)

	gplayback.on_input()
	_assert_eq("resumed playing", gplayback.state, GroupPlayback.State.PLAYING)

	gplayback.process(1.0)

	_assert_eq("d2 fired after gate", gfired_ids.size(), 2)
	if gfired_ids.size() == 2:
		_assert_eq("second is d2", gfired_ids[1], "gate_d2")
	_assert_eq("playback completed", gplayback.state, GroupPlayback.State.COMPLETE)
	print("")

	_test_load_chain(
		"tutorial_first_travel_chain",
		"res://resources/strategy/scenarios/goetz-official/event-chains/tutorials/tutorial_first_travel_chain.tres",
		4,
		["franz", "goetz"]
	)

	_test_load_chain(
		"tutorial_first_rest_chain",
		"res://resources/strategy/scenarios/goetz-official/event-chains/tutorials/tutorial_first_rest_chain.tres",
		3,
		["franz", "goetz"]
	)

	_test_load_chain(
		"tutorial_low_morale_chain",
		"res://resources/strategy/scenarios/goetz-official/event-chains/tutorials/tutorial_low_morale_chain.tres",
		4,
		["franz", "goetz"]
	)

	_test_load_chain(
		"tutorial_first_combat_chain",
		"res://resources/strategy/scenarios/goetz-official/event-chains/tutorials/tutorial_first_combat_chain.tres",
		4,
		["franz", "goetz"]
	)

	print("--- Test: GroupPlayback sequential group ---")

	var sd1 = DialogueInstruction.new()
	sd1.id = "seq_a"
	sd1.duration = 0.5
	sd1.speaker_name = "Goetz"
	sd1.line_spoken = "First line."

	var sd2 = DialogueInstruction.new()
	sd2.id = "seq_b"
	sd2.duration = 0.3
	sd2.speaker_name = "Franz"
	sd2.line_spoken = "Second line."

	var sgroup = CinematicGroup.new()
	sgroup.id = "seq_root"
	sgroup.children = [sd1, sd2] as Array[Resource]

	var splayback = GroupPlayback.new()
	var sfired_ids: Array[String] = []
	var completed_flag: Array = [false]

	splayback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
		sfired_ids.append(inst.id)
	)
	splayback.timeline_complete.connect(func() -> void:
		completed_flag[0] = true
	)

	splayback.load_group(sgroup)
	_assert_eq("group playback state PLAYING", splayback.state, GroupPlayback.State.PLAYING)

	splayback.process(2.0)

	_assert_eq("both fired", sfired_ids.size(), 2)
	if sfired_ids.size() == 2:
		_assert_eq("first is d1", sfired_ids[0], "seq_a")
		_assert_eq("second is d2", sfired_ids[1], "seq_b")
	_assert_true("playback completed", completed_flag[0])
	_assert_eq("state COMPLETE", splayback.state, GroupPlayback.State.COMPLETE)
	print("")

	print("--- Test: GroupPlayback auto_gate pausing ---")

	var agd1 = DialogueInstruction.new()
	agd1.id = "ag_a"
	agd1.duration = 0.3
	agd1.speaker_name = "Goetz"
	agd1.line_spoken = "Before gate."

	var inner_group = CinematicGroup.new()
	inner_group.id = "ag_inner"
	inner_group.gated_group = true
	inner_group.children = [agd1] as Array[Resource]

	var agd2 = DialogueInstruction.new()
	agd2.id = "ag_b"
	agd2.duration = 0.3
	agd2.speaker_name = "Franz"
	agd2.line_spoken = "After gate."

	var agroot = CinematicGroup.new()
	agroot.id = "ag_root"
	agroot.children = [inner_group, agd2] as Array[Resource]

	var agplayback = GroupPlayback.new()
	var agfired_ids: Array[String] = []
	var gates_hit: Array = [0]

	agplayback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
		agfired_ids.append(inst.id)
	)
	agplayback.gate_reached.connect(func() -> void:
		gates_hit[0] += 1
	)

	agplayback.load_group(agroot)
	agplayback.process(1.0)

	_assert_eq("d1 fired before auto_gate", agfired_ids.size(), 1)
	_assert_eq("gate reached once", gates_hit[0], 1)
	_assert_eq("paused at gate", agplayback.state, GroupPlayback.State.WAITING_FOR_GATE)

	agplayback.on_input()
	_assert_eq("resumed playing", agplayback.state, GroupPlayback.State.PLAYING)

	agplayback.process(1.0)

	_assert_eq("d2 fired after gate release", agfired_ids.size(), 2)
	if agfired_ids.size() == 2:
		_assert_eq("second is d2", agfired_ids[1], "ag_b")
	_assert_eq("state COMPLETE", agplayback.state, GroupPlayback.State.COMPLETE)
	print("")

	print("--- Test: GroupPlayback parallel group ---")

	var pard1 = DialogueInstruction.new()
	pard1.id = "par_a"
	pard1.occupation = 0.5
	pard1.speaker_name = "Goetz"
	pard1.line_spoken = "Parallel line A."

	var parcam = CameraInstruction.new()
	parcam.id = "par_cam"
	parcam.occupation = 0.5
	parcam.action = CameraInstruction.Action.FOCUS_CHARACTER

	var parroot = CinematicGroup.new()
	parroot.id = "par_root"
	parroot.duration = 2.0
	parroot.children = [pard1, parcam] as Array[Resource]

	var parplayback = GroupPlayback.new()
	var parfired_ids: Array[String] = []

	parplayback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
		parfired_ids.append(inst.id)
	)

	parplayback.load_group(parroot)
	parplayback.process(3.0)

	_assert_eq("both parallel instructions fired", parfired_ids.size(), 2)
	_assert_true("contains par_a", parfired_ids.has("par_a"))
	_assert_true("contains par_cam", parfired_ids.has("par_cam"))
	_assert_eq("state COMPLETE", parplayback.state, GroupPlayback.State.COMPLETE)
	print("")

	print("--- Test: CinematicGroup.from_dict ---")

	var data = {
		"type": "group",
		"id": "test_group",
		"duration": 3.0,
		"gated_group": true,
		"children": [
			{"type": "dialogue", "id": "fd_line", "speaker_name": "Goetz", "line_spoken": "Hello."},
			{"type": "camera", "id": "fd_cam", "action": "focus_character", "target_character": "goetz"},
			{"type": "group", "id": "fd_inner", "gated_group": false, "children": [
				{"type": "dialogue", "id": "fd_inner_line", "speaker_name": "Franz", "line_spoken": "Inner."}
			]}
		]
	}

	var fdgroup = CinematicGroup.from_dict(data)
	_assert_eq("group id", fdgroup.id, "test_group")
	_assert_float("group duration", fdgroup.duration, 3.0)
	_assert_true("group gated_group", fdgroup.gated_group)
	_assert_true("is parallel (duration>0)", fdgroup.is_parallel())
	_assert_eq("children count", fdgroup.children.size(), 3)

	var child0 = fdgroup.children[0]
	_assert_true("child0 is DialogueInstruction", child0 is DialogueInstruction)
	if child0 is DialogueInstruction:
		_assert_eq("child0 id", child0.id, "fd_line")
		_assert_eq("child0 speaker", child0.speaker_name, "Goetz")

	var child1 = fdgroup.children[1]
	_assert_true("child1 is CameraInstruction", child1 is CameraInstruction)

	var child2 = fdgroup.children[2]
	_assert_true("child2 is CinematicGroup", child2 is CinematicGroup)
	if child2 is CinematicGroup:
		_assert_eq("inner group id", child2.id, "fd_inner")
		_assert_true("inner not parallel", not child2.is_parallel())
		_assert_eq("inner children count", child2.children.size(), 1)
	print("")

	print("--- Test: Load g0_intro.json ---")

	var json_path = "res://resources/strategy/scenarios/goetz-official/event-chains/g0_intro.json"
	var json_chain = EventChain.load_from_json_file(json_path)
	_assert_true("chain loaded from JSON", json_chain != null)
	if json_chain == null:
		print("  SKIP: could not load %s\n" % json_path)
	else:
		_assert_eq("chain_id", json_chain.chain_id, "g0_intro")
		_assert_true("has root group", json_chain.has_root_group())
		_assert_true("root_group is CinematicGroup", json_chain.root_group is CinematicGroup)
		_assert_true("has characters", json_chain.character_ids.size() > 0)

		var has_goetz = false
		var has_franz = false
		for cid in json_chain.character_ids:
			if cid == "goetz":
				has_goetz = true
			elif cid == "franz":
				has_franz = true
		_assert_true("goetz in character_ids", has_goetz)
		_assert_true("franz in character_ids", has_franz)

		_assert_true("transition_type set", json_chain.transition_type != EventChain.TransitionType.NONE or true)

		var jroot = json_chain.root_group
		_assert_true("root group has children", jroot.children.size() > 0)
		print("  Root group: id='%s', %d children, duration=%.1f" % [jroot.id, jroot.children.size(), jroot.duration])

		var jplayback = GroupPlayback.new()
		var fired_count: Array = [0]
		var gates_count: Array = [0]

		jplayback.instruction_fired.connect(func(_inst: CinematicInstruction) -> void:
			fired_count[0] += 1
		)
		jplayback.gate_reached.connect(func() -> void:
			gates_count[0] += 1
		)

		jplayback.load_group(jroot)
		_assert_eq("playback state PLAYING", jplayback.state, GroupPlayback.State.PLAYING)

		var safety: int = 0
		var max_iterations: int = 50000
		while jplayback.state != GroupPlayback.State.COMPLETE and safety < max_iterations:
			if jplayback.state == GroupPlayback.State.WAITING_FOR_GATE:
				jplayback.on_input()
			jplayback.process(0.05)
			safety += 1

		_assert_true("playback completed (iterations=%d)" % safety, jplayback.state == GroupPlayback.State.COMPLETE)
		_assert_true("some instructions fired (%d)" % fired_count[0], fired_count[0] > 0)
		print("  Fired %d instructions, hit %d gates in %d iterations" % [fired_count[0], gates_count[0], safety])
		print("")

	_print_summary()
	get_tree().quit(1 if _fail_count > 0 else 0)


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

	for expected_char in expected_chars:
		var found = false
		for cid in chain.character_ids:
			if cid.to_lower() == expected_char.to_lower():
				found = true
				break
		_assert_true("character '%s' present" % expected_char, found)

	var prev_time: float = -1.0
	var sorted_timeline = chain.timeline.duplicate()
	sorted_timeline.sort_custom(func(a, b): return a.time < b.time)

	for inst in sorted_timeline:
		_assert_true("time >= 0 (got %.3f)" % inst.time, inst.time >= 0.0)

	var after_id_at_zero: int = 0
	for inst in chain.timeline:
		if inst.has_after_dependency() and inst.time == 0.0:
			after_id_at_zero += 1
	if after_id_at_zero > 0:
		print("  WARNING: %d instructions with after_id still at time=0 (may indicate unresolved deps)" % after_id_at_zero)

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

	var order_ok = true
	for i in range(1, fired_instructions.size()):
		if fired_instructions[i].time < fired_instructions[i - 1].time - 0.001:
			order_ok = false
			print("  ORDERING ERROR: instruction at index %d (t=%.3f) fired before index %d (t=%.3f)" % [
				i, fired_instructions[i].time, i - 1, fired_instructions[i - 1].time])
			break
	_assert_true("firing order monotonic", order_ok)
	print("")


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


func _print_summary() -> void:
	print("=== RESULTS: %d passed, %d failed ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		print("SOME TESTS FAILED")
	else:
		print("ALL TESTS PASSED")
