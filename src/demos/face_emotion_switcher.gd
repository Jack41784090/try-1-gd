extends Node2D

## Face-emotion demo driving clips/blend graph baked by tools/bake_face_emotions.gd (see docs/refactors/animation-tree-unification.md §5): brows/mouth are Blend2 crossfades, eyes are lid/gaze/dilation merged by an Add2 chain. Run: F6 or --gui to view; headless self-tests every emotion.

const FADE := 0.25

## brows/mouth are 0..1 blend amounts; lid/dilation are -1..+1 blend-space positions; gaze is a look-direction Vector2.
const EMOTIONS := {
	&"neutral": {"brows": 0.0, "mouth": 0.0, "lid": 0.0, "gaze": Vector2.ZERO, "dilation": 0.0},
	&"happy": {"brows": 0.0, "mouth": 1.0, "lid": 0.3, "gaze": Vector2.ZERO, "dilation": 0.4},
	&"sad": {"brows": 1.0, "mouth": 0.0, "lid": -0.4, "gaze": Vector2(0, -0.5), "dilation": -0.2},
	&"surprised": {"brows": 0.0, "mouth": 0.0, "lid": 1.0, "gaze": Vector2(0, 0.5), "dilation": 1.0},
	&"sleepy": {"brows": 0.0, "mouth": 0.0, "lid": -1.0, "gaze": Vector2(0, -0.6), "dilation": -0.4},
	&"bittersweet": {"brows": 1.0, "mouth": 1.0, "lid": -0.1, "gaze": Vector2(0, -0.2), "dilation": 0.3},
	&"angry": {"brows": 1.0, "mouth": 0.0, "lid": -0.35, "gaze": Vector2(0, -0.1), "dilation": -1.0},
	&"shifty": {"brows": 0.0, "mouth": 0.0, "lid": -0.2, "gaze": Vector2(-1, 0), "dilation": -0.5},
}
const ORDER: Array[StringName] = [
	&"neutral", &"happy", &"sad", &"surprised", &"sleepy", &"bittersweet", &"angry", &"shifty"]

@onready var rig: WarriorRig = $Rig
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var label: Label = $UI/Label
@onready var brow_l: Sprite2D = $Rig/Skeleton2D/Root/Hips/Torso/Head/Face/Brows/BrowL
@onready var mouth: Sprite2D = $Rig/Skeleton2D/Root/Hips/Torso/Head/Face/Mouth
@onready var eye_l_white: Sprite2D = $Rig/Skeleton2D/Root/Hips/Torso/Head/Face/Eyes/EyeL/White
@onready var pupil_l: Sprite2D = $Rig/Skeleton2D/Root/Hips/Torso/Head/Face/Eyes/EyeL/White/Pupil
@onready var lash_l: Sprite2D = $Rig/Skeleton2D/Root/Hips/Torso/Head/Face/Eyes/EyeL/Lashes

var _index := 0


func _ready() -> void:
	rig.play_behavior(AnimTypes.Behavior.IDLE)
	## Add2 layers default to 0; enable every merge in the chain so all parts drive.
	for node in ["m_bm", "m_lid", "m_gaze", "m_out"]:
		anim_tree.set("parameters/%s/add_amount" % node, 1.0)
	if DisplayServer.get_name() == "headless":
		await _self_test()
		get_tree().quit(0)
	else:
		_apply_emotion(ORDER[0])


func _apply_emotion(name: StringName) -> void:
	var e: Dictionary = EMOTIONS[name]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(anim_tree, "parameters/brows_blend/blend_amount", e.brows, FADE)
	tw.tween_property(anim_tree, "parameters/mouth_blend/blend_amount", e.mouth, FADE)
	tw.tween_property(anim_tree, "parameters/lid_space/blend_position", e.lid, FADE)
	tw.tween_property(anim_tree, "parameters/gaze_space/blend_position", e.gaze, FADE)
	tw.tween_property(anim_tree, "parameters/dilation_space/blend_position", e.dilation, FADE)
	_update_label(name)


func _lid_word(v: float) -> String:
	if v > 0.5:
		return "wide"
	if v < -0.75:
		return "closed"
	if v < -0.25:
		return "half-lidded"
	return "neutral"


func _update_label(name: StringName) -> void:
	var e: Dictionary = EMOTIONS[name]
	var brows_word: String = "furrowed" if e.brows > 0.5 else "neutral"
	var mouth_word: String = "smile" if e.mouth > 0.5 else "neutral"
	var gaze_word: String = ("(%+.1f,%+.1f)" % [e.gaze.x, e.gaze.y]) if e.gaze.length() > 0.05 else "center"
	label.text = "Emotion: %s\n  brows: %s   mouth: %s   lid: %s\n  gaze: %s   dilation: %+.1f\n\n[1-8] pick    [<-/-> or SPACE] cycle" % [
		String(name), brows_word, mouth_word, _lid_word(e.lid), gaze_word, e.dilation]


func _self_test() -> void:
	for name in ORDER:
		_apply_emotion(name)
		await get_tree().create_timer(FADE + 0.05).timeout
		print("[SWITCH] %-12s BrowL.rot=%+0.3f Mouth.s=%s White.s=%s Pupil.pos=%s Pupil.s=%s Lash.pos=%s" % [
			String(name) + ":", brow_l.rotation, _v2(mouth.scale), _v2(eye_l_white.scale),
			_v2(pupil_l.position), _v2(pupil_l.scale), _v2(lash_l.position)])


func _v2(v: Vector2) -> String:
	return "(%+.2f,%+.2f)" % [v.x, v.y]


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_8:
		var i: int = int(event.keycode) - int(KEY_1)
		if i < ORDER.size():
			_index = i
			_apply_emotion(ORDER[_index])
		return
	match event.keycode:
		KEY_RIGHT, KEY_SPACE, KEY_TAB:
			_index = (_index + 1) % ORDER.size()
		KEY_LEFT:
			_index = (_index - 1 + ORDER.size()) % ORDER.size()
		_:
			return
	_apply_emotion(ORDER[_index])
