@tool
extends SceneTree

## Bakes a WarriorRigConfig's textures directly into warrior_rig_2.tscn as Sprite2D
## children of each Bone2D (and the Face under the Head bone), so the rig shows
## fully textured IN THE EDITOR and animation poses can be previewed live by
## scrubbing the AnimationPlayer. At runtime WarriorRig.apply_config() updates these
## baked sprites in place (so the cutscene can still retexture per character).
##
## Re-run whenever the default character's textures or *_size values change:
##   godot --headless --path . --script res://tools/bake_rig_scene.gd
##
## Reuses WarriorRig's own size/scale/z helpers (run on the instantiated, not-yet-
## ready scene root) so the baked values match the runtime apply exactly.

const SCENE_PATH := "res://scenes/warrior_rig_2.tscn"
const CONFIG_PATH := "res://resources/character/wcr_adventurer_rachelle.tres"
# Asset folder the baked default is drawn from — also the editor-preview default
# for the character_name/emotion dropdowns.
const CHARACTER := "rachelle"

# Face overlay draw order (absolute z, z_as_relative=false). Limb baked z come from
# WarriorRig._compute_baked_z_order (0..14); the face sits in front, back hair behind.
const FACE_Z := {"HairBack": -1, "EyeL": 15, "EyeR": 15, "Mouth": 15, "Brows": 16}


func _initialize() -> void:
	var ok := _bake()
	if ok:
		print("[bake_rig_scene] Baked %s from %s" % [SCENE_PATH, CONFIG_PATH])
	else:
		push_error("[bake_rig_scene] FAILED")
	quit(0 if ok else 1)


func _bake() -> bool:
	var config := load(CONFIG_PATH) as WarriorRigConfig
	if not config:
		push_error("Could not load config: " + CONFIG_PATH)
		return false
	var packed := load(SCENE_PATH) as PackedScene
	if not packed:
		push_error("Could not load scene: " + SCENE_PATH)
		return false

	# instantiate() does NOT add to the tree, so _ready() / placeholder generation
	# never runs — we get a clean rig instance to author.
	var root := packed.instantiate() as WarriorRig
	if not root:
		push_error("Scene root is not a WarriorRig")
		return false
	var skeleton := root.get_node("Skeleton2D") as Skeleton2D

	var bone_textures := config.get_bone_textures()
	var bone_sizes := config.get_bone_sizes()
	var bone_offsets := config.get_bone_offsets()
	var z_order := root._compute_baked_z_order(bone_sizes)

	for bone_name in bone_textures.keys():
		var bone := root._find_bone_recursive(skeleton, bone_name)
		if not bone:
			push_warning("Bone not found: " + bone_name)
			continue
		var texture: Texture2D = bone_textures[bone_name]
		var target := root.limb_target_size(bone_name, bone_sizes.get(bone_name, Vector3.ZERO))
		var ds := root.limb_display_scale(texture, target)
		var offset: Vector2 = bone_offsets.get(bone_name, Vector2.ZERO)

		# Replace any sprite from a previous bake.
		var existing := root._find_sprite_child(bone)
		if existing:
			bone.remove_child(existing)
			existing.free()

		var sprite := Sprite2D.new()
		sprite.name = bone_name + "Sprite"
		sprite.texture = texture
		sprite.centered = true
		sprite.position = Vector2.ZERO
		sprite.scale = ds
		sprite.z_as_relative = false
		sprite.z_index = z_order.get(bone_name, 0)
		if offset != Vector2.ZERO and ds.x != 0.0 and ds.y != 0.0:
			sprite.offset = offset / ds
		bone.add_child(sprite)
		sprite.owner = root
		print("  %s: scale=%s z=%d tex=%s" % [bone_name, str(ds), sprite.z_index, texture.resource_path.get_file()])

	_bake_face(root, skeleton, config, bone_sizes, z_order)
	_detach_face_from_anim_tree(root)

	# Wire the proportion config + the baked character/emotion into the scene so the
	# @tool editor preview keeps these sizes and the emotion dropdown works out of
	# the box. Setters no-op here (root isn't in the tree yet).
	root.config = config
	root.character_name = CHARACTER
	root.emotion = "neutral"

	var out := PackedScene.new()
	var err := out.pack(root)
	if err != OK:
		push_error("PackedScene.pack failed: %d" % err)
		return false
	err = ResourceSaver.save(out, SCENE_PATH)
	if err != OK:
		push_error("ResourceSaver.save failed: %d" % err)
		return false
	return true


