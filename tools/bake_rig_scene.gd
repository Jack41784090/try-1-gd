@tool
extends SceneTree

## Bakes a WarriorRigConfig's textures directly into warrior_rig_2.tscn as Sprite2D
## children of each Bone2D, and rebuilds the composable Face subtree under the Head
## bone from the per-part SVGs tools/export_face_features.py emits. The rig shows
## fully textured IN THE EDITOR and animation poses can be previewed live by
## scrubbing the AnimationPlayer. At runtime WarriorRig.apply_config() updates the
## baked body sprites in place (so the cutscene can still retexture per character).
##
## Re-run whenever the default character's textures or *_size values change:
##   godot --headless --path . --script res://tools/bake_rig_scene.gd
##   godot --headless --path . --script res://tools/bake_rig_scene.gd -- rachelle
##
## Accepts an optional character id (resolved via resources/characters/<id>.tres);
## defaults to rachelle. Reuses WarriorRig's own size/scale/z helpers (run on the
## instantiated, not-yet-ready scene root) so the baked values match the runtime
## apply exactly.

const SCENE_PATH := "res://scenes/rig/warrior_rig_2.tscn"
const MANIFEST_DIR := "res://resources/characters/"
const DEFAULT_CHARACTER := "rachelle"
const FACE_DIR := "res://assets/rig_textures/%s/face/"
const DEFAULT_EMOTION := "neutral"

# Limb baked z come from WarriorRig._compute_baked_z_order (0..14), so the face
# stacks above that. Each part's data-order is its place in the source artwork's
# painting order; a negative one (hair) belongs behind the whole body instead.
const FACE_Z_BASE := 15

# The face is driven by expression intents, not the AnimTree. These blend-tree
# nodes only ever wrote inert Sprite2D :frame=0 keys over the face overlays.
const DEAD_ANIM_NODES := ["OutputAdd", "FaceBlend", "EyeAnim", "MouthAnim"]
const DEAD_ANIMATIONS := ["eyes_neutral", "mouth_neutral"]


func _initialize() -> void:
	var character := _resolve_character()
	if character.is_empty():
		quit(1)
		return
	var ok := _bake(character)
	if ok:
		print("[bake_rig_scene] Baked %s for '%s'" % [SCENE_PATH, character])
	else:
		push_error("[bake_rig_scene] FAILED")
	quit(0 if ok else 1)


func _resolve_character() -> String:
	var args := OS.get_cmdline_args()
	var id := DEFAULT_CHARACTER
	for i in args.size():
		if args[i] == "--" and i + 1 < args.size():
			id = args[i + 1]
			break
		elif not args[i].begins_with("-"):
			id = args[i]
			break
	var manifest_path := MANIFEST_DIR + id + ".tres"
	if not FileAccess.file_exists(manifest_path):
		push_error("No manifest for '%s' — expected %s" % [id, manifest_path])
		return ""
	return id


func _config_for(id: String) -> WarriorRigConfig:
	var manifest := load(MANIFEST_DIR + id + ".tres") as CharacterManifest
	if manifest and manifest.rig_config:
		return manifest.rig_config
	var fallback_path := "res://resources/animation/configs/" + id + ".tres"
	return load(fallback_path) as WarriorRigConfig


func _bake(character: String) -> bool:
	var config := _config_for(character)
	if not config:
		push_error("Could not resolve WarriorRigConfig for: " + character)
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

	if not _bake_face(root, skeleton, config, bone_sizes, character):
		return false
	_strip_face_from_anim(root)

	# Wire the proportion config + the baked character/emotion into the scene so the
	# @tool editor preview keeps these sizes and the emotion dropdown works out of
	# the box. Setters no-op here (root isn't in the tree yet).
	root.config = config
	root.character_name = character
	root.emotion = DEFAULT_EMOTION

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


#region Face

