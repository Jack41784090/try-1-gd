@tool
extends EditorScript

## One-shot editor tool: builds the neutral left sclera as a REAL, editable
## Skeleton2D + Bone2D + skinned Polygon2D node tree and saves it to a scene,
## so bone-driven mesh deformation can be verified visually.
##
## Run from the Script editor: open this file, then File > Run (calls _run()).
## It writes res://scenes/demos/sclera_skin_editor_test.tscn. The polygons use
## SOLID bright colors (cyan iris, magenta accent) so deformation is obvious.
## Open that scene and press F6: the cyan iris slides 60px right and back.
## (Deformation proven working headless: a skinned quad shifted exactly 50px.)

const OUT_SCENE := "res://scenes/demos/sclera_skin_editor_test.tscn"
const SCLERA_TEX := "res://assets/rig_textures/rachelle/face/eye_l_white_sclera_neutral.svg"

## sclera.offset in the rig (sclera local position is (0,0)).
const OFF := Vector2(-6.910002, 8.310997)

## Sampled from eye_l_white_sclera_{neutral,wide}.svg (texture space, 200x200).
const PATH0_N := [Vector2(106.181, 143.557), Vector2(106.051, 137.495), Vector2(106.515, 131.527), Vector2(107.906, 125.837), Vector2(110.558, 120.606), Vector2(114.804, 116.020), Vector2(120.978, 112.259), Vector2(122.498, 112.038), Vector2(126.488, 111.562), Vector2(132.095, 111.116), Vector2(138.465, 110.984), Vector2(144.744, 111.450), Vector2(150.078, 112.798), Vector2(152.642, 114.806), Vector2(155.076, 116.970), Vector2(157.278, 119.349), Vector2(159.149, 121.998), Vector2(160.588, 124.976), Vector2(161.494, 128.338), Vector2(161.333, 131.664), Vector2(161.323, 134.433), Vector2(161.417, 136.826), Vector2(161.565, 139.019), Vector2(161.719, 141.190), Vector2(161.830, 143.519), Vector2(159.934, 152.106), Vector2(156.449, 158.981), Vector2(152.178, 164.258), Vector2(147.926, 168.051), Vector2(144.498, 170.474), Vector2(142.699, 171.641), Vector2(137.455, 170.280), Vector2(129.876, 166.422), Vector2(121.461, 160.943), Vector2(113.708, 154.721), Vector2(108.116, 148.633)]
const PATH1_N := [Vector2(80.547, 113.865), Vector2(82.456, 113.240), Vector2(84.390, 112.829), Vector2(86.571, 112.748), Vector2(88.705, 113.046), Vector2(90.494, 113.775), Vector2(90.965, 114.089), Vector2(91.398, 114.416), Vector2(91.781, 114.754), Vector2(92.100, 115.099), Vector2(92.986, 116.420), Vector2(93.542, 117.601), Vector2(93.829, 118.451), Vector2(93.911, 118.777), Vector2(89.870, 118.425), Vector2(86.547, 117.372), Vector2(83.564, 115.793)]
const PATH1_W := [Vector2(80.547, 113.865), Vector2(82.456, 113.240), Vector2(84.417, 112.665), Vector2(86.677, 112.181), Vector2(88.937, 111.969), Vector2(90.897, 112.211), Vector2(91.359, 112.378), Vector2(91.779, 112.586), Vector2(92.147, 112.840), Vector2(92.450, 113.142), Vector2(93.282, 114.768), Vector2(93.717, 116.623), Vector2(93.884, 118.145), Vector2(93.911, 118.777), Vector2(89.870, 118.425), Vector2(86.547, 117.372), Vector2(83.564, 115.793)]
const EXAGGERATION := 12.0  # cranked high so the tiny accent morph is obvious in the test


