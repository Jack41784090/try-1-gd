extends Node
## Headless test for march walking behavior and VN gesturing logic.
## Verifies that:
## 1. Walking animation is properly applied and trackable in march mode
## 2. Gesturing behavior only targets the speaker, not all warriors
## 3. State machine is ready before behaviors are applied
##
## Run: godot --headless --path . -s src/demos/stage_logic_test.gd

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

var _frame_count: int = 0
var _test_phase: int = 0
var _warriors: Array[CharacterSocialStats] = []
var _rigs: Dictionary = { }
var _container: Node2D
var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("\n========================================")
	print("STAGE LOGIC TEST — HEADLESS")
	print("========================================\n")
	_create_test_warriors()
	_container = Node2D.new()
	add_child(_container)
	_run_phase_0_create_rigs()


func _process(_delta: float) -> void:
	_frame_count += 1
	match _test_phase:
		1:
			if _frame_count >= 3:
				_run_phase_1_verify_ready()
		2:
			if _frame_count >= 6:
				_run_phase_2_march_behavior()
		3:
			if _frame_count >= 15:
				_run_phase_3_verify_march()
		4:
			if _frame_count >= 18:
				_run_phase_4_vn_gesturing()
		5:
			if _frame_count >= 27:
				_run_phase_5_verify_gesturing()
		6:
			if _frame_count >= 30:
				_run_phase_6_dismiss_and_remarch()
		7:
			if _frame_count >= 39:
				_run_phase_7_verify_remarch()
		99:
			pass


func _create_test_warriors() -> void:
	var names = ["goetz", "franz", "hilda", "konrad"]
	for n in names:
		var w = CharacterSocialStats.new()
		w.id = n
		w.name = n.capitalize()
		w.class_id = EntityClasses.Types.Landsknecht
		_warriors.append(w)
	print("[TEST] Created %d test warriors: %s" % [_warriors.size(), names])


func _run_phase_0_create_rigs() -> void:
	print("\n--- PHASE 0: Create rigs and add to tree ---")
	for warrior in _warriors:
		var rig = WarriorRigFactory.create_rig_for_warrior(warrior)
		_container.add_child(rig)
		_rigs[warrior.id] = rig
		print("[TEST] Created rig for '%s' — in tree: %s" % [warrior.id, rig.is_inside_tree()])
	_test_phase = 1
	print("[TEST] Waiting 3 frames for _ready()...\n")


func _run_phase_1_verify_ready() -> void:
	print("\n--- PHASE 1: Verify rigs are ready (frame %d) ---" % _frame_count)
	for id in _rigs:
		var rig: WarriorRig = _rigs[id]
		var ctrl: WarriorAnimController = rig.anim_controller
		var has_tree = ctrl._anim_tree != null
		var has_sm = ctrl._state_machine != null
		var tree_active = ctrl._anim_tree.active if ctrl._anim_tree else false
		var sm_playing = ctrl._state_machine.is_playing() if ctrl._state_machine else false
		var sm_node = str(ctrl._state_machine.get_current_node()) if ctrl._state_machine else "N/A"
		var behavior = AnimTypes.Behavior.keys()[ctrl.current_behavior]
		_assert("Rig '%s' anim_tree not null" % id, has_tree)
		_assert("Rig '%s' state_machine not null" % id, has_sm)
		print("[TEST]   '%s' — tree_active: %s, sm_playing: %s, sm_node: '%s', behavior: %s" % [id, tree_active, sm_playing, sm_node, behavior])
	_test_phase = 2


func _run_phase_2_march_behavior() -> void:
	print("\n--- PHASE 2: Apply WALKING to all rigs via travel() then check start() ---")
	for id in _rigs:
		var rig: WarriorRig = _rigs[id]
		var ctrl = rig.anim_controller
		var sm_before = str(ctrl._state_machine.get_current_node()) if ctrl._state_machine else "N/A"
		print("[TEST]   Before — '%s' behavior: %s, SM: '%s'" % [id, AnimTypes.Behavior.keys()[ctrl.current_behavior], sm_before])

		# First try travel() (current approach)
		ctrl.current_behavior = AnimTypes.Behavior.IDLE # Reset so play_behavior doesn't early-return
		rig.play_behavior(AnimTypes.Behavior.WALKING)
		var sm_after_travel = str(ctrl._state_machine.get_current_node()) if ctrl._state_machine else "N/A"
		var travel_path = ctrl._state_machine.get_travel_path() if ctrl._state_machine else []
		print("[TEST]   After travel() — '%s' behavior: %s, SM: '%s', travel_path: %s" % [id, AnimTypes.Behavior.keys()[ctrl.current_behavior], sm_after_travel, travel_path])

		# Now try start() as alternative
		if ctrl._state_machine:
			ctrl._state_machine.start(&"walking")
			var sm_after_start = str(ctrl._state_machine.get_current_node())
			print("[TEST]   After start() — '%s' SM: '%s'" % [id, sm_after_start])
	_test_phase = 3