## Rebuilds the Face subtree from the exported per-part SVGs.
##
## Each SVG names itself: data-part-path gives its place in the tree, data-order
## its place in the painting order, data-pivot the centre of its own artwork. The
## parts all share the master canvas, so they composite with every texture centred
## on the Face origin; the pivot only moves where a part scales and rotates ABOUT,
## which is why a pupil can shrink toward itself instead of toward the nose.
func _bake_face(root: WarriorRig, skeleton: Skeleton2D, config: WarriorRigConfig,
		bone_sizes: Dictionary, character: String) -> bool:
	var head_bone := root._find_bone_recursive(skeleton, "Head")
	if not head_bone:
		push_error("No Head bone — cannot bake face")
		return false

	var parts := _scan_face_parts(FACE_DIR % character)
	if parts.is_empty():
		push_error("No face parts found in " + (FACE_DIR % character))
		return false

	# Hand-tuned reactions live on the scene nodes, so carry them across a rebake;
	# only the per-emotion texture swaps below are ours to regenerate.
	var old_face := root.find_child("Face", true, false)
	var authored := {}
	if old_face:
		_collect_reactions(old_face, old_face, authored)
		old_face.get_parent().remove_child(old_face)
		old_face.free()

	var face := Face.new()
	face.name = "Face"
	face.character = character
	head_bone.add_child(face)
	face.position = Vector2.ZERO
	face.scale = root.limb_display_scale(
		config.head_texture,
		root.limb_target_size("Head", bone_sizes.get("Head", Vector3.ZERO)))

	# Shallowest first, so a parent node always exists before its children need it.
	var paths := parts.keys()
	paths.sort_custom(func(a: String, b: String) -> bool:
		var depth_a := a.count("/")
		var depth_b := b.count("/")
		if depth_a != depth_b:
			return depth_a < depth_b
		return parts[a].order < parts[b].order
	)

	var pivots := {}  # part path / group name -> pivot offset from canvas centre
	for path in paths:
		pivots[path] = _pivot_offset(parts[path].pivots[DEFAULT_EMOTION],
			parts[path].textures[DEFAULT_EMOTION])
	var groups := _pair_groupings(paths)
	for path in groups:
		# A pair anchors midway between its members, so scaling the pair scales
		# it about the pair rather than about the middle of the whole canvas.
		var members := groups.keys().filter(func(p: String) -> bool:
			return groups[p] == groups[path])
		var mid := Vector2.ZERO
		for member in members:
			mid += pivots[member]
		pivots[groups[path]] = mid / members.size()

	var nodes := {}  # part path / group name -> FaceComponent
	for path in paths:
		var part: Dictionary = parts[path]
		var parent: Node2D = face
		var parent_key: String = path.get_base_dir()
		if parent_key.is_empty() and groups.has(path):
			parent_key = groups[path]
			if not nodes.has(parent_key):
				var group := FaceComponent.new()
				group.name = parent_key
				face.add_child(group)
				group.position = pivots[parent_key]
				nodes[parent_key] = group
		if not parent_key.is_empty():
			parent = nodes[parent_key]

		var component := FaceComponent.new()
		component.name = _pascal(path.get_file())
		parent.add_child(component)
		component.texture = part.textures[DEFAULT_EMOTION]
		component.centered = true
		component.z_as_relative = false
		component.z_index = part.order if part.order < 0 else FACE_Z_BASE + part.order
		# position and offset cancel at rest, so every part still composites with
		# its texture centred on the Face; they only relocate the transform anchor.
		component.position = pivots[path] - pivots.get(parent_key, Vector2.ZERO)
		component.offset = -pivots[path]
		component.reactions = _reactions_for(part,
			authored.get(String(face.get_path_to(component)), []))
		nodes[path] = component
		print("  face %s: parent=%s z=%d pivot=%s reactions=%d"
			% [path, parent.name, component.z_index, str(pivots[path]),
				component.reactions.size()])

	_set_owner_recursive(face, root)
	return true


