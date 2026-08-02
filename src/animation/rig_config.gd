@tool
class_name WarriorRigConfig extends Resource

@export var class_id: String = ""

## Whether this character has a face at all. All characters currently share one
## baked rig scene, so a missing face can't announce itself the way an absent
## node would — this answers the one binary question (is the Face subtree this
## character's?) and hides it outright otherwise, rather than leaving whatever
## the previous character was showing. Individual FEATURES need no flag: a part
## a character never composed simply has nothing listening.
@export var has_face_components: bool = false

@export_group("Body Textures")
@export var head_texture: Texture2D
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
