@tool
extends SceneTree

## Bakes the face-emotion switcher demo: authors the per-part expression clips and the
## AnimationTree blend graph (validated in docs/refactors/animation-tree-unification.md
## §5) and saves them as real resources in the scene, so the runtime script only drives
## parameters. Re-run whenever the clips or graph change:
##   godot --headless --path . --script res://tools/bake_face_emotions.gd

const SCENE_PATH := "res://scenes/demos/face_emotion_switcher.tscn"
const RIG_PATH := "res://scenes/rig/warrior_rig_2.tscn"
const SCRIPT_PATH := "res://src/demos/face_emotion_switcher.gd"

const FACE := "Skeleton2D/Root/Hips/Torso/Head/Face/"
const BL := FACE + "Brows/BrowL"
const BR := FACE + "Brows/BrowR"
const MO := FACE + "Mouth"
## Eye layers, per eye: White (openness), Pupil + Sclera (gaze/dilation), Lashes (lid).
const EWL := FACE + "Eyes/EyeL/White"
const EWR := FACE + "Eyes/EyeR/White"
const PLL := FACE + "Eyes/EyeL/White/Pupil"
const PLR := FACE + "Eyes/EyeR/White/Pupil"
const SLL := FACE + "Eyes/EyeL/White/Sclera"
const SLR := FACE + "Eyes/EyeR/White/Sclera"
const LSL := FACE + "Eyes/EyeL/Lashes"
const LSR := FACE + "Eyes/EyeR/Lashes"

## Rest-pose values read from warrior_rig_2.tscn (clips are absolute, so every animated
## track must carry its rest value in the neutral clip and in RESET).
const BL_POS := Vector2(-26.486097, 0.9382992)
const BR_POS := Vector2(26.4861, -0.9382992)
const MO_POS := Vector2(30.280006, 41.462006)
const LSL_POS := Vector2(-3.0794024, -8.836001)
const LSR_POS := Vector2(1.5663986, -9.377599)
const PLL_POS := Vector2(4.965794, 0.0)
const PLR_POS := Vector2(1.3386002, 0.0)
const SLL_POS := Vector2.ZERO
const SLR_POS := Vector2.ZERO


func _initialize() -> void:
	var ok := _bake()
	if ok:
		print("[bake_face_emotions] Saved %s" % SCENE_PATH)
	else:
		push_error("[bake_face_emotions] FAILED")
	quit(0 if ok else 1)


func _bake() -> bool:
	var rig_packed := load(RIG_PATH) as PackedScene
	if not rig_packed:
		push_error("Could not load rig: " + RIG_PATH)
		return false
	var script := load(SCRIPT_PATH) as Script
	if not script:
		push_error("Could not load script: " + SCRIPT_PATH)
		return false

	var root := Node2D.new()
	root.name = "FaceEmotionSwitcher"
	root.set_script(script)

	var rig := rig_packed.instantiate()
	rig.name = "Rig"
	root.add_child(rig)
	rig.owner = root

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(0, -60)
	camera.zoom = Vector2(4, 4)
	root.add_child(camera)
	camera.owner = root

	var ui := CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)
	ui.owner = root
	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(14, 12)
	label.size = Vector2(606, 208)
	label.text = "Face Emotion Switcher"
	ui.add_child(label)
	label.owner = root

	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	player.root_node = NodePath("../Rig")
	var lib := AnimationLibrary.new()
	_author_clips(lib)
	player.add_animation_library("", lib)

	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	root.add_child(tree)
	tree.owner = root
	tree.anim_player = NodePath("../AnimationPlayer")
	tree.root_node = NodePath("../Rig")
	tree.tree_root = _graph()
	tree.active = true

	var out := PackedScene.new()
	var err := out.pack(root)
	if err != OK:
		push_error("PackedScene.pack failed: %d" % err)
		return false
	err = ResourceSaver.save(out, SCENE_PATH)
	if err != OK:
		push_error("ResourceSaver.save failed: %d" % err)
		return false
	return true


