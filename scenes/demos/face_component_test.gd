extends Node

## Regression test for the composable Face / FaceComponent expression system.
##
## Covers the three things the design rests on: that an intent cascades to every
## part that answers it (and only those), that reactions are measured from the
## baked baseline so repeated switching never drifts, and that a config without
## face components hides the face outright instead of leaving the previous
## character's one showing.
##
##   godot --headless --path . scenes/demos/face_component_test.tscn

const RIG_SCENE := preload("res://scenes/rig/warrior_rig_2.tscn")
const RACHELLE_CONFIG := "res://resources/animation/configs/wcr_adventurer_rachelle.tres"
const LANDSKNECHT_CONFIG := "res://resources/animation/configs/landsknecht.tres"

var test_count := 0
var passed_count := 0
var failed_count := 0

var rig: WarriorRig
var face: Face


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("FACE COMPONENT — COMPOSABLE EXPRESSION TEST SUITE")
	print("=".repeat(70) + "\n")

	rig = RIG_SCENE.instantiate() as WarriorRig
	add_child(rig)
	rig.apply_config(load(RACHELLE_CONFIG) as WarriorRigConfig)
	face = rig.face

	test_tree_composed()
	await test_intent_cascades()
	await test_neutral_returns_to_baseline()
	await test_unanswered_intent_is_a_noop()
	test_texture_swap_intents()
	test_faceless_config_hides_face()

	print("\n" + "=".repeat(70))
	print("TEST RESULTS: %d passed, %d failed, %d total" % [passed_count, failed_count, test_count])
	if failed_count == 0:
		print("✓ ALL TESTS PASSED!")
	else:
		print("✗ SOME TESTS FAILED!")
	print("=".repeat(70) + "\n")

	get_tree().quit(0 if failed_count == 0 else 1)


## Waits out the longest authored blend, so assertions read finished transforms
## rather than whatever frame a tween happens to be on.
func settle() -> void:
	await get_tree().create_timer(0.3).timeout


func check(condition: bool, test_name: String, detail: String = "") -> void:
	test_count += 1
	if condition:
		passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_count += 1
		print("  [FAIL] %s%s" % [test_name, "  (%s)" % detail if detail else ""])


func test_tree_composed() -> void:
	print("\n--- Test 1: The rig carries a composed Face tree ---")
	check(face != null, "WarriorRig resolves its Face node")
	if not face:
		return
	check(face.character == "rachelle", "Face knows whose art it carries", face.character)
	for path in ["Eyes", "Eyes/EyeL", "Eyes/EyeL/White", "Eyes/EyeL/White/Pupil",
			"Eyes/EyeL/White/Sclera", "Eyes/EyeL/Lashes", "Eyes/EyeR/White/Pupil",
			"Brows/BrowL", "Brows/BrowR", "Mouth", "HairBack"]:
		check(face.get_node_or_null(NodePath(path)) is FaceComponent,
			"Face/%s is a FaceComponent" % path)
	## Nesting is what makes a reaction on a parent carry its children along.
	var pupil := face.get_node_or_null(NodePath("Eyes/EyeL/White/Pupil")) as FaceComponent
	check(pupil and pupil.get_parent().name == "White",
		"Pupil nests inside White, matching the source artwork")


func test_intent_cascades() -> void:
	print("\n--- Test 2: One intent, several parts answering independently ---")
	var pupil := face.get_node_or_null(NodePath("Eyes/EyeL/White/Pupil")) as FaceComponent
	var white := face.get_node_or_null(NodePath("Eyes/EyeL/White")) as FaceComponent
	var brow := face.get_node_or_null(NodePath("Brows/BrowL")) as FaceComponent
	var mouth := face.get_node_or_null(NodePath("Mouth")) as FaceComponent
	var pupil_base := pupil.scale
	var white_base := white.scale
	var brow_base := brow.position
	var brow_rot := brow.rotation
	var mouth_base := mouth.position

	rig.set_expression_by_name("scared")
	await settle()

	check(pupil.scale.is_equal_approx(pupil_base * Vector2(0.6, 0.6)),
		"Pupil shrinks", str(pupil.scale))
	check(white.scale.is_equal_approx(white_base * Vector2(1.12, 1.28)),
		"Eye white widens", str(white.scale))
	check(brow.position.is_equal_approx(brow_base + Vector2(0, -7)),
		"Brow lifts", str(brow.position))
	check(not is_equal_approx(brow.rotation, brow_rot), "Brow tilts", str(brow.rotation))
	## The mouth authors nothing for "scared", so it must not move — a part with
	## nothing to say about an intent is silent, not defaulted.
	check(mouth.position.is_equal_approx(mouth_base),
		"Mouth, which authors no 'scared' reaction, stays put", str(mouth.position))