func _run_phase_3_verify_march() -> void:
	print("\n--- PHASE 3: Verify all rigs are WALKING (frame %d) ---" % _frame_count)
	for id in _rigs:
		var rig: WarriorRig = _rigs[id]
		var ctrl = rig.anim_controller
		var is_walking = ctrl.current_behavior == AnimTypes.Behavior.WALKING
		_assert("Rig '%s' is WALKING" % id, is_walking)

		var sm_current = ""
		if ctrl._state_machine:
			sm_current = str(ctrl._state_machine.get_current_node())
		print(
			"[TEST]   '%s' — current_behavior: %s, SM node: '%s'" % [
				id,
				AnimTypes.Behavior.keys()[ctrl.current_behavior],
				sm_current,
			],
		)
		_assert("Rig '%s' SM node is 'walking'" % id, sm_current == "walking")
	_test_phase = 4


func _run_phase_4_vn_gesturing() -> void:
	print("\n--- PHASE 4: Simulate VN dialogue with gesturing (speaker=goetz) ---")

	print("[TEST] Step 1: dismiss_all_speech equivalent — set all to IDLE")
	for id in _rigs:
		_rigs[id].play_behavior(AnimTypes.Behavior.IDLE)

	print("[TEST] Step 2: show_speech equivalent — set speaker to TALKING")
	var speaker_id = "goetz"
	_rigs[speaker_id].play_behavior(AnimTypes.Behavior.TALKING)

	print("[TEST] Step 3: Apply behavior override 'gesturing' to speaker ONLY")
	var anim = BEHAVIOR_MAP.get("gesturing")
	_rigs[speaker_id].play_behavior(anim)

	print("[TEST] After VN dialogue application:")
	for id in _rigs:
		var behavior = AnimTypes.Behavior.keys()[_rigs[id].anim_controller.current_behavior]
		print("[TEST]   '%s' — behavior: %s" % [id, behavior])
	_test_phase = 5


func _run_phase_5_verify_gesturing() -> void:
	print("\n--- PHASE 5: Verify ONLY goetz is GESTURING (frame %d) ---" % _frame_count)
	for id in _rigs:
		var rig: WarriorRig = _rigs[id]
		var ctrl = rig.anim_controller
		var behavior = ctrl.current_behavior
		var sm_current = ""
		if ctrl._state_machine:
			sm_current = str(ctrl._state_machine.get_current_node())

		if id == "goetz":
			_assert("Speaker 'goetz' is GESTURING", behavior == AnimTypes.Behavior.GESTURING)
			_assert("Speaker 'goetz' SM node is 'gesturing'", sm_current == "gesturing")
		else:
			_assert("Non-speaker '%s' is IDLE" % id, behavior == AnimTypes.Behavior.IDLE)
			_assert("Non-speaker '%s' SM node is 'idle'" % id, sm_current == "idle")
		print("[TEST]   '%s' — behavior: %s, SM: '%s'" % [id, AnimTypes.Behavior.keys()[behavior], sm_current])
	_test_phase = 6


func _run_phase_6_dismiss_and_remarch() -> void:
	print("\n--- PHASE 6: Dismiss speech → return to march ---")
	print("[TEST] Step 1: dismiss_all_speech — set all to IDLE")
	for id in _rigs:
		_rigs[id].play_behavior(AnimTypes.Behavior.IDLE)

	print("[TEST] Step 2: start_march — set all to WALKING")
	for id in _rigs:
		_rigs[id].play_behavior(AnimTypes.Behavior.WALKING)

	for id in _rigs:
		var behavior = AnimTypes.Behavior.keys()[_rigs[id].anim_controller.current_behavior]
		print("[TEST]   '%s' — behavior after re-march: %s" % [id, behavior])
	_test_phase = 7


func _run_phase_7_verify_remarch() -> void:
	print("\n--- PHASE 7: Verify all rigs walking after VN→march transition (frame %d) ---" % _frame_count)
	for id in _rigs:
		var rig: WarriorRig = _rigs[id]
		var ctrl = rig.anim_controller
		var is_walking = ctrl.current_behavior == AnimTypes.Behavior.WALKING
		var sm_current = ""
		if ctrl._state_machine:
			sm_current = str(ctrl._state_machine.get_current_node())
		_assert("Rig '%s' is WALKING after re-march" % id, is_walking)
		_assert("Rig '%s' SM node is 'walking' after re-march" % id, sm_current == "walking")
		print("[TEST]   '%s' — behavior: %s, SM: '%s'" % [id, AnimTypes.Behavior.keys()[ctrl.current_behavior], sm_current])

	_finish()


func _assert(msg: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("[PASS] %s" % msg)
	else:
		_fail_count += 1
		print("[FAIL] %s" % msg)


func _finish() -> void:
	_test_phase = 99
	print("\n========================================")
	print("TEST COMPLETE: %d passed, %d failed" % [_pass_count, _fail_count])
	print("========================================\n")
	if _fail_count > 0:
		print("RESULT: FAILURES DETECTED")
	else:
		print("RESULT: ALL TESTS PASSED")
	get_tree().quit(1 if _fail_count > 0 else 0)