func _author_clips(lib: AnimationLibrary) -> void:
	lib.add_animation("brows_neutral", _pose({
		BL + ":position": BL_POS, BL + ":rotation": 0.0, BL + ":scale": Vector2.ONE,
		BR + ":position": BR_POS, BR + ":rotation": 0.0, BR + ":scale": Vector2.ONE,
	}))
	lib.add_animation("brows_sad", _pose({
		BL + ":position": BL_POS + Vector2(0, 2), BL + ":rotation": 0.35, BL + ":scale": Vector2.ONE,
		BR + ":position": BR_POS + Vector2(0, 2), BR + ":rotation": -0.35, BR + ":scale": Vector2.ONE,
	}))
	lib.add_animation("mouth_neutral", _pose({
		MO + ":position": MO_POS, MO + ":rotation": 0.0, MO + ":scale": Vector2.ONE,
	}))
	lib.add_animation("mouth_smile", _pose({
		MO + ":position": MO_POS + Vector2(0, -2), MO + ":rotation": 0.0, MO + ":scale": Vector2(1.3, 0.7),
	}))

	## lid: openness via White.scale, plus Lashes sweeping down to cover / up to widen.
	lib.add_animation("lid_neutral", _pose({
		EWL + ":scale": Vector2.ONE, EWR + ":scale": Vector2.ONE,
		LSL + ":position": LSL_POS, LSL + ":rotation": 0.0,
		LSR + ":position": LSR_POS, LSR + ":rotation": 0.0,
	}))
	lib.add_animation("lid_closed", _pose({
		EWL + ":scale": Vector2(1.0, 0.08), EWR + ":scale": Vector2(1.0, 0.08),
		LSL + ":position": LSL_POS + Vector2(0, 7), LSL + ":rotation": 0.18,
		LSR + ":position": LSR_POS + Vector2(0, 7), LSR + ":rotation": -0.18,
	}))
	lib.add_animation("lid_wide", _pose({
		EWL + ":scale": Vector2(1.2, 1.3), EWR + ":scale": Vector2(1.2, 1.3),
		LSL + ":position": LSL_POS + Vector2(0, -3), LSL + ":rotation": -0.12,
		LSR + ":position": LSR_POS + Vector2(0, -3), LSR + ":rotation": 0.12,
	}))

	## gaze: Pupil + Sclera translate together; Sclera (iris) trails the Pupil a touch.
	lib.add_animation("gaze_neutral", _pose({
		PLL + ":position": PLL_POS, PLR + ":position": PLR_POS,
		SLL + ":position": SLL_POS, SLR + ":position": SLR_POS,
	}))
	lib.add_animation("gaze_left", _pose({
		PLL + ":position": PLL_POS + Vector2(-3.5, 0), PLR + ":position": PLR_POS + Vector2(-3.5, 0),
		SLL + ":position": SLL_POS + Vector2(-2.5, 0), SLR + ":position": SLR_POS + Vector2(-2.5, 0),
	}))
	lib.add_animation("gaze_right", _pose({
		PLL + ":position": PLL_POS + Vector2(3.5, 0), PLR + ":position": PLR_POS + Vector2(3.5, 0),
		SLL + ":position": SLL_POS + Vector2(2.5, 0), SLR + ":position": SLR_POS + Vector2(2.5, 0),
	}))
	lib.add_animation("gaze_up", _pose({
		PLL + ":position": PLL_POS + Vector2(0, -3.0), PLR + ":position": PLR_POS + Vector2(0, -3.0),
		SLL + ":position": SLL_POS + Vector2(0, -2.0), SLR + ":position": SLR_POS + Vector2(0, -2.0),
	}))
	lib.add_animation("gaze_down", _pose({
		PLL + ":position": PLL_POS + Vector2(0, 3.0), PLR + ":position": PLR_POS + Vector2(0, 3.0),
		SLL + ":position": SLL_POS + Vector2(0, 2.0), SLR + ":position": SLR_POS + Vector2(0, 2.0),
	}))

	## dilation: Pupil + Sclera scale (constrict = anger/focus, dilate = fear/surprise).
	lib.add_animation("dilate_neutral", _pose({
		PLL + ":scale": Vector2.ONE, PLR + ":scale": Vector2.ONE,
		SLL + ":scale": Vector2.ONE, SLR + ":scale": Vector2.ONE,
	}))
	lib.add_animation("dilate_constrict", _pose({
		PLL + ":scale": Vector2(0.7, 0.7), PLR + ":scale": Vector2(0.7, 0.7),
		SLL + ":scale": Vector2(0.92, 0.92), SLR + ":scale": Vector2(0.92, 0.92),
	}))
	lib.add_animation("dilate_wide", _pose({
		PLL + ":scale": Vector2(1.35, 1.35), PLR + ":scale": Vector2(1.35, 1.35),
		SLL + ":scale": Vector2(1.15, 1.15), SLR + ":scale": Vector2(1.15, 1.15),
	}))

	## RESET must carry EVERY animated track at rest, or unkeyed parts collapse (see §5).
	lib.add_animation("RESET", _pose({
		BL + ":position": BL_POS, BL + ":rotation": 0.0, BL + ":scale": Vector2.ONE,
		BR + ":position": BR_POS, BR + ":rotation": 0.0, BR + ":scale": Vector2.ONE,
		MO + ":position": MO_POS, MO + ":rotation": 0.0, MO + ":scale": Vector2.ONE,
		EWL + ":scale": Vector2.ONE, EWR + ":scale": Vector2.ONE,
		LSL + ":position": LSL_POS, LSL + ":rotation": 0.0,
		LSR + ":position": LSR_POS, LSR + ":rotation": 0.0,
		PLL + ":position": PLL_POS, PLR + ":position": PLR_POS,
		SLL + ":position": SLL_POS, SLR + ":position": SLR_POS,
		PLL + ":scale": Vector2.ONE, PLR + ":scale": Vector2.ONE,
		SLL + ":scale": Vector2.ONE, SLR + ":scale": Vector2.ONE,
	}))