func test_neutral_returns_to_baseline() -> void:
	print("\n--- Test 3: Repeated switching never drifts from the baked pose ---")
	var pupil := face.get_node_or_null(NodePath("Eyes/EyeL/White/Pupil")) as FaceComponent
	var brow := face.get_node_or_null(NodePath("Brows/BrowL")) as FaceComponent
	rig.set_expression_by_name("neutral")
	await settle()
	var pupil_neutral := pupil.scale
	var brow_neutral := brow.position

	## Switch without settling, so each tween is killed part-way — the case that
	## would accumulate if reactions were applied to the current pose rather than
	## to the baseline.
	for i in 5:
		rig.set_expression_by_name("scared")
		await get_tree().process_frame
		rig.set_expression_by_name("angry")
		await get_tree().process_frame
		rig.set_expression_by_name("neutral")
		await get_tree().process_frame
	rig.set_expression_by_name("neutral")
	await settle()

	check(pupil.scale.is_equal_approx(pupil_neutral),
		"Pupil scale returns exactly after 5 round trips", str(pupil.scale))
	check(brow.position.is_equal_approx(brow_neutral),
		"Brow position returns exactly after 5 round trips", str(brow.position))
	check(is_equal_approx(brow.rotation, 0.0),
		"Brow rotation returns to the baked 0", str(brow.rotation))


func test_unanswered_intent_is_a_noop() -> void:
	print("\n--- Test 4: An intent no part answers changes nothing ---")
	var before := {}
	for node in _components():
		before[node] = [node.position, node.rotation, node.scale, node.texture]

	rig.set_expression_by_name("bewildered")
	await settle()

	var unchanged := true
	for node in _components():
		var was: Array = before[node]
		if node.position != was[0] or node.rotation != was[1] \
				or node.scale != was[2] or node.texture != was[3]:
			unchanged = false
			print("      moved: %s" % node.name)
	check(unchanged, "No component reacts to an unknown intent")


func test_texture_swap_intents() -> void:
	print("\n--- Test 5: Emotions from the artwork arrive as texture swaps ---")
	var lashes := face.get_node_or_null(NodePath("Eyes/EyeL/Lashes")) as FaceComponent
	var sclera := face.get_node_or_null(NodePath("Eyes/EyeL/White/Sclera")) as FaceComponent
	rig.set_expression_by_name("neutral")
	var lashes_neutral := lashes.texture
	var sclera_neutral := sclera.texture

	rig.set_expression_by_name("blink")
	check(lashes.texture != lashes_neutral, "Lashes swap art for 'blink'")
	## A blink authors no eye white, so the part is exported empty rather than
	## left showing the open eye's art underneath the closed lashes.
	check(sclera.texture != sclera_neutral, "Eye fill swaps to the blink variant")

	rig.set_expression_by_name("neutral")
	check(lashes.texture == lashes_neutral, "Lashes return to the baked art")
	check(sclera.texture == sclera_neutral, "Eye fill returns to the baked art")


func test_faceless_config_hides_face() -> void:
	print("\n--- Test 6: A character with no face art doesn't wear someone else's ---")
	var faceless := load(LANDSKNECHT_CONFIG) as WarriorRigConfig
	check(faceless != null, "Landsknecht rig config loads")
	check(not faceless.has_face_components,
		"Landsknecht declares no face components")
	rig.apply_config(faceless)
	check(not face.visible, "Face is hidden for a config without face components")
	## Broadcasting at a hidden face is harmless — nothing special-cases it.
	rig.set_expression_by_name("scared")
	check(true, "express() on a hidden face raises nothing")

	rig.apply_config(load(RACHELLE_CONFIG) as WarriorRigConfig)
	check(face.visible, "Face comes back for the character it belongs to")


func _components() -> Array[FaceComponent]:
	var out: Array[FaceComponent] = []
	for node in face.find_children("*", "FaceComponent", true, false):
		out.append(node)
	return out