func _bake_face(root: WarriorRig, skeleton: Skeleton2D, config: WarriorRigConfig,
		bone_sizes: Dictionary, _z_order: Dictionary) -> void:
	var face := root.find_child("Face", true, false) as Node2D
	if not face:
		push_warning("No Face node — skipping face bake")
		return
	var head_bone := root._find_bone_recursive(skeleton, "Head")
	if not head_bone:
		push_warning("No Head bone — skipping face bake")
		return

	# Reparent Face under the Head bone so it tracks the head in the editor.
	if face.get_parent() != head_bone:
		face.owner = null # avoid an owner-inconsistency warning during reparent
		face.get_parent().remove_child(face)
		head_bone.add_child(face)
	var head_target := root.limb_target_size("Head", bone_sizes.get("Head", Vector3.ZERO))
	var head_ds := root.limb_display_scale(config.head_texture, head_target)
	face.position = Vector2.ZERO
	face.scale = head_ds

	# Drop the pre-split single-eye sprite; EyeL/EyeR replace it.
	var stale := face.find_child("Eyes", false, false)
	if stale:
		face.remove_child(stale)
		stale.free()

	var feature_tex := {
		"HairBack": config.hair_back_texture,
		"EyeL": config.eye_l_texture,
		"EyeR": config.eye_r_texture,
		"Mouth": config.mouth_texture,
		"Brows": config.brows_texture,
	}
	for feature_name in feature_tex.keys():
		# Create the overlay sprite when the scene doesn't have it yet (EyeL/EyeR).
		var sprite := face.find_child(feature_name, false, false) as Sprite2D
		if not sprite:
			sprite = Sprite2D.new()
			sprite.name = feature_name
			face.add_child(sprite)
		if feature_tex[feature_name]:
			sprite.texture = feature_tex[feature_name]
		sprite.centered = true
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
		sprite.z_as_relative = false
		sprite.z_index = FACE_Z.get(feature_name, 1)

	_set_owner_recursive(face, root)
	_repath_face_anim_tracks(root, face)
	_rename_eye_anim_tracks(root)


## Rewrites AnimationPlayer tracks that target the old root-level "Face/..." path to
## the Face's new location under the Head bone, so reparenting doesn't leave the
## (inert legacy) eyes/mouth frame tracks unresolved.
func _repath_face_anim_tracks(root: WarriorRig, face: Node2D) -> void:
	var anim_player := root.get_node_or_null("AnimPlayer") as AnimationPlayer
	if not anim_player:
		return
	var new_prefix := String(root.get_path_to(face)) + "/"
	if new_prefix == "Face/":
		return
	for lib_name in anim_player.get_animation_library_list():
		var lib := anim_player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			for i in anim.get_track_count():
				var path := String(anim.track_get_path(i))
				if path.begins_with("Face/"):
					anim.track_set_path(i, NodePath(new_prefix + path.substr(5)))


## The face overlays are driven by the texture-swap expression system, not the
## AnimTree. Point the blend-tree output straight at the body state machine so the
## leftover EyeAnim/MouthAnim face tracks can't overwrite expression textures each
## frame (they previously pinned the eyes/mouth to their neutral overlay).
func _detach_face_from_anim_tree(root: WarriorRig) -> void:
	var anim_tree := root.get_node_or_null("AnimTree") as AnimationTree
	if not anim_tree:
		return
	var tree_root := anim_tree.tree_root as AnimationNodeBlendTree
	if not tree_root or tree_root.get_node("OutputAdd") == null:
		return
	# Drop FaceBlend (EyeAnim + MouthAnim) from the OutputAdd's second input; the
	# Add2 then passes the body state machine through untouched.
	tree_root.disconnect_node("OutputAdd", 1)


## Repoints the inert legacy "Face/Eyes:*" animation tracks (texture/position/
## rotation/frame) at the new left-eye node so they resolve after the eye split.
func _rename_eye_anim_tracks(root: WarriorRig) -> void:
	var anim_player := root.get_node_or_null("AnimPlayer") as AnimationPlayer
	if not anim_player:
		return
	for lib_name in anim_player.get_animation_library_list():
		var lib := anim_player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			for i in anim.get_track_count():
				var path := String(anim.track_get_path(i))
				if "/Face/Eyes:" in path:
					anim.track_set_path(i, NodePath(path.replace("/Face/Eyes:", "/Face/EyeL:")))


func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)
