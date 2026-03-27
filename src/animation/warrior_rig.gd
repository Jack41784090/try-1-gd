class_name WarriorRig extends Node2D

const SKIN_COLOR := Color(0.93, 0.76, 0.60)
const EYE_WHITE := Color(0.95, 0.95, 0.97)
const EYE_PUPIL := Color(0.15, 0.12, 0.1)
const MOUTH_COLOR := Color(0.65, 0.32, 0.32)
const HAIR_COLOR := Color(0.25, 0.18, 0.12)

const BONE_DISPLAY_SIZES: Dictionary = {
	"Head": Vector2(22, 26),
	"Torso": Vector2(48, 44),
	"Hips": Vector2(40, 12),
	"LeftArm": Vector2(14, 36),
	"LeftForearm": Vector2(12, 26),
	"LeftHand": Vector2(10, 10),
	"RightArm": Vector2(14, 36),
	"RightForearm": Vector2(12, 26),
	"RightHand": Vector2(10, 10),
	"LeftLeg": Vector2(16, 48),
	"LeftShin": Vector2(14, 36),
	"LeftFoot": Vector2(24, 12),
	"RightLeg": Vector2(16, 48),
	"RightShin": Vector2(14, 36),
	"RightFoot": Vector2(24, 12),
}

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

func setup(p_class_id: EntityClasses.Types, p_character_id: String, p_facing: int = 1) -> void:
	class_id = p_class_id
	character_id = p_character_id
	facing = p_facing
	scale.x = facing

func apply_config(config: WarriorRigConfig) -> void:
	if not config:
		return
	if not is_node_ready():
		_pending_config = config
		return
	_apply_config_internal(config)

func _apply_config_internal(config: WarriorRigConfig) -> void:
	var bone_textures := config.get_bone_textures()
	for bone_name in bone_textures:
		_replace_limb(bone_name, bone_textures[bone_name])
	if config.eye_spritesheet and eyes:
		eyes.texture = config.eye_spritesheet
	if config.mouth_spritesheet and mouth:
		mouth.texture = config.mouth_spritesheet
	if config.default_expression:
		anim_controller.set_expression(config.default_expression)

func play_behavior(behavior: AnimTypes.Behavior) -> void:
	anim_controller.play_behavior(behavior)

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

func _replace_limb(bone_name: String, texture: Texture2D) -> void:
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
	var display_scale := Vector2.ONE
	if BONE_DISPLAY_SIZES.has(bone_name):
		var target_size: Vector2 = BONE_DISPLAY_SIZES[bone_name]
		var tex_size := Vector2(texture.get_width(), texture.get_height())
		display_scale = Vector2(target_size.x / tex_size.x, target_size.y / tex_size.y)
		sprite.scale = display_scale
	add_child(sprite)
	_limb_nodes[bone_name] = [sprite]
	_synced_parts.append({"node": sprite, "bone": bone, "display_scale": display_scale})

#region Placeholder Body Generation

