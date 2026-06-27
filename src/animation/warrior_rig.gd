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

## Draw order back-to-front for right-facing character:
## Right* = far (profile edge), Left* = near (viewer side)
const BONE_DRAW_ORDER: Array[String] = [
	"RightArm", "RightForearm", "RightHand",
	"RightLeg", "RightShin", "RightFoot",
	"Hips",
	"LeftLeg", "LeftShin", "LeftFoot",
	"Torso",
	"Head",
	"LeftArm", "LeftForearm", "LeftHand",
]

## Inspector-driven texturing. Drop a fully-authored config here to replace the
## placeholder body outright. `character_name` + `emotion` (auto-derived dropdowns,
## see _get_property_list) instead texture the rig from an asset folder by name;
## when a config is ALSO set, its bone sizes/offsets are kept and only the textures
## are overlaid (build a config purely for warrior_rig_2 proportions, pick a look).
@export var config: WarriorRigConfig:
	set(value):
		config = value
		_on_rig_source_changed()

## Backing storage for the auto-derived dropdowns (see _get_property_list). Not
## @export — the property list supplies the live PROPERTY_HINT_ENUM of folder /
## emotion names so the inspector dropdowns update as assets are added.
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
# Face/feature refs are resolved by name (recursive) so they work whether Face is
# a root child (legacy warrior_rig) or baked under the Head bone (warrior_rig_2).
@onready var face_node: Node2D = find_child("Face", true, false)
# Left (near) and right (far) eyes are separate overlay sprites.
@onready var eye_l: Sprite2D = find_child("EyeL", true, false)
@onready var eye_r: Sprite2D = find_child("EyeR", true, false)
@onready var mouth: Sprite2D = find_child("Mouth", true, false)
# Optional — only the new-proportion rig (warrior_rig_2) has these overlays.
@onready var brows: Sprite2D = find_child("Brows", true, false)
@onready var hair_back: Sprite2D = find_child("HairBack", true, false)
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var anim_tree: AnimationTree = $AnimTree
@onready var anim_controller: WarriorAnimController = $WarriorAnimController

## Exposes `character_name` + `emotion` as live PROPERTY_HINT_ENUM dropdowns whose
## options are scanned from the asset folders, so they auto-update as characters /
## emotions are added. Requires @tool to be queried by the editor inspector.
func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": "character_name",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			# Leading comma = a blank "(none)" option, so leaving it unset falls
			# back to the `config` resource.
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
	# @tool: in the editor, live-preview the inspector dropdowns on baked rigs so
	# picking a character/emotion retextures immediately. Legacy rigs are skipped
	# (their placeholders rely on the per-frame _process sync, off in the editor).
	if Engine.is_editor_hint():
		if _has_baked_sprites():
			_apply_inspector_config()
		return
	anim_controller.setup(anim_tree, anim_player)
	# warrior_rig_2 ships textures baked as Sprite2D children of each bone (for
	# editor pose feedback). When those exist, skip the runtime placeholder body —
	# apply_config updates the baked sprites in place instead.
	if not _has_baked_sprites():
		_build_placeholder_body()
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

## Re-resolves and applies the inspector source (config and/or character_name +
## emotion). Called from the property setters at runtime once the node is ready.
func _on_rig_source_changed() -> void:
	if not is_node_ready():
		return
	# In the editor only baked rigs preview (see _ready); at runtime always apply.
	if Engine.is_editor_hint() and not _has_baked_sprites():
		return
	_apply_inspector_config()

## Resolves the effective config from the inspector fields: a named character
## folder textures the rig (using `config` as a size/offset base when present);
## otherwise the `config` resource is applied directly. No-op when neither is set.
func _apply_inspector_config() -> void:
	var resolved: WarriorRigConfig = null
	if RigTextureLibrary.has_character(character_name):
		# Keep the rig's proportions when retexturing by name: prefer the explicit
		# `config` as the size/offset base, else reuse the last-applied config so an
		# emotion change doesn't reset limbs to the default sizes.
		var size_base: WarriorRigConfig = config if config else _applied_config
		resolved = RigTextureLibrary.build_config(character_name, emotion, size_base)
	elif config:
		resolved = config
	if resolved:
		_apply_config_internal(resolved)