func _run() -> void:
	var tex: Texture2D = load(SCLERA_TEX)
	if tex == null:
		push_error("could not load sclera texture: " + SCLERA_TEX)
		return

	var root := Node2D.new()
	root.name = "ScleraSkinTest"

	# Faint reference of the original art so deformation is visible against it.
	var ref := Sprite2D.new()
	ref.name = "ReferenceSprite"
	ref.texture = tex
	ref.offset = OFF
	ref.modulate = Color(1, 1, 1, 0.35)
	root.add_child(ref)
	ref.owner = root

	var skel := Skeleton2D.new()
	skel.name = "Skeleton2D"
	root.add_child(skel)
	skel.owner = root

	# BIris: a bone the user can drag to confirm deformation works at all.
	var iris_bone := _make_bone("BIris", Vector2.ZERO)
	skel.add_child(iris_bone)
	iris_bone.owner = root

	# One bone per accent vertex, at the vertex's rest position.
	var accent_bones: Array[Bone2D] = []
	for i in PATH1_N.size():
		var local: Vector2 = PATH1_N[i] + OFF - Vector2(100, 100)
		var b := _make_bone("B%d" % i, local)
		skel.add_child(b)
		b.owner = root
		accent_bones.append(b)

	# Iris polygon (fixed outline), fully weighted to BIris so dragging it moves.
	var iris_poly := _make_poly("IrisPoly", PATH0_N, Color(0.0, 0.9, 0.9, 0.85))
	iris_poly.add_bone(NodePath(iris_bone.name), _ones(PATH0_N.size()))
	skel.add_child(iris_poly)
	iris_poly.owner = root

	# Accent polygon, each vertex fully weighted to its own bone.
	var accent_poly := _make_poly("AccentPoly", PATH1_N, Color(1.0, 0.1, 0.8, 0.95))
	for i in accent_bones.size():
		var w := PackedFloat32Array()
		w.resize(PATH1_N.size())
		w.fill(0.0)
		w[i] = 1.0
		accent_poly.add_bone(NodePath(accent_bones[i].name), w)
	skel.add_child(accent_poly)
	accent_poly.owner = root

	# Autoplaying morph so deformation can be confirmed by pressing Play (F6):
	# at runtime the renderer always computes skinning (no editor-viewport ambiguity).
	var player := AnimationPlayer.new()
	player.name = "MorphPlayer"
	root.add_child(player)
	player.owner = root
	player.root_node = player.get_path_to(root)

	var anim := Animation.new()
	anim.length = 2.4
	anim.loop_mode = Animation.LOOP_LINEAR
	# Obvious diagnostic: slide the whole iris 60px right and back.
	var ti := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ti, NodePath("Skeleton2D/BIris:position"))
	anim.track_insert_key(ti, 0.0, Vector2.ZERO)
	anim.track_insert_key(ti, 1.2, Vector2(60, 0))
	anim.track_insert_key(ti, 2.4, Vector2.ZERO)
	# Accent morph: each bone from its rest position to rest + neutral->wide displacement.
	for i in accent_bones.size():
		var rest_pos: Vector2 = PATH1_N[i] + OFF - Vector2(100, 100)
		var disp: Vector2 = (PATH1_W[i] - PATH1_N[i]) * EXAGGERATION
		var tk := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(tk, NodePath("Skeleton2D/B%d:position" % i))
		anim.track_insert_key(tk, 0.0, rest_pos)
		anim.track_insert_key(tk, 1.2, rest_pos + disp)
		anim.track_insert_key(tk, 2.4, rest_pos)

	var lib := AnimationLibrary.new()
	lib.add_animation("morph", anim)
	player.add_animation_library("", lib)
	player.autoplay = "morph"

	var ps := PackedScene.new()
	if ps.pack(root) != OK:
		push_error("failed to pack scene")
		root.free()
		return
	var err := ResourceSaver.save(ps, OUT_SCENE)
	root.free()
	if err != OK:
		push_error("failed to save scene: %d" % err)
		return
	print("Saved editable skinning test to: ", OUT_SCENE)
	print("Open it and press F6 (Play). The iris should slide 60px right and back (autoplay morph).")
	print("If it moves at runtime, skinning works. You can also drag bones in the editor to test live.")


func _make_bone(bname: String, pos: Vector2) -> Bone2D:
	var b := Bone2D.new()
	b.name = bname
	b.position = pos
	# Bind pose must equal the current transform so deformation is identity at rest
	# (final_xform = accum_transform * rest_inverse). Default rest is a zero transform.
	b.rest = Transform2D(0.0, pos)
	b.set_autocalculate_length_and_angle(false)
	return b


func _make_poly(pname: String, tex_pts: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = pname
	# Solid bright color (no texture) so the fill -- and any deformation -- is obvious.
	poly.color = color
	# skeleton defaults to an EMPTY NodePath -- must point it at the parent Skeleton2D.
	poly.skeleton = NodePath("..")
	var verts := PackedVector2Array()
	for p in tex_pts:
		verts.append(Vector2(p.x - 100.0, p.y - 100.0) + OFF)
	poly.polygon = verts
	return poly


func _ones(n: int) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(n)
	w.fill(1.0)
	return w
