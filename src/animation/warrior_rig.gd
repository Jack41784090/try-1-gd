@tool
class_name WarriorRig extends Node2D

## SD / chibi flat-vector style — 1:2.5 head-to-body ratio
const SKIN_COLOR := Color(0.96, 0.82, 0.66) # #f5d0a8
const EYE_WHITE := Color(0.95, 0.93, 0.90)
const EYE_PUPIL := Color(0.12, 0.10, 0.10)
const MOUTH_COLOR := Color(0.75, 0.35, 0.30)
const HAIR_COLOR := Color(0.77, 0.60, 0.42) # #c49a6c — blonde default

const BONE_DISPLAY_SIZES: Dictionary = {
	"Head": Vector2(44, 50),
	"Torso": Vector2(34, 28),
	"Hips": Vector2(28, 8),
	"LeftArm": Vector2(10, 22),
	"LeftForearm": Vector2(8, 18),
	"LeftHand": Vector2(14, 14),
	"RightArm": Vector2(10, 22),
	"RightForearm": Vector2(8, 18),
	"RightHand": Vector2(14, 14),
	"LeftLeg": Vector2(12, 26),
	"LeftShin": Vector2(10, 22),
	"LeftFoot": Vector2(20, 10),
	"RightLeg": Vector2(12, 26),
	"RightShin": Vector2(10, 22),
	"RightFoot": Vector2(20, 10),
}

const BONE_OFFSETS: Dictionary = {
	"Head": Vector2(0, 0),
	"Torso": Vector2(0, 0),
	"Hips": Vector2(0, 0),
	"LeftArm": Vector2(0, 0),
	"LeftForearm": Vector2(0, 0),
	"LeftHand": Vector2(0, 0),
	"RightArm": Vector2(0, 0),
	"RightForearm": Vector2(0, 0),
	"RightHand": Vector2(0, 0),
	"LeftLeg": Vector2(0, 0),
	"LeftShin": Vector2(0, 0),
	"LeftFoot": Vector2(0, 0),
	"RightLeg": Vector2(0, 0),
	"RightShin": Vector2(0, 0),
	"RightFoot": Vector2(0, 0),
}

## Draw order back-to-front for right-facing character: Right* = far (profile edge), Left* = near (viewer side).
const BONE_DRAW_ORDER: Array[String] = [
	"RightArm", "RightForearm", "RightHand",
	"RightLeg", "RightShin", "RightFoot",
	"Hips",
	"LeftLeg", "LeftShin", "LeftFoot",
	"Torso",
	"Head",
	"LeftArm", "LeftForearm", "LeftHand",
]

## `character_name` + `emotion` (see _get_property_list) texture the rig from an asset folder by name instead; when a config is ALSO set, its bone sizes/offsets are kept and only the textures are overlaid.
@export var config: WarriorRigConfig:
	set(value):
		config = value
		_on_rig_source_changed()

## Not @export — the property list supplies the live PROPERTY_HINT_ENUM of folder/emotion names so the inspector dropdowns update as assets are added.
var character_name: String = "":
	set(value):
		character_name = value
		_on_rig_source_changed()
var emotion: String = "neutral":
	set(value):
		emotion = value
		_on_rig_source_changed()

var class_id: String = ""
var character_id: String = ""
var facing: int = 1
var _synced_parts: Array[Dictionary] = []
var _limb_nodes: Dictionary = {}
var _pending_config: WarriorRigConfig
## The config last applied — used to resolve named expressions at runtime.
var _applied_config: WarriorRigConfig
## Absolute z_index per bone name for baked sprites (see _compute_baked_z_order).
var _baked_z: Dictionary = {}

@onready var skeleton: Skeleton2D = $Skeleton2D
## Null on the legacy rig, which has no face parts — every call site treats that as "this rig has nothing to express with", not as an error.
@onready var face: Face = find_child("Face", true, false) as Face
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var anim_tree: AnimationTree = $AnimTree
@onready var anim_controller: WarriorAnimController = $WarriorAnimController