func _apply_config_internal(cfg: WarriorRigConfig) -> void:
	_applied_config = cfg
	var bone_textures := cfg.get_bone_textures()
	var bone_sizes := cfg.get_bone_sizes()
	var bone_offsets := cfg.get_bone_offsets()
	_baked_z = _compute_baked_z_order(bone_sizes)
	for bone_name in BONE_DRAW_ORDER:
		if bone_textures.has(bone_name):
			_replace_limb(bone_name, bone_textures[bone_name],
				bone_sizes.get(bone_name, Vector3.ZERO),
				bone_offsets.get(bone_name, Vector2.ZERO))
	# Facial-feature overlays (texture-swap expressions) — opt-in via config face
	# slots. Only the new-proportion rig uses them; the legacy rig has no face
	# textures, so this block (and _fit_face_to_head) is skipped and its existing
	# RemoteTransform2D-driven Face is left untouched.
	if cfg.eye_l_texture or cfg.eye_r_texture or cfg.mouth_texture or cfg.brows_texture or cfg.hair_back_texture:
		if eye_l and cfg.eye_l_texture:
			eye_l.texture = cfg.eye_l_texture
		if eye_r and cfg.eye_r_texture:
			eye_r.texture = cfg.eye_r_texture
		if mouth and cfg.mouth_texture:
			mouth.texture = cfg.mouth_texture
		if brows and cfg.brows_texture:
			brows.texture = cfg.brows_texture
		if hair_back and cfg.hair_back_texture:
			hair_back.texture = cfg.hair_back_texture
		# Baked rigs parent Face under the Head bone (so it tracks the head in the
		# editor); only the legacy top_level Face needs the per-frame fit.
		if not _face_is_baked():
			_fit_face_to_head(cfg)
	if cfg.default_expression:
		set_expression(cfg.default_expression)

## Syncs the Face node to the Head bone with the same display scale as the head
## sprite, so the full-canvas feature overlays (eyes/mouth/brows) sit exactly on
## the head base. Replaces the old static RemoteTransform2D, which couldn't carry
## the head's display scale.
func _fit_face_to_head(cfg: WarriorRigConfig) -> void:
	if not face_node:
		return
	var head_bone := _find_bone_recursive(skeleton, "Head")
	if not head_bone:
		return
	var target: Vector2 = BONE_DISPLAY_SIZES["Head"]
	var head_size: Vector3 = cfg.get_bone_sizes().get("Head", Vector3.ZERO)
	if Vector2(head_size.x, head_size.y) != Vector2.ZERO:
		target = Vector2(head_size.x, head_size.y)
	var display_scale := Vector2.ONE
	if cfg.head_texture:
		var tex_size := Vector2(cfg.head_texture.get_width(), cfg.head_texture.get_height())
		if tex_size.x > 0 and tex_size.y > 0:
			display_scale = Vector2(target.x / tex_size.x, target.y / tex_size.y)
	face_node.top_level = true
	for sprite in [eye_l, eye_r, mouth, brows, hair_back]:
		if sprite:
			sprite.centered = true
			sprite.position = Vector2.ZERO
			sprite.scale = Vector2.ONE
	_synced_parts = _synced_parts.filter(func(p: Dictionary) -> bool:
		return p.node != face_node
	)
	_synced_parts.append({"node": face_node, "bone": head_bone, "display_scale": display_scale})

func play_behavior(behavior: AnimTypes.Behavior) -> void:
	if anim_tree and not anim_tree.active:
		anim_tree.active = true
	anim_controller.play_behavior(behavior)

## Freezes the rig in its skeleton rest (bind) pose with no animation driving it.
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

## Swaps the per-feature overlay textures for an expression. Null features are
## left unchanged, so an expression can alter just the brows, just the eyes, etc.
func set_expression(expr: iExpression) -> void:
	if not expr:
		return
	if eye_l and expr.eye_l_texture:
		eye_l.texture = expr.eye_l_texture
	if eye_r and expr.eye_r_texture:
		eye_r.texture = expr.eye_r_texture
	if mouth and expr.mouth_texture:
		mouth.texture = expr.mouth_texture
	if brows and expr.brows_texture:
		brows.texture = expr.brows_texture
	anim_controller.set_expression(expr)

## Resolves a named expression (by iExpression.expression_id) against the applied
## config's expression set and applies it. Used by the EXPRESSION cinematic action.
func set_expression_by_name(expression_id: String) -> void:
	if expression_id.is_empty() or not _applied_config:
		return
	var expr := _applied_config.get_expression(expression_id)
	if expr:
		set_expression(expr)

func play_action(action: AnimAction) -> void:
	anim_controller.play_action(action)

func get_head_position() -> Vector2:
	if skeleton:
		var head = _find_bone_recursive(skeleton, "Head")
		if head:
			return head.global_position
	return global_position + Vector2(0, -80)

func clear_placeholders() -> void:
	for part in _synced_parts:
		if is_instance_valid(part.node):
			part.node.queue_free()
	_synced_parts.clear()
	_limb_nodes.clear()

