@tool
class_name WarriorRigConfig extends Resource

@export var class_id: String = ""

@export_group("Body Textures")
@export var head_texture: Texture2D
## Back hair, rendered as a head-synced overlay behind the whole body (low
## z_index). Exported separately from the head base by export_face_features.py.
@export var hair_back_texture: Texture2D
@export var torso_texture: Texture2D
@export var hips_texture: Texture2D
@export var left_arm_texture: Texture2D
@export var left_forearm_texture: Texture2D
@export var left_hand_texture: Texture2D
@export var right_arm_texture: Texture2D
@export var right_forearm_texture: Texture2D
@export var right_hand_texture: Texture2D
@export var left_leg_texture: Texture2D
@export var left_shin_texture: Texture2D
@export var left_foot_texture: Texture2D
@export var right_leg_texture: Texture2D
@export var right_shin_texture: Texture2D
@export var right_foot_texture: Texture2D

## Per-bone rendered size in px (x, y) plus draw order (z). Defaults match the
## rig's BONE_DISPLAY_SIZES, so configs that leave these untouched render
## identically. The z component is the sprite's z_index — higher draws in front,
## overriding the rig's BONE_DRAW_ORDER tree order. A zero x/y falls back to the
## rig constant.
@export_group("Bone Sizes")
@export var head_size: Vector3 = Vector3(44, 50, 0)
@export var torso_size: Vector3 = Vector3(34, 28, 0)
@export var hips_size: Vector3 = Vector3(28, 8, 0)
@export var left_arm_size: Vector3 = Vector3(10, 22, 0)
@export var left_forearm_size: Vector3 = Vector3(8, 18, 0)
@export var left_hand_size: Vector3 = Vector3(14, 14, 0)
@export var right_arm_size: Vector3 = Vector3(10, 22, 0)
@export var right_forearm_size: Vector3 = Vector3(8, 18, 0)
@export var right_hand_size: Vector3 = Vector3(14, 14, 0)
@export var left_leg_size: Vector3 = Vector3(12, 26, 0)
@export var left_shin_size: Vector3 = Vector3(10, 22, 0)
@export var left_foot_size: Vector3 = Vector3(20, 10, 0)
@export var right_leg_size: Vector3 = Vector3(12, 26, 0)
@export var right_shin_size: Vector3 = Vector3(10, 22, 0)
@export var right_foot_size: Vector3 = Vector3(20, 10, 0)

## Per-bone pixel offset applied to the sprite relative to its bone. Zero leaves
## the sprite centred on the bone.
@export_group("Bone Offsets")
@export var head_offset: Vector2 = Vector2.ZERO
@export var torso_offset: Vector2 = Vector2.ZERO
@export var hips_offset: Vector2 = Vector2.ZERO
@export var left_arm_offset: Vector2 = Vector2.ZERO
@export var left_forearm_offset: Vector2 = Vector2.ZERO
@export var left_hand_offset: Vector2 = Vector2.ZERO
@export var right_arm_offset: Vector2 = Vector2.ZERO
@export var right_forearm_offset: Vector2 = Vector2.ZERO
@export var right_hand_offset: Vector2 = Vector2.ZERO
@export var left_leg_offset: Vector2 = Vector2.ZERO
@export var left_shin_offset: Vector2 = Vector2.ZERO
@export var left_foot_offset: Vector2 = Vector2.ZERO
@export var right_leg_offset: Vector2 = Vector2.ZERO
@export var right_shin_offset: Vector2 = Vector2.ZERO
@export var right_foot_offset: Vector2 = Vector2.ZERO

## Facial features render as full-canvas overlay sprites on top of the head base
## texture (head_texture should be the head_base_*.svg with eyes/mouth/brows
## removed). These are the neutral defaults; expressions swap them per-feature.
@export_group("Face")
## Left (near) and right (far) eyes are separate overlays so each can be swapped
## independently (winks, asymmetry). Exported per-eye by export_face_features.py.
@export var eye_l_texture: Texture2D
@export var eye_r_texture: Texture2D
@export var mouth_texture: Texture2D
@export var brows_texture: Texture2D
@export var default_expression: iExpression
## Named expressions this character can switch to (via the EXPRESSION cinematic
## action). Looked up by iExpression.expression_id; default_expression is also
## resolvable by its own id.
@export var expressions: Array[iExpression] = []

## Returns the expression whose expression_id matches (case-insensitive), or null.
## default_expression participates in the lookup too.
func get_expression(expression_id: String) -> iExpression:
	var key := expression_id.to_lower()
	if default_expression and default_expression.expression_id.to_lower() == key:
		return default_expression
	for expr in expressions:
		if expr and expr.expression_id.to_lower() == key:
			return expr
	return null

func get_bone_textures() -> Dictionary:
	var textures: Dictionary = {}
	## Z-order: back-to-front for side-facing character
	if left_arm_texture:
		textures["LeftArm"] = left_arm_texture
	if left_forearm_texture:
		textures["LeftForearm"] = left_forearm_texture
	if left_hand_texture:
		textures["LeftHand"] = left_hand_texture
	if left_leg_texture:
		textures["LeftLeg"] = left_leg_texture
	if left_shin_texture:
		textures["LeftShin"] = left_shin_texture
	if left_foot_texture:
		textures["LeftFoot"] = left_foot_texture
	if hips_texture:
		textures["Hips"] = hips_texture
	if right_leg_texture:
		textures["RightLeg"] = right_leg_texture
	if right_shin_texture:
		textures["RightShin"] = right_shin_texture
	if right_foot_texture:
		textures["RightFoot"] = right_foot_texture
	if torso_texture:
		textures["Torso"] = torso_texture
	if head_texture:
		textures["Head"] = head_texture
	if right_arm_texture:
		textures["RightArm"] = right_arm_texture
	if right_forearm_texture:
		textures["RightForearm"] = right_forearm_texture
	if right_hand_texture:
		textures["RightHand"] = right_hand_texture
	return textures

func get_bone_sizes() -> Dictionary:
	return {
		"Head": head_size,
		"Torso": torso_size,
		"Hips": hips_size,
		"LeftArm": left_arm_size,
		"LeftForearm": left_forearm_size,
		"LeftHand": left_hand_size,
		"RightArm": right_arm_size,
		"RightForearm": right_forearm_size,
		"RightHand": right_hand_size,
		"LeftLeg": left_leg_size,
		"LeftShin": left_shin_size,
		"LeftFoot": left_foot_size,
		"RightLeg": right_leg_size,
		"RightShin": right_shin_size,
		"RightFoot": right_foot_size,
	}

func get_bone_offsets() -> Dictionary:
	return {
		"Head": head_offset,
		"Torso": torso_offset,
		"Hips": hips_offset,
		"LeftArm": left_arm_offset,
		"LeftForearm": left_forearm_offset,
		"LeftHand": left_hand_offset,
		"RightArm": right_arm_offset,
		"RightForearm": right_forearm_offset,
		"RightHand": right_hand_offset,
		"LeftLeg": left_leg_offset,
		"LeftShin": left_shin_offset,
		"LeftFoot": left_foot_offset,
		"RightLeg": right_leg_offset,
		"RightShin": right_shin_offset,
		"RightFoot": right_foot_offset,
	}
