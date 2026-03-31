class_name WarriorRigConfig extends Resource

@export var class_id: EntityClasses.Types

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

@export_group("Face")
@export var eye_spritesheet: Texture2D
@export var mouth_spritesheet: Texture2D
@export var default_expression: iExpression

func get_bone_textures() -> Dictionary:
	var textures: Dictionary = {}
	## Z-order: back-to-front for side-facing character
	# Far arm (behind body)
	if left_arm_texture:
		textures["LeftArm"] = left_arm_texture
	if left_forearm_texture:
		textures["LeftForearm"] = left_forearm_texture
	if left_hand_texture:
		textures["LeftHand"] = left_hand_texture
	# Far leg
	if left_leg_texture:
		textures["LeftLeg"] = left_leg_texture
	if left_shin_texture:
		textures["LeftShin"] = left_shin_texture
	if left_foot_texture:
		textures["LeftFoot"] = left_foot_texture
	# Hips
	if hips_texture:
		textures["Hips"] = hips_texture
	# Near leg (in front of hips)
	if right_leg_texture:
		textures["RightLeg"] = right_leg_texture
	if right_shin_texture:
		textures["RightShin"] = right_shin_texture
	if right_foot_texture:
		textures["RightFoot"] = right_foot_texture
	# Torso (on top of legs)
	if torso_texture:
		textures["Torso"] = torso_texture
	# Head
	if head_texture:
		textures["Head"] = head_texture
	# Near arm (on top of everything)
	if right_arm_texture:
		textures["RightArm"] = right_arm_texture
	if right_forearm_texture:
		textures["RightForearm"] = right_forearm_texture
	if right_hand_texture:
		textures["RightHand"] = right_hand_texture
	return textures