func _replace_limb(bone_name: String, texture: Texture2D,
		size_override: Vector3 = Vector3.ZERO,
		offset_override: Vector2 = Vector2.ZERO) -> void:
	var bone := _find_bone_recursive(skeleton, bone_name)
	if not bone:
		return
	var target_size := limb_target_size(bone_name, size_override)
	var display_scale := limb_display_scale(texture, target_size)
	var world_offset: Vector2 = offset_override
	if world_offset == Vector2.ZERO and BONE_OFFSETS.has(bone_name):
		world_offset = BONE_OFFSETS[bone_name]

	# Baked rig (warrior_rig_2): a Sprite2D already lives under the bone for editor
	# pose feedback. Update it in place instead of spawning a top_level sprite.
	var baked := _find_sprite_child(bone)
	if baked:
		baked.texture = texture
		baked.scale = display_scale
		baked.z_as_relative = false
		baked.z_index = _baked_z.get(bone_name, int(size_override.z))
		baked.offset = (world_offset / display_scale) if world_offset != Vector2.ZERO else Vector2.ZERO
		return

	# Legacy rig (warrior_rig): no baked sprites — create a top_level sprite synced
	# to the bone each frame via _process.
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
	sprite.z_index = int(size_override.z) # Vector3.z = draw order override
	if target_size != Vector2.ZERO:
		sprite.scale = display_scale
	if world_offset != Vector2.ZERO:
		sprite.offset = world_offset / display_scale
	add_child(sprite)
	_limb_nodes[bone_name] = [sprite]
	_synced_parts.append({"node": sprite, "bone": bone, "display_scale": display_scale})

## Rendered px size of a limb sprite — config size (x, y), falling back to the rig
## constant when zero. Shared by the runtime apply and the bake tool.
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

## Absolute z_index per bone for baked (bone-child) sprites. Bone-child sprites
## paint in skeleton-tree order, which is NOT the desired draw order, so we assign
## an explicit z. The order reproduces the legacy scheme: sort by (config z, then
## BONE_DRAW_ORDER rank) and use that ranking as the absolute z_index. Shared with
## the bake tool so runtime retexturing keeps the baked layering.
func _compute_baked_z_order(bone_sizes: Dictionary) -> Dictionary:
	var entries: Array = []
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

## True when Face is parented under a bone (baked under Head in warrior_rig_2)
## rather than at the rig root (legacy).
func _face_is_baked() -> bool:
	return face_node != null and face_node.get_parent() is Bone2D

#region Placeholder Body Generation

func _build_placeholder_body() -> void:
	var p := _get_class_palette()
	## Z-order: back-to-front for right-facing SD character
	## Left side = NEAR (viewer side), Right side = FAR (profile edge)
	# Far arm (behind body)
	_add_part("RightArm", _make_rect(Vector2(0, 8), 6, 14), p.arms)
	_add_part("RightForearm", _make_rect(Vector2(0, 6), 5, 11), p.arms)
	_add_part("RightHand", _make_circle(Vector2(0, 2), 3), SKIN_COLOR)
	# Far leg
	_add_part("RightLeg", _make_rect(Vector2(0, 10), 7, 17), p.legs)
	_add_part("RightShin", _make_rect(Vector2(0, 8), 6, 14), p.boots)
	_add_part("RightFoot", _make_rect(Vector2(2, 2), 10, 5), p.boots)
	# Hips
	_add_part("Hips", _make_rect(Vector2(0, 0), 18, 5), p.hips)
	# Near leg (in front of hips)
	_add_part("LeftLeg", _make_rect(Vector2(0, 10), 7, 17), p.legs)
	_add_part("LeftShin", _make_rect(Vector2(0, 8), 6, 14), p.boots)
	_add_part("LeftFoot", _make_rect(Vector2(2, 2), 10, 5), p.boots)
	# Torso (on top of legs)
	_add_part("Torso", _make_rect(Vector2(0, 6), 21, 18), p.torso)
	_add_part("Torso", _make_rect(Vector2(0, -4), 18, 5), p.torso_accent)
	# Head — oversized for SD, 3/4 profile (big eye on left/near side)
	_add_part("Head", _make_oval(Vector2(0, 6), 15, 17), SKIN_COLOR)
	_add_part("Head", _make_oval(Vector2(0, -2), 16, 8), HAIR_COLOR)
	_add_part("Head", _make_circle(Vector2(-5, 5), 3.5), EYE_WHITE)
	_add_part("Head", _make_circle(Vector2(5, 6), 2.5), EYE_WHITE)
	_add_part("Head", _make_circle(Vector2(-5, 5), 2.0), EYE_PUPIL)
	_add_part("Head", _make_circle(Vector2(5, 6), 1.5), EYE_PUPIL)
	_add_part("Head", _make_rect(Vector2(-2, 14), 4, 1.5), MOUTH_COLOR)
	# Near arm (on top of everything)
	_add_part("LeftArm", _make_rect(Vector2(0, 8), 6, 14), p.arms)
	_add_part("LeftForearm", _make_rect(Vector2(0, 6), 5, 11), p.arms)
	_add_part("LeftHand", _make_circle(Vector2(0, 2), 3), SKIN_COLOR)

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

func _get_class_palette() -> Dictionary:
	return {
		"torso": Color(0.80, 0.20, 0.20),
		"torso_accent": Color(0.86, 0.80, 0.53),
		"arms": Color(0.60, 0.13, 0.13),
		"hips": Color(0.45, 0.32, 0.22),
		"legs": Color(0.47, 0.38, 0.31),
		"boots": Color(0.48, 0.35, 0.25),
	}

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
