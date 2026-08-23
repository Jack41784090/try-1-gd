extends Node2D

## Phase 0 spike (docs/refactors/animation-tree-unification.md) answering: does Blend2 crossfade same-keyed clips smoothly (Q1), do disjoint-keyed clips compose (Q2), must RESET carry face tracks (Q3)? Run headless for the report, or --gui with LEFT/RIGHT to scrub the Q1 crossfade.

const FACE := "Skeleton2D/Root/Hips/Torso/Head/Face/"
const BL := FACE + "Brows/BrowL"
const BR := FACE + "Brows/BrowR"
const MO := FACE + "Mouth"

const BL_POS := Vector2(-26.486097, 0.9382992)
const BR_POS := Vector2(26.4861, -0.9382992)
const MO_POS := Vector2(30.280006, 41.462006)

@onready var rig: WarriorRig = $Rig

var spike_player: AnimationPlayer
var spike_tree: AnimationTree
var lib: AnimationLibrary
var brow_l: Sprite2D
var brow_r: Sprite2D
var mouth: Sprite2D
var _interactive := false


func _ready() -> void:
	brow_l = rig.get_node(BL)
	brow_r = rig.get_node(BR)
	mouth = rig.get_node(MO)
	rig.anim_tree.active = false
	rig.anim_player.stop()
	_build_player()
	if DisplayServer.get_name() == "headless":
		await _run_report()
		get_tree().quit(0)
	else:
		_interactive = true
		spike_tree.tree_root = _graph_q1()
		spike_tree.active = true
		print("[SPIKE] interactive: LEFT/RIGHT scrub Q1 crossfade, 1/2/3 switch tests")


func _build_player() -> void:
	spike_player = AnimationPlayer.new()
	spike_player.name = "SpikePlayer"
	rig.add_child(spike_player)
	spike_player.root_node = spike_player.get_path_to(rig)

	lib = AnimationLibrary.new()
	_author_clips()
	spike_player.add_animation_library("", lib)

	spike_tree = AnimationTree.new()
	spike_tree.name = "SpikeTree"
	rig.add_child(spike_tree)
	spike_tree.anim_player = spike_tree.get_path_to(spike_player)
	spike_tree.root_node = spike_tree.get_path_to(rig)


func _author_clips() -> void:
	lib.add_animation("face_neutral", _pose({
		BL + ":position": BL_POS, BL + ":rotation": 0.0, BL + ":scale": Vector2.ONE,
		BR + ":position": BR_POS, BR + ":rotation": 0.0, BR + ":scale": Vector2.ONE,
		MO + ":position": MO_POS, MO + ":rotation": 0.0, MO + ":scale": Vector2.ONE,
	}))
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
	## Additive (delta-from-baseline) variants for the Q2 composition test.
	lib.add_animation("brows_sad_add", _pose({
		BL + ":position": Vector2(0, 2), BL + ":rotation": 0.35, BL + ":scale": Vector2.ZERO,
		BR + ":position": Vector2(0, 2), BR + ":rotation": -0.35, BR + ":scale": Vector2.ZERO,
	}))
	lib.add_animation("mouth_smile_add", _pose({
		MO + ":position": Vector2(0, -2), MO + ":rotation": 0.0, MO + ":scale": Vector2(0.3, -0.3),
	}))
	## Keys a body bone only — no face tracks. Used for the Q3 RESET test.
	lib.add_animation("body_only", _pose({
		"Skeleton2D/Root/Hips/Torso:rotation": 0.2,
	}))
	lib.add_animation("RESET", _face_reset())


func _face_reset() -> Animation:
	return _pose({
		BL + ":position": BL_POS, BL + ":rotation": 0.0, BL + ":scale": Vector2.ONE,
		BR + ":position": BR_POS, BR + ":rotation": 0.0, BR + ":scale": Vector2.ONE,
		MO + ":position": MO_POS, MO + ":rotation": 0.0, MO + ":scale": Vector2.ONE,
	})


