extends Node2D

## Phase B spike: rigs the left sclera as a per-vertex-boned Polygon2D mesh so it can WIDEN/BLINK non-affinely (vertical scale around the eye centroid) — something a sprite transform can't do. Right eye stays a sprite for comparison; run with --gui to view, headless just prints verification.

const FACE := "Skeleton2D/Root/Hips/Torso/Head/Face/"
const WHITE_PATH := FACE + "Eyes/EyeL/White"
const SCLERA_PATH := WHITE_PATH + "/Sclera"
const BONE_BASE := WHITE_PATH + "/ScleraSkeleton/"

const WIDEN_Y := 1.35  # eye-white vertical stretch at "wide"
const BLINK_Y := 0.06  # eye-white vertical collapse at "blink"

## Sampled from eye_l_white_sclera_neutral.svg (texture space, 200x200 viewBox): path0 = rim outline, path1 = blue accent.
const PATH0_N := [Vector2(106.181, 143.557), Vector2(106.051, 137.495), Vector2(106.515, 131.527), Vector2(107.906, 125.837), Vector2(110.558, 120.606), Vector2(114.804, 116.020), Vector2(120.978, 112.259), Vector2(122.498, 112.038), Vector2(126.488, 111.562), Vector2(132.095, 111.116), Vector2(138.465, 110.984), Vector2(144.744, 111.450), Vector2(150.078, 112.798), Vector2(152.642, 114.806), Vector2(155.076, 116.970), Vector2(157.278, 119.349), Vector2(159.149, 121.998), Vector2(160.588, 124.976), Vector2(161.494, 128.338), Vector2(161.333, 131.664), Vector2(161.323, 134.433), Vector2(161.417, 136.826), Vector2(161.565, 139.019), Vector2(161.719, 141.190), Vector2(161.830, 143.519), Vector2(159.934, 152.106), Vector2(156.449, 158.981), Vector2(152.178, 164.258), Vector2(147.926, 168.051), Vector2(144.498, 170.474), Vector2(142.699, 171.641), Vector2(137.455, 170.280), Vector2(129.876, 166.422), Vector2(121.461, 160.943), Vector2(113.708, 154.721), Vector2(108.116, 148.633)]
const PATH1_N := [Vector2(80.547, 113.865), Vector2(82.456, 113.240), Vector2(84.390, 112.829), Vector2(86.571, 112.748), Vector2(88.705, 113.046), Vector2(90.494, 113.775), Vector2(90.965, 114.089), Vector2(91.398, 114.416), Vector2(91.781, 114.754), Vector2(92.100, 115.099), Vector2(92.986, 116.420), Vector2(93.542, 117.601), Vector2(93.829, 118.451), Vector2(93.911, 118.777), Vector2(89.870, 118.425), Vector2(86.547, 117.372), Vector2(83.564, 115.793)]

@onready var rig: WarriorRig = $Rig

var _white_bones: Array[Bone2D] = []
var _accent_bones: Array[Bone2D] = []
var _centroid := Vector2.ZERO  # eye pivot for the vertical widen/blink morphs