func _build_placeholder_body() -> void:
	var p := _get_class_palette()

	_add_part("LeftLeg", _make_rect(Vector2(0, 12), 8, 24), p.legs)
	_add_part("LeftShin", _make_rect(Vector2(0, 9), 7, 18), p.boots)
	_add_part("LeftFoot", _make_rect(Vector2(2, 3), 12, 6), p.boots)
	_add_part("RightLeg", _make_rect(Vector2(0, 12), 8, 24), p.legs)
	_add_part("RightShin", _make_rect(Vector2(0, 9), 7, 18), p.boots)
	_add_part("RightFoot", _make_rect(Vector2(2, 3), 12, 6), p.boots)

	_add_part("Hips", _make_rect(Vector2(0, -2), 20, 6), p.hips)
	_add_part("Torso", _make_rect(Vector2(0, 10), 24, 22), p.torso)
	_add_part("Torso", _make_rect(Vector2(0, -2), 20, 6), p.torso_accent)

	_add_part("LeftArm", _make_rect(Vector2(0, 9), 7, 18), p.arms)
	_add_part("LeftForearm", _make_rect(Vector2(0, 6), 6, 13), p.arms)
	_add_part("LeftHand", _make_circle(Vector2(0, 3), 4), SKIN_COLOR)
	_add_part("RightArm", _make_rect(Vector2(0, 9), 7, 18), p.arms)
	_add_part("RightForearm", _make_rect(Vector2(0, 6), 6, 13), p.arms)
	_add_part("RightHand", _make_circle(Vector2(0, 3), 4), SKIN_COLOR)

	_add_part("Head", _make_oval(Vector2(0, -4), 11, 13), SKIN_COLOR)
	_add_part("Head", _make_oval(Vector2(0, -12), 12, 6), HAIR_COLOR)
	_add_part("Head", _make_circle(Vector2(-4, -5), 2.5), EYE_WHITE)
	_add_part("Head", _make_circle(Vector2(4, -5), 2.5), EYE_WHITE)
	_add_part("Head", _make_circle(Vector2(-4, -5), 1.2), EYE_PUPIL)
	_add_part("Head", _make_circle(Vector2(4, -5), 1.2), EYE_PUPIL)
	_add_part("Head", _make_rect(Vector2(0, 2), 5, 1.5), MOUTH_COLOR)

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
	match class_id:
		EntityClasses.Types.Healer:
			return {
				"torso": Color(0.22, 0.38, 0.72),
				"torso_accent": Color(0.28, 0.45, 0.78),
				"arms": Color(0.30, 0.45, 0.68),
				"hips": Color(0.32, 0.32, 0.52),
				"legs": Color(0.20, 0.28, 0.52),
				"boots": Color(0.28, 0.20, 0.16),
			}
		EntityClasses.Types.Crossbowman:
			return {
				"torso": Color(0.24, 0.39, 0.22),
				"torso_accent": Color(0.18, 0.31, 0.16),
				"arms": Color(0.27, 0.37, 0.25),
				"hips": Color(0.47, 0.33, 0.20),
				"legs": Color(0.39, 0.28, 0.18),
				"boots": Color(0.31, 0.23, 0.15),
			}
		EntityClasses.Types.Arquebusier:
			return {
				"torso": Color(0.31, 0.25, 0.22),
				"torso_accent": Color(0.24, 0.19, 0.16),
				"arms": Color(0.35, 0.29, 0.24),
				"hips": Color(0.39, 0.27, 0.18),
				"legs": Color(0.35, 0.25, 0.17),
				"boots": Color(0.22, 0.16, 0.12),
			}
		EntityClasses.Types.Pikeman:
			return {
				"torso": Color(0.63, 0.63, 0.67),
				"torso_accent": Color(0.51, 0.51, 0.56),
				"arms": Color(0.55, 0.55, 0.60),
				"hips": Color(0.55, 0.55, 0.60),
				"legs": Color(0.50, 0.50, 0.55),
				"boots": Color(0.27, 0.22, 0.15),
			}
		EntityClasses.Types.Feldprediger:
			return {
				"torso": Color(0.20, 0.16, 0.25),
				"torso_accent": Color(0.27, 0.23, 0.35),
				"arms": Color(0.35, 0.29, 0.47),
				"hips": Color(0.35, 0.29, 0.47),
				"legs": Color(0.30, 0.25, 0.40),
				"boots": Color(0.24, 0.18, 0.13),
			}
		EntityClasses.Types.Gelehrter:
			return {
				"torso": Color(0.47, 0.12, 0.31),
				"torso_accent": Color(0.35, 0.09, 0.24),
				"arms": Color(0.55, 0.20, 0.39),
				"hips": Color(0.27, 0.22, 0.22),
				"legs": Color(0.24, 0.18, 0.18),
				"boots": Color(0.22, 0.15, 0.15),
			}
		_:
			return {
				"torso": Color(0.72, 0.18, 0.18),
				"torso_accent": Color(0.58, 0.14, 0.14),
				"arms": Color(0.58, 0.15, 0.15),
				"hips": Color(0.42, 0.30, 0.22),
				"legs": Color(0.38, 0.28, 0.20),
				"boots": Color(0.28, 0.20, 0.14),
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
