extends Node2D

## Headless check that the GENERATED eyes_expression_test.tscn loads with intact
## skinning and that its morph animation actually moves the bones. Rasterization is
## NOT required (this environment's headless GL falls back to the dummy renderer), so
## instead of pixels we freeze the MorphPlayer at neutral / wide / blink and read a
## rim bone's position: wide must lift the top rim, blink must drop it toward centre.
## Run: godot --headless --path . tools/verify_eyes_expression.tscn

const SCENE := "res://scenes/demos/eyes_expression_test.tscn"


func _ready() -> void:
	var packed: PackedScene = load(SCENE)
	if packed == null:
		print("[EYESVERIFY] FAILED: could not load %s" % SCENE)
		get_tree().quit(1)
		return
	var inst: Node = packed.instantiate()
	add_child(inst)

	var eyewhite: Polygon2D = inst.get_node_or_null("Eyes/Sclera/EyeWhite")
	if eyewhite == null:
		print("[EYESVERIFY] FAILED: EyeWhite mesh missing")
		get_tree().quit(1)
		return
	var skel := eyewhite.get_node(eyewhite.skeleton) as Skeleton2D
	print("[EYESVERIFY] EyeWhite bones=%d verts=%d skeleton=%s skel_bones=%d" % [
		eyewhite.get_bone_count(), eyewhite.polygon.size(),
		skel.name if skel else "NULL", skel.get_bone_count() if skel else -1])
	if skel == null or eyewhite.get_bone_count() == 0:
		print("[EYESVERIFY] FAILED: skinning did not survive save/load")
		get_tree().quit(1)
		return

	var player: AnimationPlayer = inst.get_node("MorphPlayer")
	var anim := player.get_animation("morph")
	print("[EYESVERIFY] morph tracks=%d length=%.1f" % [
		anim.get_track_count() if anim else -1, anim.length if anim else -1.0])

	# W10 is the topmost eye-white rim bone.
	var top: Bone2D = inst.get_node("Eyes/Sclera/W10")
	player.speed_scale = 0.0
	player.play("morph")

	player.seek(0.0, true)
	await _pump()
	var p_neutral := top.position

	player.seek(1.0, true)
	await _pump()
	var p_wide := top.position

	player.seek(3.0, true)
	await _pump()
	var p_blink := top.position

	print("[EYESVERIFY] W10 neutral=%s wide=%s blink=%s" % [
		str(p_neutral), str(p_wide), str(p_blink)])

	var wide_ok := p_wide.y < p_neutral.y - 1.0      # top rim lifted (more -y)
	var blink_ok := p_blink.y > p_neutral.y + 1.0    # top rim dropped toward centre
	print("[EYESVERIFY] %s" % ("DEFORMATION WORKS: wide lifts top rim, blink closes it"
		if wide_ok and blink_ok else "UNEXPECTED bone motion"))
	get_tree().quit(0 if wide_ok and blink_ok else 1)


func _pump() -> void:
	for i in 2:
		await get_tree().process_frame