func _ready() -> void:
	rig.play_behavior(AnimTypes.Behavior.IDLE)

	var sclera: Sprite2D = rig.get_node(SCLERA_PATH)
	var white: Sprite2D = rig.get_node(WHITE_PATH)
	var tex := sclera.texture
	var off := sclera.offset
	var zidx := sclera.z_index
	sclera.visible = false

	var half := tex.get_size() * 0.5
	var origin := off - half  # texture pixel (0,0) in White-local space

	var white_pts := _local_points(PATH0_N, origin)
	var accent_pts := _local_points(PATH1_N, origin)
	_centroid = _avg(white_pts)

	var skel := Skeleton2D.new()
	skel.name = "ScleraSkeleton"
	white.add_child(skel)
	for k in white_pts.size():
		var b := _make_bone("W%d" % k, white_pts[k])
		skel.add_child(b)
		_white_bones.append(b)
	for k in accent_pts.size():
		var b := _make_bone("B%d" % k, accent_pts[k])
		skel.add_child(b)
		_accent_bones.append(b)

	var poly_iris := _make_poly("IrisPoly", PATH0_N, origin, tex, zidx)
	var poly_accent := _make_poly("AccentPoly", PATH1_N, origin, tex, zidx)
	skel.add_child(poly_iris)
	skel.add_child(poly_accent)
	poly_iris.skeleton = NodePath("..")
	poly_accent.skeleton = NodePath("..")

	await get_tree().process_frame  # let the skeleton settle bone rests before skinning

	# Weight each vertex fully to its own bone (paths resolve relative to the skeleton).
	for k in _white_bones.size():
		var w := PackedFloat32Array()
		w.resize(white_pts.size())
		w.fill(0.0)
		w[k] = 1.0
		poly_iris.add_bone(NodePath("W%d" % k), w)
	for k in _accent_bones.size():
		var w := PackedFloat32Array()
		w.resize(accent_pts.size())
		w.fill(0.0)
		w[k] = 1.0
		poly_accent.add_bone(NodePath("B%d" % k), w)

	# add_bone() doesn't request a redraw, but skeleton attachment happens in NOTIFICATION_DRAW.
	poly_iris.queue_redraw()
	poly_accent.queue_redraw()

	_build_anim()

	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(1.0).timeout
		var top: Vector2 = white_pts[10]  # a top-rim vertex
		print("[SPIKE] eye-white rim bones=%d accent bones=%d centroid=%s" % [
			_white_bones.size(), _accent_bones.size(), str(_centroid)])
		print("[SPIKE] WIDEN moves top-rim vert %s -> %s" % [str(top), str(_morph(top, WIDEN_Y))])
		print("[SPIKE] BLINK moves top-rim vert %s -> %s" % [str(top), str(_morph(top, BLINK_Y))])
		get_tree().quit(0)


func _local_points(ring: Array, origin: Vector2) -> Array:
	var out: Array[Vector2] = []
	for p in ring:
		out.append(origin + p)
	return out


func _make_bone(bname: String, pos: Vector2) -> Bone2D:
	var b := Bone2D.new()
	b.name = bname
	b.position = pos
	# Bind pose == current transform so deformation is identity at rest (default rest is a zero transform).
	b.rest = Transform2D(0.0, pos)
	b.set_autocalculate_length_and_angle(false)
	return b


func _make_poly(pname: String, ring: Array, origin: Vector2, tex: Texture2D, zidx: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = pname
	poly.texture = tex
	poly.antialiased = true
	poly.z_index = zidx
	poly.z_as_relative = false
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in ring:
		pts.append(origin + p)
		uvs.append(p)
	poly.polygon = pts
	poly.uv = uvs
	return poly


func _avg(pts: Array) -> Vector2:
	var s := Vector2.ZERO
	for p in pts:
		s += p
	return s / float(pts.size())


func _morph(neutral: Vector2, y_scale: float) -> Vector2:
	# Vertical scale around the eye centroid: y_scale>1 opens, <1 closes.
	return _centroid + (neutral - _centroid) * Vector2(1.0, y_scale)


func _build_anim() -> void:
	var player := AnimationPlayer.new()
	player.name = "ScleraAnim"
	add_child(player)
	player.root_node = player.get_path_to(rig)

	var anim := Animation.new()
	anim.length = 4.0
	anim.loop_mode = Animation.LOOP_LINEAR
	# Timeline: 0 neutral, 1 wide, 2 neutral, 3 blink, 4 neutral.
	for k in _white_bones.size():
		_add_morph_track(anim, "W%d" % k, _white_bones[k].position)
	for k in _accent_bones.size():
		_add_morph_track(anim, "B%d" % k, _accent_bones[k].position)

	var lib := AnimationLibrary.new()
	lib.add_animation("morph", anim)
	player.add_animation_library("", lib)
	player.play("morph")


func _add_morph_track(anim: Animation, bname: String, neutral: Vector2) -> void:
	var ti := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ti, NodePath(BONE_BASE + bname + ":position"))
	anim.track_insert_key(ti, 0.0, neutral)
	anim.track_insert_key(ti, 1.0, _morph(neutral, WIDEN_Y))
	anim.track_insert_key(ti, 2.0, neutral)
	anim.track_insert_key(ti, 3.0, _morph(neutral, BLINK_Y))
	anim.track_insert_key(ti, 4.0, neutral)
