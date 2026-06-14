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

var class_id: EntityClasses.Types
var character_id: String = ""
var facing: int = 1
var _synced_parts: Array[Dictionary] = []
var _limb_nodes: Dictionary = {}
var _pending_config: WarriorRigConfig

@onready var skeleton: Skeleton2D = $Skeleton2D
@onready var face_node: Node2D = $Face
@onready var eyes: Sprite2D = $Face/Eyes
@onready var mouth: Sprite2D = $Face/Mouth
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var anim_tree: AnimationTree = $AnimTree
@onready var anim_controller: WarriorAnimController = $WarriorAnimController

func _ready() -> void:
	anim_controller.setup(anim_tree, anim_player)
	_build_placeholder_body()
	if _pending_config:
		_apply_config_internal(_pending_config)
		_pending_config = null

func _process(_delta: float) -> void:
	for part in _synced_parts:
		var bone: Bone2D = part.bone
		var node: Node2D = part.node
		if is_instance_valid(bone) and is_instance_valid(node):
			node.global_transform = bone.global_transform
			if part.has("display_scale"):
				node.scale = part.display_scale

func setup(p_class_id = null, p_character_id: String = "", p_facing: int = 1) -> void:
	class_id = p_class_id
	character_id = p_character_id
	facing = p_facing
	scale.x = facing

func setup_default(p_character_id: String = "") -> void:
	character_id = p_character_id
	scale.x = 1.0

func apply_config(config: WarriorRigConfig) -> void:
	if not config:
		return
	if not is_node_ready():
		_pending_config = config
		return
	_apply_config_internal(config)

func _apply_config_internal(config: WarriorRigConfig) -> void:
	var bone_textures := config.get_bone_textures()
	var bone_sizes := config.get_bone_sizes()
	var bone_offsets := config.get_bone_offsets()
	for bone_name in BONE_DRAW_ORDER:
		if bone_textures.has(bone_name):
			_replace_limb(bone_name, bone_textures[bone_name],
				bone_sizes.get(bone_name, Vector3.ZERO),
				bone_offsets.get(bone_name, Vector2.ZERO))
	if config.eye_spritesheet and eyes:
		eyes.texture = config.eye_spritesheet
	if config.mouth_spritesheet and mouth:
		mouth.texture = config.mouth_spritesheet
	if config.default_expression:
		anim_controller.set_expression(config.default_expression)

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

func set_expression(expr: iExpression) -> void:
	anim_controller.set_expression(expr)

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
	if _limb_nodes.has(bone_name):
		for node in _limb_nodes[bone_name]:
			if is_instance_valid(node):
				node.queue_free()
		_limb_nodes.erase(bone_name)
		_synced_parts = _synced_parts.filter(func(p: Dictionary) -> bool:
			return is_instance_valid(p.node) and not p.node.is_queued_for_deletion()
		)

	var bone := _find_bone_recursive(skeleton, bone_name)
	if not bone:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.top_level = true
	sprite.z_index = int(size_override.z) # Vector3.z = draw order override
	var target_size := Vector2(size_override.x, size_override.y)
	if target_size == Vector2.ZERO and BONE_DISPLAY_SIZES.has(bone_name):
		target_size = BONE_DISPLAY_SIZES[bone_name]
	var display_scale := Vector2.ONE
	if target_size != Vector2.ZERO:
		var tex_size := Vector2(texture.get_width(), texture.get_height())
		display_scale = Vector2(target_size.x / tex_size.x, target_size.y / tex_size.y)
		sprite.scale = display_scale
	var world_offset: Vector2 = offset_override
	if world_offset == Vector2.ZERO and BONE_OFFSETS.has(bone_name):
		world_offset = BONE_OFFSETS[bone_name]
	if world_offset != Vector2.ZERO:
		sprite.offset = world_offset / display_scale
	add_child(sprite)
	_limb_nodes[bone_name] = [sprite]
	_synced_parts.append({"node": sprite, "bone": bone, "display_scale": display_scale})

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
