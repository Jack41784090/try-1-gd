extends Node2D

## Animation test harness for warrior_rig_2.
## Instances the rig, applies a textured config, and lets you cycle behaviors
## with the number keys / arrows so skeleton + animation edits in
## warrior_rig_2.tscn can be verified with F6.
##
## Live texture reload: while running, edits to the config's source art files
## (e.g. the .svg bone textures) OR to the config .tres itself (reassigning a
## slot) are detected on disk and re-applied immediately — no restart.

const BEHAVIORS: Array[AnimTypes.Behavior] = [
	AnimTypes.Behavior.IDLE,
	AnimTypes.Behavior.WALKING,
	AnimTypes.Behavior.ATTACKING,
	AnimTypes.Behavior.DEFENDING,
	AnimTypes.Behavior.HURT,
	AnimTypes.Behavior.DYING,
	AnimTypes.Behavior.TALKING,
	AnimTypes.Behavior.GESTURING,
]

const BEHAVIOR_NAMES: Array[String] = [
	"idle", "walking", "attacking", "defending",
	"hurt", "dying", "talking", "gesturing",
]

const POLL_INTERVAL := 0.4
const SVG_RENDER_SCALE := 4.0

@export var config: WarriorRigConfig

@onready var rig: WarriorRig = $Rig
@onready var status_label: Label = $UI/StatusLabel

var _index: int = 0
var _tpose: bool = false # showing static rest/T-pose instead of an animation
var _poll_accum: float = 0.0
var _mtimes: Dictionary = {} # abs_path -> modified_time (config .tres + each source texture)
var _last_sig: String = "" # signature of the live config's sizes/offsets/texture paths

func _ready() -> void:
	if config:
		_refresh(false)
	_play(_index)

func _process(delta: float) -> void:
	if not config:
		return
	_poll_accum += delta
	if _poll_accum < POLL_INTERVAL:
		return
	_poll_accum = 0.0
	if _disk_changed():
		_refresh(true)
	elif _config_signature() != _last_sig:
		# Live edit to the in-memory config (e.g. a bone size tweaked in the
		# running remote inspector) — no file changed, so re-apply directly.
		_refresh(false)

## Captures the config's current sizes, offsets, and texture assignments so an
## inline (no .tres) config edited at runtime still triggers a re-apply.
func _config_signature() -> String:
	var parts := PackedStringArray()
	var sizes := config.get_bone_sizes()
	var offsets := config.get_bone_offsets()
	for bone_name in sizes:
		parts.append("%s|%s|%s" % [bone_name, sizes[bone_name], offsets[bone_name]])
	var textures := config.get_bone_textures()
	for bone_name in textures:
		var tex: Texture2D = textures[bone_name]
		parts.append("%s=%s" % [bone_name, tex.resource_path if tex else ""])
	return "/".join(parts)

#region Live texture reload

func _disk_changed() -> bool:
	for abs_path in _watched_paths():
		if not FileAccess.file_exists(abs_path):
			continue
		if _mtimes.get(abs_path, -1) != FileAccess.get_modified_time(abs_path):
			return true
	return false

func _watched_paths() -> Array[String]:
	var paths: Array[String] = []
	if not config.resource_path.is_empty():
		paths.append(ProjectSettings.globalize_path(config.resource_path))
	for tex in config.get_bone_textures().values():
		if tex and not tex.resource_path.is_empty():
			paths.append(ProjectSettings.globalize_path(tex.resource_path))
	return paths

