class_name RigTextureLibrary extends RefCounted

## Derives WarriorRig art from the on-disk asset folders, so a rig can be textured
## by naming a character folder + an emotion instead of hand-wiring a config.
##
## - Character names are the sub-folders of `assets/rig_textures/` (landsknecht,
##   rachelle, faust1, ...).
## - Emotions are the trailing `_<emotion>` token of the files under a character's
##   `face/` folder (neutral, wide, blink, ...), emitted by
##   `tools/export_face_features.py` — which names every output `<part>_<emotion>`.
##
## Both lists are scanned live from the filesystem (no hardcoded enum), so adding a
## folder or authoring a new emotion sub-group updates the WarriorRig dropdowns
## automatically. Face art itself is NOT loaded here: the face parts are baked
## into the rig scene as a FaceComponent tree, and an emotion is just an intent
## the rig broadcasts to them.

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

## Emotion tokens discovered across every character's `face/` folder, with
## "neutral" first. Falls back to ["neutral"] when nothing is found.
static func emotion_names() -> PackedStringArray:
	var found := {}
	for character in character_names():
		var dir := DirAccess.open(ROOT + character + "/face/")
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".svg"):
				var stem := f.trim_suffix(".svg")
				found[stem.substr(stem.rfind("_") + 1)] = true
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

## Builds a config for a character. When `base` is given it is deep-copied first
## (keeping its bone sizes/offsets) and only the textures are overlaid, so an
## existing proportion config (e.g. warrior_rig_2 sizes) can be retextured by name.
static func build_config(character: String,
		base: WarriorRigConfig = null) -> WarriorRigConfig:
	var config: WarriorRigConfig = base.duplicate(true) if base else WarriorRigConfig.new()
	apply_textures(config, character)
	return config

## Overlays a character folder's bone + head textures onto an existing config.
static func apply_textures(config: WarriorRigConfig, character: String) -> void:
	if not has_character(character):
		return
	var folder := ROOT + character + "/"
	for stem in BONE_FILES:
		var tex := _load_svg(folder + stem + ".svg")
		if tex:
			config.set(BONE_FILES[stem], tex)

	## Head: prefer the face-split base (the face parts removed) so the baked
	## overlays sit on a clean head; fall back to the whole head.svg for non-split
	## folders. The base doesn't vary by emotion — the parts on top of it do.
	var head := _load_svg(folder + "face/head_base_" + DEFAULT_EMOTION + ".svg")
	if head == null:
		head = _load_svg(folder + "head.svg")
	if head:
		config.head_texture = head

static func _load_svg(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
