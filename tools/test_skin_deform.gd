extends Node2D

## Headless self-test for Polygon2D skeletal deformation.
## Step 1 (control): a plain red quad with NO skeleton -- confirms headless rasterizes.
## Step 2 (skinned): the same quad fully weighted to one bone; move the bone 50px and
## compare pixel centroids. If the centroid shifts, code-created skinning deforms.

func _ready() -> void:
	var svp := SubViewport.new()
	svp.size = Vector2i(200, 200)
	svp.transparent_bg = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)

	# --- Control: plain quad, no skeleton ---
	var plain := Polygon2D.new()
	plain.polygon = PackedVector2Array([Vector2(90, 90), Vector2(110, 90), Vector2(110, 110), Vector2(90, 110)])
	plain.color = Color.RED
	svp.add_child(plain)
	await _pump()
	var c_ctrl := _centroid(svp.get_texture().get_image())
	print("[SKINTEST] CONTROL plain quad centroid=%s" % str(c_ctrl))
	plain.queue_free()
	if c_ctrl.x < 0:
		print("[SKINTEST] HEADLESS DOES NOT RASTERIZE -- pixel test invalid here")
		get_tree().quit(0)
		return
	await _pump()

	# --- Skinned quad ---
	var skel := Skeleton2D.new()
	skel.position = Vector2(100, 100)
	svp.add_child(skel)

	var bone := Bone2D.new()
	bone.name = "B"
	bone.rest = Transform2D.IDENTITY
	bone.set_autocalculate_length_and_angle(false)
	skel.add_child(bone)

	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)])
	poly.color = Color.RED
	poly.skeleton = NodePath("..")
	poly.add_bone(NodePath("B"), PackedFloat32Array([1, 1, 1, 1]))
	skel.add_child(poly)

	await _pump()
	var c_a := _centroid(svp.get_texture().get_image())

	bone.position = Vector2(50, 0)
	await _pump()
	var c_b := _centroid(svp.get_texture().get_image())

	print("[SKINTEST] poly.bone_count=%d skel.bone_count=%d bone_idx=%d" % [
		poly.get_bone_count(), skel.get_bone_count(), bone.get_index_in_skeleton()])
	print("[SKINTEST] skinned centroid A=%s  B=%s" % [str(c_a), str(c_b)])
	var shift := c_a.distance_to(c_b)
	if c_a.x < 0 or c_b.x < 0:
		print("[SKINTEST] FAILED: skinned quad not rendered")
	elif shift > 20.0:
		print("[SKINTEST] DEFORMATION WORKS: shifted %.1fpx" % shift)
	else:
		print("[SKINTEST] NO DEFORMATION: shifted only %.1fpx" % shift)

	# --- Step 3: multi-bone, one vertex per bone (the accent's exact setup) ---
	skel.queue_free()
	await _pump()

	var skel2 := Skeleton2D.new()
	skel2.position = Vector2(100, 100)
	svp.add_child(skel2)

	var verts := [Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)]
	var mbones: Array[Bone2D] = []
	for i in 4:
		var mb := Bone2D.new()
		mb.name = "M%d" % i
		mb.position = verts[i]
		mb.rest = Transform2D(0.0, verts[i])
		mb.set_autocalculate_length_and_angle(false)
		skel2.add_child(mb)
		mbones.append(mb)

	var mpoly := Polygon2D.new()
	mpoly.polygon = PackedVector2Array(verts)
	mpoly.color = Color.RED
	mpoly.skeleton = NodePath("..")
	for i in 4:
		var w := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
		w[i] = 1.0
		mpoly.add_bone(NodePath("M%d" % i), w)
	skel2.add_child(mpoly)

	await _pump()
	var m_a := _centroid(svp.get_texture().get_image())
	mbones[1].position = verts[1] + Vector2(50, 0)  # move vertex 1 right 50px
	await _pump()
	var m_b := _centroid(svp.get_texture().get_image())
	var mshift := m_a.distance_to(m_b)
	print("[SKINTEST] MULTI-BONE centroid A=%s  B=%s (expect ~12.5px shift)" % [str(m_a), str(m_b)])
	if mshift > 8.0:
		print("[SKINTEST] MULTI-BONE DEFORMATION WORKS: shifted %.1fpx" % mshift)
	else:
		print("[SKINTEST] MULTI-BONE NO DEFORMATION: shifted only %.1fpx" % mshift)
	get_tree().quit(0)


func _pump() -> void:
	for i in 4:
		await get_tree().process_frame


func _centroid(img: Image) -> Vector2:
	if img == null:
		return Vector2(-1, -1)
	img.convert(Image.FORMAT_RGBA8)
	var sum := Vector2.ZERO
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				sum += Vector2(x, y)
				n += 1
	if n == 0:
		return Vector2(-1, -1)
	return sum / float(n)