## Options are scanned from the asset folders, so dropdowns auto-update as characters/emotions are added. Requires @tool to be queried by the editor inspector.
func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": "character_name",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			## Leading comma = a blank "(none)" option, so leaving it unset falls back to the `config` resource.
			"hint_string": "," + ",".join(RigTextureLibrary.character_names()),
		},
		{
			"name": "emotion",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(RigTextureLibrary.emotion_names()),
		},
	]

func _ready() -> void:
	## @tool: live-preview the inspector dropdowns on baked rigs; legacy rigs are skipped since their placeholders rely on the per-frame _process sync, off in the editor.
	if Engine.is_editor_hint():
		if _has_baked_sprites():
			_apply_inspector_config()
		return
	anim_controller.setup(anim_tree, anim_player)
	## When baked Sprite2D children already exist on bones (warrior_rig_2), skip the runtime placeholder body — apply_config updates them in place instead.
	if not _has_baked_sprites():
		var p := {
			"torso": Color(0.80, 0.20, 0.20),
			"torso_accent": Color(0.86, 0.80, 0.53),
			"arms": Color(0.60, 0.13, 0.13),
			"hips": Color(0.45, 0.32, 0.22),
			"legs": Color(0.47, 0.38, 0.31),
			"boots": Color(0.48, 0.35, 0.25),
		}
		## Z-order: back-to-front for right-facing SD character; Left = NEAR (viewer side), Right = FAR (profile edge).
		_add_part("RightArm", _make_rect(Vector2(0, 8), 6, 14), p.arms)
		_add_part("RightForearm", _make_rect(Vector2(0, 6), 5, 11), p.arms)
		_add_part("RightHand", _make_circle(Vector2(0, 2), 3), SKIN_COLOR)
		_add_part("RightLeg", _make_rect(Vector2(0, 10), 7, 17), p.legs)
		_add_part("RightShin", _make_rect(Vector2(0, 8), 6, 14), p.boots)
		_add_part("RightFoot", _make_rect(Vector2(2, 2), 10, 5), p.boots)
		_add_part("Hips", _make_rect(Vector2(0, 0), 18, 5), p.hips)
		_add_part("LeftLeg", _make_rect(Vector2(0, 10), 7, 17), p.legs)
		_add_part("LeftShin", _make_rect(Vector2(0, 8), 6, 14), p.boots)
		_add_part("LeftFoot", _make_rect(Vector2(2, 2), 10, 5), p.boots)
		_add_part("Torso", _make_rect(Vector2(0, 6), 21, 18), p.torso)
		_add_part("Torso", _make_rect(Vector2(0, -4), 18, 5), p.torso_accent)
		_add_part("Head", _make_oval(Vector2(0, 6), 15, 17), SKIN_COLOR)
		_add_part("Head", _make_oval(Vector2(0, -2), 16, 8), HAIR_COLOR)
		_add_part("Head", _make_circle(Vector2(-5, 5), 3.5), EYE_WHITE)
		_add_part("Head", _make_circle(Vector2(5, 6), 2.5), EYE_WHITE)
		_add_part("Head", _make_circle(Vector2(-5, 5), 2.0), EYE_PUPIL)
		_add_part("Head", _make_circle(Vector2(5, 6), 1.5), EYE_PUPIL)
		_add_part("Head", _make_rect(Vector2(-2, 14), 4, 1.5), MOUTH_COLOR)
		_add_part("LeftArm", _make_rect(Vector2(0, 8), 6, 14), p.arms)
		_add_part("LeftForearm", _make_rect(Vector2(0, 6), 5, 11), p.arms)
		_add_part("LeftHand", _make_circle(Vector2(0, 2), 3), SKIN_COLOR)
	if _pending_config:
		_apply_config_internal(_pending_config)
		_pending_config = null
	else:
		_apply_inspector_config()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for part in _synced_parts:
		var bone: Bone2D = part.bone
		var node: Node2D = part.node
		if is_instance_valid(bone) and is_instance_valid(node):
			var xf: Transform2D = bone.global_transform
			if part.has("display_scale"):
				var ds: Vector2 = part.display_scale
				xf.x = xf.x.normalized() * ds.x
				xf.y = xf.y.normalized() * ds.y
			node.global_transform = xf

