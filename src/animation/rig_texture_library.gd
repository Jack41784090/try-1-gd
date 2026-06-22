class_name RigTextureLibrary extends RefCounted

## Derives WarriorRig art from the on-disk asset folders, so a rig can be textured
## by naming a character folder + an emotion instead of hand-wiring a config.
##
## - Character names are the sub-folders of `assets/rig_textures/` (landsknecht,
##   rachelle, faust1, ...).
## - Emotions are the `<feature>_<emotion>.svg` tokens under a character's `face/`
##   folder (neutral, wide, blink, ...), emitted by `tools/export_face_features.py`.
##
## Both lists are scanned live from the filesystem (no hardcoded enum), so adding a
## folder or authoring a new emotion sub-group updates the WarriorRig dropdowns
## automatically.

const ROOT := "res://assets/rig_textures/"

## Bone SVG file stem -> WarriorRigConfig texture property. Head is handled
## separately (it prefers the face-split `face/head_base_*.svg` base).
const BONE_FILES := {
	"torso": "torso_texture",
	"hips": "hips_texture",
	"leftarm": "left_arm_texture",
	"leftforearm": "left_forearm_texture",
	"lefthand": "left_hand_texture",
	"rightarm": "right_arm_texture",
	"rightforearm": "right_forearm_texture",
	"righthand": "right_hand_texture",
	"leftleg": "left_leg_texture",
	"leftshin": "left_shin_texture",
	"leftfoot": "left_foot_texture",
	"rightleg": "right_leg_texture",
	"rightshin": "right_shin_texture",
	"rightfoot": "right_foot_texture",
}

const DEFAULT_EMOTION := "neutral"

## Sub-folder names under ROOT, sorted — the available character looks.
static func character_names() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(ROOT)
	if dir == null:
		return out
	for name in dir.get_directories():
		if not name.begins_with("."):
			out.append(name)
	out.sort()
	return out

## Emotion tokens discovered across every character's per-eye `face/eye_[lr]_*.svg`,
## with "neutral" first. Falls back to ["neutral"] when nothing is found.
static func emotion_names() -> PackedStringArray:
	var found := {}
	for character in character_names():
		var dir := DirAccess.open(ROOT + character + "/face/")
		if dir == null:
			continue
		for f in dir.get_files():
			for prefix in ["eye_l_", "eye_r_"]:
				if f.begins_with(prefix) and f.ends_with(".svg"):
					found[f.trim_prefix(prefix).trim_suffix(".svg")] = true
	var out := PackedStringArray([DEFAULT_EMOTION])
	found.erase(DEFAULT_EMOTION)
	var rest := found.keys()
	rest.sort()
	for token in rest:
		out.append(token)
	return out

## True when the named character folder exists.
static func has_character(character: String) -> bool:
	return not character.is_empty() and DirAccess.dir_exists_absolute(ROOT + character)

## Builds a config for a character + emotion. When `base` is given it is deep-copied
## first (keeping its bone sizes/offsets) and only the textures are overlaid, so an
## existing proportion config (e.g. warrior_rig_2 sizes) can be retextured by name.
static func build_config(character: String, emotion: String = DEFAULT_EMOTION,
		base: WarriorRigConfig = null) -> WarriorRigConfig:
	var config: WarriorRigConfig = base.duplicate(true) if base else WarriorRigConfig.new()
	apply_textures(config, character, emotion)
	return config

## Overlays a character folder's bone + face textures onto an existing config.
static func apply_textures(config: WarriorRigConfig, character: String,
		emotion: String = DEFAULT_EMOTION) -> void:
	if not has_character(character):
		return
	var folder := ROOT + character + "/"
	for stem in BONE_FILES:
		var tex := _load_svg(folder + stem + ".svg")
		if tex:
			config.set(BONE_FILES[stem], tex)

	# Head: prefer the face-split base (eyes/mouth/brows removed) so the overlays
	# sit on a clean head; fall back to the whole head.svg for non-split folders.
	var face := folder + "face/"
	var head := _load_emotion(face, "head_base", emotion)
	if head == null:
		head = _load_svg(folder + "head.svg")
	if head:
		config.head_texture = head

	var eye_l := _load_emotion(face, "eye_l", emotion)
	if eye_l:
		config.eye_l_texture = eye_l
	var eye_r := _load_emotion(face, "eye_r", emotion)
	if eye_r:
		config.eye_r_texture = eye_r
	var mouth := _load_emotion(face, "mouth", emotion)
	if mouth:
		config.mouth_texture = mouth
	var brows := _load_emotion(face, "brows", emotion)
	if brows:
		config.brows_texture = brows
	var hair := _load_emotion(face, "hair_back", emotion)
	if hair:
		config.hair_back_texture = hair

	# The loaded overlays ARE the requested emotion. Clear any base default
	# expression so WarriorRig._apply_config_internal doesn't re-apply it on top
	# and snap the face back to neutral.
	config.default_expression = null

## Loads `face/<feature>_<emotion>.svg`, falling back to the neutral variant.
static func _load_emotion(face_dir: String, feature: String, emotion: String) -> Texture2D:
	var tex := _load_svg(face_dir + feature + "_" + emotion + ".svg")
	if tex == null and emotion != DEFAULT_EMOTION:
		tex = _load_svg(face_dir + feature + "_" + DEFAULT_EMOTION + ".svg")
	return tex

static func _load_svg(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
