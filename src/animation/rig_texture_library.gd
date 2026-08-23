class_name RigTextureLibrary extends RefCounted

## Both character and emotion lists are scanned live from the filesystem (no hardcoded enum), so a new folder or emotion sub-group updates the WarriorRig dropdowns automatically. Face art itself is NOT loaded here — face parts are baked into the rig scene, and an emotion is just an intent broadcast to them.

const ROOT := "res://assets/rig_textures/"

const BONE_FILES := { ## bone SVG file stem -> WarriorRigConfig texture property; head is handled separately
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

## Falls back to ["neutral"] when nothing is found.
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

static func has_character(character: String) -> bool:
	return not character.is_empty() and DirAccess.dir_exists_absolute(ROOT + character)

## When `base` is given it is deep-copied first (keeping its bone sizes/offsets) and only the textures are overlaid, so an existing proportion config can be retextured by name.
static func build_config(character: String,
		base: WarriorRigConfig = null) -> WarriorRigConfig:
	var config: WarriorRigConfig = base.duplicate(true) if base else WarriorRigConfig.new()
	apply_textures(config, character)
	return config

static func apply_textures(config: WarriorRigConfig, character: String) -> void:
	if not has_character(character):
		return
	var folder := ROOT + character + "/"
	for stem in BONE_FILES:
		var tex := _load_svg(folder + stem + ".svg")
		if tex:
			config.set(BONE_FILES[stem], tex)

	## Prefers the face-split base (parts removed) so baked overlays sit on a clean head; falls back to the whole head.svg for non-split folders.
	var head := _load_svg(folder + "face/head_base_" + DEFAULT_EMOTION + ".svg")
	if head == null:
		head = _load_svg(folder + "head.svg")
	if head:
		config.head_texture = head

static func _load_svg(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