func setup(p_class_id = null, p_character_id: String = "", p_facing: int = 1) -> void:
	class_id = p_class_id
	character_id = p_character_id
	facing = p_facing
	scale.x = facing

func setup_default(p_character_id: String = "") -> void:
	character_id = p_character_id
	scale.x = 1.0

func apply_config(p_config: WarriorRigConfig) -> void:
	if not p_config:
		return
	if not is_node_ready():
		_pending_config = p_config
		return
	_apply_config_internal(p_config)

## Called from the property setters at runtime once the node is ready.
func _on_rig_source_changed() -> void:
	if not is_node_ready():
		return
	## In the editor only baked rigs preview (see _ready); at runtime always apply.
	if Engine.is_editor_hint() and not _has_baked_sprites():
		return
	_apply_inspector_config()

## A named character folder textures the rig (using `config` as a size/offset base when present); otherwise the `config` resource is applied directly. No-op when neither is set.
func _apply_inspector_config() -> void:
	var resolved: WarriorRigConfig = null
	if RigTextureLibrary.has_character(character_name):
		## Reuse the last-applied config as size base (when `config` isn't explicit) so an emotion change doesn't reset limbs to default sizes.
		var size_base: WarriorRigConfig = config if config else _applied_config
		resolved = RigTextureLibrary.build_config(character_name, size_base)
		resolved.has_face_components = face != null and character_name == face.character
	elif config:
		resolved = config
	if resolved:
		_apply_config_internal(resolved)
		## The emotion dropdown is just an intent by another name, exercising the same path a cutscene does.
		if resolved.has_face_components and face:
			face.express(StringName(emotion))

func _apply_config_internal(cfg: WarriorRigConfig) -> void:
	_applied_config = cfg
	var bone_textures := cfg.get_bone_textures()
	var bone_sizes := cfg.get_bone_sizes()
	var bone_offsets := cfg.get_bone_offsets()
	_baked_z = _compute_baked_z_order(bone_sizes)
	for bone_name in BONE_DRAW_ORDER:
		if bone_textures.has(bone_name):
			var bone := _find_bone_recursive(skeleton, bone_name)
			if bone:
				var size_override: Vector3 = bone_sizes.get(bone_name, Vector3.ZERO)
				var offset_override: Vector2 = bone_offsets.get(bone_name, Vector2.ZERO)
				var texture: Texture2D = bone_textures[bone_name]
				var target_size := limb_target_size(bone_name, size_override)
				var display_scale := limb_display_scale(texture, target_size)
				var world_offset: Vector2 = offset_override
				if world_offset == Vector2.ZERO and BONE_OFFSETS.has(bone_name):
					world_offset = BONE_OFFSETS[bone_name]
				var baked := _find_sprite_child(bone)
				if baked:
					baked.texture = texture
					baked.scale = display_scale
					baked.z_as_relative = false
					baked.z_index = _baked_z.get(bone_name, int(size_override.z))
					baked.offset = (world_offset / display_scale) if world_offset != Vector2.ZERO else Vector2.ZERO
				else:
					if _limb_nodes.has(bone_name):
						for node in _limb_nodes[bone_name]:
							if is_instance_valid(node):
								node.queue_free()
						_limb_nodes.erase(bone_name)
						_synced_parts = _synced_parts.filter(func(p: Dictionary) -> bool:
							return is_instance_valid(p.node) and not p.node.is_queued_for_deletion()
						)
					var sprite := Sprite2D.new()
					sprite.texture = texture
					sprite.top_level = true
					sprite.z_index = int(size_override.z)
					if target_size != Vector2.ZERO:
						sprite.scale = display_scale
					if world_offset != Vector2.ZERO:
						sprite.offset = world_offset / display_scale
					add_child(sprite)
					_limb_nodes[bone_name] = [sprite]
					_synced_parts.append({"node": sprite, "bone": bone, "display_scale": display_scale})
	## Hides the Face subtree when the config isn't that character's, else the face of whoever was rigged last bleeds through onto everyone else.
	if face:
		face.visible = cfg.has_face_components

func play_behavior(behavior: AnimTypes.Behavior) -> void:
	if anim_tree and not anim_tree.active:
		anim_tree.active = true
	anim_controller.play_behavior(behavior)