func _refresh(reload_config: bool) -> void:
	# Re-read the .tres from disk so slot reassignments are picked up.
	if reload_config and not config.resource_path.is_empty():
		var fresh := ResourceLoader.load(
			config.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if fresh is WarriorRigConfig:
			config = fresh

	# Rebuild every slot from its source file on disk (fresh art each time).
	# Duplicate the source config first so bone sizes/offsets carry through.
	var rebuilt: WarriorRigConfig = config.duplicate()
	for bone_name in config.get_bone_textures():
		var tex: Texture2D = config.get_bone_textures()[bone_name]
		var out_tex: Texture2D = tex
		if tex and not tex.resource_path.is_empty():
			var abs_path := ProjectSettings.globalize_path(tex.resource_path)
			if FileAccess.file_exists(abs_path):
				var reloaded := _load_texture_from_disk(abs_path)
				if reloaded:
					out_tex = reloaded
		_set_slot(rebuilt, bone_name, out_tex)

	rig.apply_config(rebuilt)
	_snapshot_mtimes()
	_last_sig = _config_signature()
	if reload_config:
		Log.info("AnimationTest", "Textures reloaded from disk")

func _snapshot_mtimes() -> void:
	_mtimes.clear()
	for abs_path in _watched_paths():
		if FileAccess.file_exists(abs_path):
			_mtimes[abs_path] = FileAccess.get_modified_time(abs_path)

func _load_texture_from_disk(abs_path: String) -> Texture2D:
	if abs_path.to_lower().ends_with(".svg"):
		var file := FileAccess.open(abs_path, FileAccess.READ)
		if not file:
			return null
		var svg_text := file.get_as_text()
		file.close()
		var image := Image.new()
		if image.load_svg_from_string(svg_text, SVG_RENDER_SCALE) != OK:
			return null
		return ImageTexture.create_from_image(image)
	var img := Image.new()
	if img.load(abs_path) != OK:
		return null
	return ImageTexture.create_from_image(img)

func _set_slot(cfg: WarriorRigConfig, bone_name: String, tex: Texture2D) -> void:
	match bone_name:
		"Head": cfg.head_texture = tex
		"Torso": cfg.torso_texture = tex
		"Hips": cfg.hips_texture = tex
		"LeftArm": cfg.left_arm_texture = tex
		"LeftForearm": cfg.left_forearm_texture = tex
		"LeftHand": cfg.left_hand_texture = tex
		"RightArm": cfg.right_arm_texture = tex
		"RightForearm": cfg.right_forearm_texture = tex
		"RightHand": cfg.right_hand_texture = tex
		"LeftLeg": cfg.left_leg_texture = tex
		"LeftShin": cfg.left_shin_texture = tex
		"LeftFoot": cfg.left_foot_texture = tex
		"RightLeg": cfg.right_leg_texture = tex
		"RightShin": cfg.right_shin_texture = tex
		"RightFoot": cfg.right_foot_texture = tex

#endregion

#region Animation controls

func _play(idx: int) -> void:
	_tpose = false
	_index = wrapi(idx, 0, BEHAVIORS.size())
	rig.play_behavior(BEHAVIORS[_index])
	_update_label()

func _pose_rest() -> void:
	_tpose = true
	rig.pose_rest()
	_update_label()

func _update_label() -> void:
	var lines := PackedStringArray()
	var current := "T-pose (rest, no anim)" if _tpose else BEHAVIOR_NAMES[_index]
	lines.append("Animation: %s" % current)
	lines.append("")
	lines.append("[1-8] select   [←/→] cycle   [R] replay   [T] T-pose")
	lines.append("textures hot-reload on file change")
	for i in BEHAVIOR_NAMES.size():
		lines.append("  %d: %s" % [i + 1, BEHAVIOR_NAMES[i]])
	status_label.text = "\n".join(lines)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key >= KEY_1 and key <= KEY_8:
		_play(key - KEY_1)
	elif key == KEY_RIGHT:
		_play(_index + 1)
	elif key == KEY_LEFT:
		_play(_index - 1)
	elif key == KEY_T:
		_pose_rest()
	elif key == KEY_R:
		# Re-travel to force one-shot anims (attack/hurt/die) to restart.
		rig.play_behavior(AnimTypes.Behavior.IDLE)
		await get_tree().process_frame
		_play(_index)

#endregion