func _pose(tracks: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = 0.001
	anim.loop_mode = Animation.LOOP_NONE
	for path in tracks:
		var ti := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(ti, NodePath(path))
		anim.track_insert_key(ti, 0.0, tracks[path])
	return anim


func _graph() -> AnimationNodeBlendTree:
	var t := AnimationNodeBlendTree.new()

	var bn := AnimationNodeAnimation.new()
	bn.animation = "brows_neutral"
	var bs := AnimationNodeAnimation.new()
	bs.animation = "brows_sad"
	var brows_blend := AnimationNodeBlend2.new()

	var mn := AnimationNodeAnimation.new()
	mn.animation = "mouth_neutral"
	var ms := AnimationNodeAnimation.new()
	ms.animation = "mouth_smile"
	var mouth_blend := AnimationNodeBlend2.new()

	## lid: BlendSpace1D closed(-1) / neutral(0) / wide(+1).
	var lid_space := AnimationNodeBlendSpace1D.new()
	var lid_closed := AnimationNodeAnimation.new()
	lid_closed.animation = "lid_closed"
	var lid_neutral := AnimationNodeAnimation.new()
	lid_neutral.animation = "lid_neutral"
	var lid_wide := AnimationNodeAnimation.new()
	lid_wide.animation = "lid_wide"
	lid_space.add_blend_point(lid_closed, -1.0)
	lid_space.add_blend_point(lid_neutral, 0.0)
	lid_space.add_blend_point(lid_wide, 1.0)

	## gaze: BlendSpace2D, blend_position is a Vector2 look direction.
	var gaze_space := AnimationNodeBlendSpace2D.new()
	var g_neutral := AnimationNodeAnimation.new()
	g_neutral.animation = "gaze_neutral"
	var g_left := AnimationNodeAnimation.new()
	g_left.animation = "gaze_left"
	var g_right := AnimationNodeAnimation.new()
	g_right.animation = "gaze_right"
	var g_up := AnimationNodeAnimation.new()
	g_up.animation = "gaze_up"
	var g_down := AnimationNodeAnimation.new()
	g_down.animation = "gaze_down"
	gaze_space.add_blend_point(g_neutral, Vector2(0, 0))
	gaze_space.add_blend_point(g_left, Vector2(-1, 0))
	gaze_space.add_blend_point(g_right, Vector2(1, 0))
	gaze_space.add_blend_point(g_up, Vector2(0, 1))
	gaze_space.add_blend_point(g_down, Vector2(0, -1))

	## dilation: BlendSpace1D constrict(-1) / neutral(0) / wide(+1).
	var dilation_space := AnimationNodeBlendSpace1D.new()
	var d_constrict := AnimationNodeAnimation.new()
	d_constrict.animation = "dilate_constrict"
	var d_neutral := AnimationNodeAnimation.new()
	d_neutral.animation = "dilate_neutral"
	var d_wide := AnimationNodeAnimation.new()
	d_wide.animation = "dilate_wide"
	dilation_space.add_blend_point(d_constrict, -1.0)
	dilation_space.add_blend_point(d_neutral, 0.0)
	dilation_space.add_blend_point(d_wide, 1.0)

	## Add2 chain merges disjoint-track layers: brows+mouth, then lid, gaze, dilation.
	var m_bm := AnimationNodeAdd2.new()
	var m_lid := AnimationNodeAdd2.new()
	var m_gaze := AnimationNodeAdd2.new()
	var m_out := AnimationNodeAdd2.new()

	t.add_node("bn", bn)
	t.add_node("bs", bs)
	t.add_node("brows_blend", brows_blend)
	t.add_node("mn", mn)
	t.add_node("ms", ms)
	t.add_node("mouth_blend", mouth_blend)
	t.add_node("lid_space", lid_space)
	t.add_node("gaze_space", gaze_space)
	t.add_node("dilation_space", dilation_space)
	t.add_node("m_bm", m_bm)
	t.add_node("m_lid", m_lid)
	t.add_node("m_gaze", m_gaze)
	t.add_node("m_out", m_out)

	t.connect_node("brows_blend", 0, "bn")
	t.connect_node("brows_blend", 1, "bs")
	t.connect_node("mouth_blend", 0, "mn")
	t.connect_node("mouth_blend", 1, "ms")
	t.connect_node("m_bm", 0, "brows_blend")
	t.connect_node("m_bm", 1, "mouth_blend")
	t.connect_node("m_lid", 0, "m_bm")
	t.connect_node("m_lid", 1, "lid_space")
	t.connect_node("m_gaze", 0, "m_lid")
	t.connect_node("m_gaze", 1, "gaze_space")
	t.connect_node("m_out", 0, "m_gaze")
	t.connect_node("m_out", 1, "dilation_space")
	t.connect_node("output", 0, "m_out")
	return t
