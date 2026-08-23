@tool
class_name WarriorRigConfig extends Resource

@export var class_id: String = ""

@export var has_face_components: bool = false ## all characters share one rig scene, so this hides the Face subtree outright when false instead of leaving the previous character's face showing

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

## Per-bone size in px (x, y) plus z_index draw order (z), overriding the rig's BONE_DRAW_ORDER; a zero x/y falls back to the rig's BONE_DISPLAY_SIZES constant.
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

@export_group("Bone Offsets") ## per-bone pixel offset; zero leaves the sprite centred on the bone
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