func _pose(tracks: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = 0.001
	anim.loop_mode = Animation.LOOP_NONE
	for path in tracks:
		var ti := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(ti, NodePath(path))
		anim.track_insert_key(ti, 0.0, tracks[path])
	return anim


func _graph_q1() -> AnimationNodeBlendTree:
	var t := AnimationNodeBlendTree.new()
	var a := AnimationNodeAnimation.new()
	a.animation = "brows_neutral"
	var b := AnimationNodeAnimation.new()
	b.animation = "brows_sad"
	var blend := AnimationNodeBlend2.new()
	t.add_node("a", a)
	t.add_node("b", b)
	t.add_node("blend", blend)
	t.connect_node("blend", 0, "a")
	t.connect_node("blend", 1, "b")
	t.connect_node("output", 0, "blend")
	return t


func _graph_q2_absolute() -> AnimationNodeBlendTree:
	var t := AnimationNodeBlendTree.new()
	var base := AnimationNodeAnimation.new()
	base.animation = "brows_sad"
	var layer := AnimationNodeAnimation.new()
	layer.animation = "mouth_smile"
	var add := AnimationNodeAdd2.new()
	t.add_node("base", base)
	t.add_node("layer", layer)
	t.add_node("add", add)
	t.connect_node("add", 0, "base")
	t.connect_node("add", 1, "layer")
	t.connect_node("output", 0, "add")
	return t


func _graph_q2_additive() -> AnimationNodeBlendTree:
	var t := AnimationNodeBlendTree.new()
	var base := AnimationNodeAnimation.new()
	base.animation = "face_neutral"
	var brows := AnimationNodeAnimation.new()
	brows.animation = "brows_sad_add"
	var mouth_node := AnimationNodeAnimation.new()
	mouth_node.animation = "mouth_smile_add"
	var add1 := AnimationNodeAdd2.new()
	var add2 := AnimationNodeAdd2.new()
	t.add_node("base", base)
	t.add_node("brows", brows)
	t.add_node("mouth", mouth_node)
	t.add_node("add1", add1)
	t.add_node("add2", add2)
	t.connect_node("add1", 0, "base")
	t.connect_node("add1", 1, "brows")
	t.connect_node("add2", 0, "add1")
	t.connect_node("add2", 1, "mouth")
	t.connect_node("output", 0, "add2")
	return t


func _graph_q2c_production() -> AnimationNodeBlendTree:
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
	var face_merge := AnimationNodeAdd2.new()
	var body := AnimationNodeAnimation.new()
	body.animation = "body_only"
	var body_face := AnimationNodeAdd2.new()
	t.add_node("bn", bn)
	t.add_node("bs", bs)
	t.add_node("brows_blend", brows_blend)
	t.add_node("mn", mn)
	t.add_node("ms", ms)
	t.add_node("mouth_blend", mouth_blend)
	t.add_node("face_merge", face_merge)
	t.add_node("body", body)
	t.add_node("body_face", body_face)
	t.connect_node("brows_blend", 0, "bn")
	t.connect_node("brows_blend", 1, "bs")
	t.connect_node("mouth_blend", 0, "mn")
	t.connect_node("mouth_blend", 1, "ms")
	t.connect_node("face_merge", 0, "brows_blend")
	t.connect_node("face_merge", 1, "mouth_blend")
	t.connect_node("body_face", 0, "body")
	t.connect_node("body_face", 1, "face_merge")
	t.connect_node("output", 0, "body_face")
	return t


func _graph_q3_bodyonly() -> AnimationNodeBlendTree:
	var t := AnimationNodeBlendTree.new()
	var a := AnimationNodeAnimation.new()
	a.animation = "body_only"
	t.add_node("a", a)
	t.connect_node("output", 0, "a")
	return t


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _use(graph: AnimationNodeBlendTree) -> void:
	spike_tree.active = false
	spike_tree.tree_root = graph
	spike_tree.active = true
	await _settle()


func _run_report() -> void:
	print("[SPIKE] ============ Q1: Blend2 crossfade (same nodes) ============")
	await _use(_graph_q1())
	for amt in [0.0, 0.25, 0.5, 0.75, 1.0]:
		spike_tree.set("parameters/blend/blend_amount", amt)
		await _settle()
		print("[SPIKE]   blend=%0.2f  BrowL.rot=%+0.4f (expect %+0.4f)  BrowL.pos.y=%0.3f" % [
			amt, brow_l.rotation, 0.35 * amt, brow_l.position.y])

	print("[SPIKE] ============ Q2a: Add2 with ABSOLUTE clips (disjoint) ============")
	await _use(_graph_q2_absolute())
	spike_tree.set("parameters/add/add_amount", 1.0)
	await _settle()
	print("[SPIKE]   BrowL.rot=%+0.4f (expect +0.3500)" % brow_l.rotation)
	print("[SPIKE]   Mouth.scale=%s (expect (1.3, 0.7))" % str(mouth.scale))
	print("[SPIKE]   Mouth.pos=%s (expect ~%s)" % [str(mouth.position), str(MO_POS + Vector2(0, -2))])

	print("[SPIKE] ============ Q2b: Add2 chain with ADDITIVE clips (disjoint) ============")
	await _use(_graph_q2_additive())
	spike_tree.set("parameters/add1/add_amount", 1.0)
	spike_tree.set("parameters/add2/add_amount", 1.0)
	await _settle()
	print("[SPIKE]   BrowL.rot=%+0.4f (expect +0.3500)" % brow_l.rotation)
	print("[SPIKE]   BrowL.pos=%s (expect ~%s)" % [str(brow_l.position), str(BL_POS + Vector2(0, 2))])
	print("[SPIKE]   Mouth.scale=%s (expect (1.3, 0.7))" % str(mouth.scale))
	print("[SPIKE]   Mouth.pos=%s (expect ~%s)" % [str(mouth.position), str(MO_POS + Vector2(0, -2))])

	print("[SPIKE] ============ Q2c: PRODUCTION SHAPE (per-part Blend2 -> Add2 merge -> body) ============")
	await _use(_graph_q2c_production())
	spike_tree.set("parameters/face_merge/add_amount", 1.0)
	spike_tree.set("parameters/body_face/add_amount", 1.0)
	spike_tree.set("parameters/brows_blend/blend_amount", 1.0)
	spike_tree.set("parameters/mouth_blend/blend_amount", 1.0)
	await _settle()
	print("[SPIKE]   full sad+smile:")
	print("[SPIKE]     BrowL.rot=%+0.4f (expect +0.3500)  pos=%s (expect ~%s)" % [
		brow_l.rotation, str(brow_l.position), str(BL_POS + Vector2(0, 2))])
	print("[SPIKE]     Mouth.scale=%s (expect (1.3, 0.7))  pos=%s (expect ~%s)" % [
		str(mouth.scale), str(mouth.position), str(MO_POS + Vector2(0, -2))])
	spike_tree.set("parameters/brows_blend/blend_amount", 0.5)
	spike_tree.set("parameters/mouth_blend/blend_amount", 0.0)
	await _settle()
	print("[SPIKE]   brow half-fade, mouth neutral:")
	print("[SPIKE]     BrowL.rot=%+0.4f (expect +0.1750)  pos.y=%0.3f (expect 1.938)" % [
		brow_l.rotation, brow_l.position.y])
	print("[SPIKE]     Mouth.scale=%s (expect (1, 1))  pos=%s (expect %s)" % [
		str(mouth.scale), str(mouth.position), str(MO_POS)])

	print("[SPIKE] ============ Q3: RESET dependency (body_only graph) ============")
	await _use(_graph_q3_bodyonly())
	print("[SPIKE]   face tracks IN RESET:")
	print("[SPIKE]     BrowL.rot=%+0.4f scale=%s pos=%s" % [brow_l.rotation, str(brow_l.scale), str(brow_l.position)])
	print("[SPIKE]     Mouth.scale=%s pos=%s" % [str(mouth.scale), str(mouth.position)])
	lib.remove_animation("RESET")
	lib.add_animation("RESET", _pose({}))
	await _use(_graph_q3_bodyonly())
	print("[SPIKE]   EMPTY RESET:")
	print("[SPIKE]     BrowL.rot=%+0.4f scale=%s pos=%s" % [brow_l.rotation, str(brow_l.scale), str(brow_l.position)])
	print("[SPIKE]     Mouth.scale=%s pos=%s" % [str(mouth.scale), str(mouth.position)])
	print("[SPIKE] ============ report done ============")


func _input(event: InputEvent) -> void:
	if not _interactive or not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_LEFT:
			var v: float = spike_tree.get("parameters/blend/blend_amount")
			spike_tree.set("parameters/blend/blend_amount", clampf(v - 0.1, 0.0, 1.0))
		KEY_RIGHT:
			var v: float = spike_tree.get("parameters/blend/blend_amount")
			spike_tree.set("parameters/blend/blend_amount", clampf(v + 0.1, 0.0, 1.0))
		KEY_1:
			await _use(_graph_q1())
		KEY_2:
			await _use(_graph_q2_additive())
			spike_tree.set("parameters/add1/add_amount", 1.0)
			spike_tree.set("parameters/add2/add_amount", 1.0)
		KEY_3:
			await _use(_graph_q2_absolute())
			spike_tree.set("parameters/add/add_amount", 1.0)