## Reads every exported part SVG in ``dir`` into
## {part path: {order, textures: {emotion: Texture2D}, pivots: {emotion: Vector2}}}.
func _scan_face_parts(dir_path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file_name in dir.get_files():
		if not file_name.ends_with(".svg"):
			continue
		var meta := _read_svg_meta(dir_path + file_name)
		var path: String = meta.get("part_path", "")
		if path.is_empty():
			continue  # the head base is the Head bone's own texture, not a part
		# Every export is named "<part>_<emotion>", so the emotion is the last token.
		var stem := file_name.trim_suffix(".svg")
		var emotion := stem.substr(stem.rfind("_") + 1)
		var entry: Dictionary = out.get_or_add(path, {
			"order": meta.get("order", 0), "textures": {}, "pivots": {},
		})
		entry.textures[emotion] = load(dir_path + file_name) as Texture2D
		entry.pivots[emotion] = meta.get("pivot", Vector2(0.5, 0.5))
	for path in out.keys():
		if not out[path].textures.has(DEFAULT_EMOTION):
			push_warning("Face part '%s' has no %s variant" % [path, DEFAULT_EMOTION])
			out.erase(path)
	return out


func _read_svg_meta(path: String) -> Dictionary:
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		return {}
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT or parser.get_node_name() != "svg":
			continue
		var out := {}
		if parser.has_attribute("data-part-path"):
			out.part_path = parser.get_named_attribute_value("data-part-path")
		if parser.has_attribute("data-order"):
			out.order = int(parser.get_named_attribute_value("data-order"))
		if parser.has_attribute("data-pivot"):
			var pair := parser.get_named_attribute_value("data-pivot").split(",")
			if pair.size() == 2:
				out.pivot = Vector2(float(pair[0]), float(pair[1]))
		return out
	return {}


## Where a part's own artwork sits relative to the texture's centre, in pixels —
## the anchor a Sprite2D scales and rotates about once position/offset cancel.
func _pivot_offset(fraction: Vector2, texture: Texture2D) -> Vector2:
	if not texture:
		return Vector2.ZERO
	return (fraction - Vector2(0.5, 0.5)) * Vector2(texture.get_width(), texture.get_height())


## Top-level parts that differ only by an _l/_r suffix share a synthesized parent
## (eye_l + eye_r -> Eyes), so an intent can move both at once.
func _pair_groupings(paths: Array) -> Dictionary:
	var out := {}
	for path in paths:
		var name := String(path)
		if name.contains("/") or not name.ends_with("_l"):
			continue
		var stem := name.trim_suffix("_l")
		if paths.has(stem + "_r"):
			out[name] = _pascal(stem) + "s"
			out[stem + "_r"] = _pascal(stem) + "s"
	return out


## This part's reaction list: one texture swap per non-default emotion it
## authors — so express("wide") / express("blink") work straight off the exported
## artwork — followed by whatever was hand-tuned for intents the artwork has no
## variant for, which a rebake must not throw away.
func _reactions_for(part: Dictionary, previous: Array) -> Array[FaceReaction]:
	var out: Array[FaceReaction] = []
	var emotions: Array = part.textures.keys()
	emotions.sort()
	for emotion in emotions:
		if emotion == DEFAULT_EMOTION:
			continue
		var reaction := FaceReaction.new()
		reaction.intent = StringName(emotion)
		reaction.texture = part.textures[emotion]
		out.append(reaction)
	for reaction in previous:
		if reaction and not part.textures.has(String(reaction.intent)):
			out.append(reaction)
	return out


## The existing scene's reactions, keyed by each component's path under the Face.
func _collect_reactions(node: Node, face: Node, out: Dictionary) -> void:
	if node is FaceComponent and not node.reactions.is_empty():
		out[String(face.get_path_to(node))] = node.reactions
	for child in node.get_children():
		_collect_reactions(child, face, out)


func _strip_face_from_anim(root: WarriorRig) -> void:
	var anim_tree := root.get_node_or_null("AnimTree") as AnimationTree
	if anim_tree:
		var tree_root := anim_tree.tree_root as AnimationNodeBlendTree
		if tree_root:
			var rewire := false
			for dead in DEAD_ANIM_NODES:
				if tree_root.has_node(dead):
					tree_root.remove_node(dead)
					rewire = true
			# Nothing removed means an earlier bake already rewired this; asking
			# for the same connection twice is an error.
			if rewire:
				tree_root.connect_node("output", 0, "BodyStateMachine")
	var anim_player := root.get_node_or_null("AnimPlayer") as AnimationPlayer
	if not anim_player:
		return
	for lib_name in anim_player.get_animation_library_list():
		var lib := anim_player.get_animation_library(lib_name)
		for dead in DEAD_ANIMATIONS:
			if lib.has_animation(dead):
				lib.remove_animation(dead)
		_rebuild_reset(root, lib)


## Rewrites RESET to hold a neutral value for every property any animation drives.
##
## An AnimationTree drives every property that appears anywhere in its player's
## library, in every state — not just the ones the current animation keys. RESET
## is where it reads the value for the rest, and an EMPTY RESET means those
## properties fall to their type default. That is why the rig went completely
## invisible: die_body fades the root's modulate:a to 0, so with nothing in RESET
## every other state resolved alpha to 0 too. The same gap collapsed every bone
## walk/attack doesn't key onto the origin.
func _rebuild_reset(root: WarriorRig, lib: AnimationLibrary) -> void:
	var paths := {}
	for anim_name in lib.get_animation_list():
		if anim_name == "RESET":
			continue
		var anim := lib.get_animation(anim_name)
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_VALUE:
				paths[anim.track_get_path(i)] = true

	var reset := Animation.new()
	reset.resource_name = "RESET"
	reset.length = 0.001
	for path in paths:
		var parts := String(path).split(":")
		var node := root if parts[0] == "." else root.get_node_or_null(NodePath(parts[0]))
		if not node:
			continue
		var value = _neutral_value(node, parts.slice(1))
		if value == null:
			continue
		var track := reset.add_track(Animation.TYPE_VALUE)
		reset.track_set_path(track, path)
		reset.track_insert_key(track, 0.0, value)
	lib.add_animation("RESET", reset)
	print("  reset: %d neutral tracks" % reset.get_track_count())


## A bone's neutral is its bind pose, the same one pose_rest() shows — not the
## pose the scene happens to be saved mid-animation in. Everything else neutralises
## to whatever the scene authored.
func _neutral_value(node: Node, property: PackedStringArray):
	if node is Bone2D:
		match property[0]:
			"position":
				var origin: Vector2 = node.rest.origin
				if property.size() == 1:
					return origin
				return origin.x if property[1] == "x" else origin.y
			"rotation":
				return node.rest.get_rotation()
			"scale":
				return node.rest.get_scale()
	return node.get_indexed(NodePath(":".join(property)))


func _pascal(snake: String) -> String:
	var out := ""
	for token in snake.split("_", false):
		out += token.substr(0, 1).to_upper() + token.substr(1)
	return out

#endregion


func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)