## For a rig authored in a T-pose, this shows that T-pose.
func pose_rest() -> void:
	if anim_tree:
		anim_tree.active = false
	if anim_player:
		anim_player.stop()
	_apply_rest_recursive(skeleton)

func _apply_rest_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Bone2D:
			child.apply_rest()
		_apply_rest_recursive(child)

## Entry point for the EXPRESSION cinematic action.
func set_expression_by_name(expression_id: String) -> void:
	if expression_id.is_empty() or not face:
		return
	face.express(StringName(expression_id.to_lower()))

func get_head_position() -> Vector2:
	if skeleton:
		var head = _find_bone_recursive(skeleton, "Head")
		if head:
			return head.global_position
	return global_position + Vector2(0, -80)

## Falls back to the rig constant when config size is zero. Shared by the runtime apply and the bake tool.
func limb_target_size(bone_name: String, size_override: Vector3) -> Vector2:
	var target_size := Vector2(size_override.x, size_override.y)
	if target_size == Vector2.ZERO and BONE_DISPLAY_SIZES.has(bone_name):
		target_size = BONE_DISPLAY_SIZES[bone_name]
	return target_size

## Sprite scale that renders a texture at target_size px. Shared with the bake tool.
func limb_display_scale(texture: Texture2D, target_size: Vector2) -> Vector2:
	if target_size == Vector2.ZERO or not texture:
		return Vector2.ONE
	var tex_size := Vector2(texture.get_width(), texture.get_height())
	if tex_size.x <= 0 or tex_size.y <= 0:
		return Vector2.ONE
	return Vector2(target_size.x / tex_size.x, target_size.y / tex_size.y)

## Bone-child sprites paint in skeleton-tree order, not the desired draw order, so this assigns an explicit z: sort by (config z, then BONE_DRAW_ORDER rank) and use that ranking as the absolute z_index.
func _compute_baked_z_order(bone_sizes: Dictionary) -> Dictionary:
	var entries: Array[Dictionary] = []
	for i in BONE_DRAW_ORDER.size():
		var bn: String = BONE_DRAW_ORDER[i]
		var sz: Vector3 = bone_sizes.get(bn, Vector3.ZERO)
		entries.append({"bone": bn, "z": int(sz.z), "rank": i})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.z != b.z:
			return a.z < b.z
		return a.rank < b.rank
	)
	var out: Dictionary = {}
	for j in entries.size():
		out[entries[j].bone] = j
	return out

func _find_sprite_child(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
	return null

func _has_baked_sprites() -> bool:
	for bone_name in BONE_DRAW_ORDER:
		var bone := _find_bone_recursive(skeleton, bone_name)
		if bone and _find_sprite_child(bone):
			return true
	return false

#region Placeholder Body Generation

func _add_part(bone_name: String, poly_shape: PackedVector2Array, color: Color) -> void:
	var bone := _find_bone_recursive(skeleton, bone_name)
	if not bone:
		return
	var poly := Polygon2D.new()
	poly.polygon = poly_shape
	poly.color = color
	poly.top_level = true
	add_child(poly)
	if not _limb_nodes.has(bone_name):
		_limb_nodes[bone_name] = []
	_limb_nodes[bone_name].append(poly)
	_synced_parts.append({"node": poly, "bone": bone})

func _make_rect(center: Vector2, w: float, h: float) -> PackedVector2Array:
	var hw := w * 0.5
	var hh := h * 0.5
	return PackedVector2Array([
		center + Vector2(-hw, -hh),
		center + Vector2(hw, -hh),
		center + Vector2(hw, hh),
		center + Vector2(-hw, hh),
	])

func _make_oval(center: Vector2, rx: float, ry: float, segs: int = 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * i / segs
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _make_circle(center: Vector2, r: float) -> PackedVector2Array:
	return _make_oval(center, r, r, 8)

#endregion

func _find_bone_recursive(node: Node, bone_name: String) -> Bone2D:
	for child in node.get_children():
		if child is Bone2D and child.name == bone_name:
			return child
		if child is Bone2D:
			var found = _find_bone_recursive(child, bone_name)
			if found:
				return found
	return null
