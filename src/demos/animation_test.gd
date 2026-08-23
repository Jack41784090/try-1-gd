extends Node2D

## Animation test harness for warrior_rig_2 (F6) — cycle behaviors with number keys/arrows; edits to the config .tres or its source art files hot-reload with no restart.

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
## Expression intents to broadcast with the [E] key; each face part reacts independently, &"neutral" always restores the baked pose.
@export var expression_ids: Array[String] = ["neutral", "wide", "blink"]

@onready var rig: WarriorRig = $Rig
@onready var status_label: Label = $UI/StatusLabel

var _index: int = 0
var _expr_index: int = 0
var _tpose: bool = false # showing static rest/T-pose instead of an animation
var _poll_accum: float = 0.0
var _mtimes: Dictionary = {} # abs_path -> modified_time (config .tres + each source texture)
var _last_sig: String = "" # signature of the live config's sizes/offsets/texture paths
var _face_slots: Array[Dictionary] = [] # {node|reaction, path} per face texture slot

func _ready() -> void:
	if config:
		_refresh(false)
	_play(_index)

	print("=== Rig debug ===")
	print("rig global_position=%s scale=%s modulate=%s visible=%s" % [rig.global_position, rig.scale, rig.modulate, rig.visible])
	var sprites := 0
	for child in _find_all(rig, Sprite2D):
		sprites += 1
		var tex: Texture2D = child.texture
		var size := Vector2.ZERO
		var avg_alpha := 0.0
		if tex:
			size = Vector2(tex.get_width(), tex.get_height())
			var img: Image = tex.get_image()
			if img and img.get_width() > 0 and img.get_height() > 0:
				var sample: Color = img.get_pixel(img.get_width() / 2, img.get_height() / 2)
				avg_alpha = sample.a
		print("  sprite %s: pos=%s scale=%s visible=%s size=%s mid_alpha=%.2f" % [child.name, child.global_position, child.scale, child.visible, size, avg_alpha])
	print("total sprites: %d" % sprites)

func _find_all(node: Node, type: Variant) -> Array:
	var out: Array = []
	for child in node.get_children():
		if is_instance_of(child, type):
			out.append(child)
		out.append_array(_find_all(child, type))
	return out

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
		# In-memory-only edit (e.g. remote inspector) with no file change, so re-apply directly.
		_refresh(false)

## Lets an inline (no .tres) config edited at runtime still trigger a re-apply.
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

## Captured once: a reload replaces each imported texture with a path-less one rasterized from disk.
func _snapshot_face_slots() -> void:
	_face_slots.clear()
	if not rig.face:
		return
	for node in _find_all(rig.face, FaceComponent):
		if node.texture and not node.texture.resource_path.is_empty():
			_face_slots.append({"node": node, "path": node.texture.resource_path})
		for reaction in node.reactions:
			if reaction and reaction.texture and not reaction.texture.resource_path.is_empty():
				_face_slots.append({"reaction": reaction, "path": reaction.texture.resource_path})

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
	for slot in _face_slots:
		paths.append(ProjectSettings.globalize_path(slot.path))
	return paths

func _refresh(reload_config: bool) -> void:
	# Re-read the .tres from disk so slot reassignments are picked up.
	if reload_config and not config.resource_path.is_empty():
		var fresh := ResourceLoader.load(
			config.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if fresh is WarriorRigConfig:
			config = fresh

	# Use the config's imported textures directly (skip disk reload for now).
	rig.apply_config(config.duplicate())
	if _face_slots.is_empty():
		_snapshot_face_slots()
	if reload_config:
		for slot in _face_slots:
			var tex := _load_texture_from_disk(ProjectSettings.globalize_path(slot.path))
			if not tex:
				continue
			if slot.has("node"):
				slot.node.texture = tex
			else:
				slot.reaction.texture = tex
	_apply_expression(_expr_index)
	_snapshot_mtimes()
	_last_sig = _config_signature()
	if reload_config:
		MyLog.info("AnimationTest", "Textures reloaded from disk")

## Each face part reacts independently, so one call can move brows, shrink pupils and swap lashes together.
func _apply_expression(idx: int) -> void:
	if expression_ids.is_empty():
		return
	_expr_index = wrapi(idx, 0, expression_ids.size())
	rig.set_expression_by_name(expression_ids[_expr_index])
	_update_label()

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

#endregion

#region Animation controls

func _play(idx: int) -> void:
	_tpose = false
	_index = wrapi(idx, 0, BEHAVIORS.size())
	rig.play_behavior(BEHAVIORS[_index])
	_update_label()

func _update_label() -> void:
	var lines := PackedStringArray()
	var current := "T-pose (rest, no anim)" if _tpose else BEHAVIOR_NAMES[_index]
	lines.append("Animation: %s" % current)
	lines.append("")
	lines.append("[1-8] select   [←/→] cycle   [R] replay   [T] T-pose")
	if not expression_ids.is_empty():
		lines.append("[E] expression: %s" % expression_ids[_expr_index])
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
	elif key == KEY_E:
		_apply_expression(_expr_index + 1)
	elif key == KEY_T:
		_tpose = true
		rig.pose_rest()
		_update_label()
	elif key == KEY_R:
		# Re-travel to force one-shot anims (attack/hurt/die) to restart.
		rig.play_behavior(AnimTypes.Behavior.IDLE)
		await get_tree().process_frame
		_play(_index)

#endregion
