@tool
extends SceneTree

## Authors the procedural (non-texture-swap) FaceReactions onto warrior_rig_2's
## Face components — the same thing you'd do by hand in the Inspector, written
## down so it survives and can be re-tuned by editing numbers instead of clicking.
##
## The per-emotion texture swaps (blink, wide) are generated from the artwork by
## bake_rig_scene.gd and are NOT touched here; these are the intents the artwork
## has no variant for, which move parts rather than redraw them. bake_rig_scene
## carries them across a rebake, so run this once after adding an intent:
##   godot --headless --path . --script res://tools/author_face_reactions.gd
##
## Deltas are in the Face's 200-unit canvas space (the head renders at 50px), and
## rotation is radians clockwise. Every one is measured from the baked pose, so
## the numbers read as "how far from neutral", never as absolute placement.

const SCENE_PATH := "res://scenes/rig/warrior_rig_2.tscn"

# node path under Face -> intent -> {position, rotation, scale, blend}
const REACTIONS := {
	"Eyes/EyeL/White": {
		"scared": {"scale": Vector2(1.12, 1.28), "blend": 0.12},
	},
	"Eyes/EyeR/White": {
		"scared": {"scale": Vector2(1.12, 1.28), "blend": 0.12},
	},
	"Eyes/EyeL/White/Pupil": {
		"scared": {"scale": Vector2(0.6, 0.6), "blend": 0.12},
		"angry": {"scale": Vector2(0.82, 0.82), "blend": 0.15},
	},
	"Eyes/EyeR/White/Pupil": {
		"scared": {"scale": Vector2(0.6, 0.6), "blend": 0.12},
		"angry": {"scale": Vector2(0.82, 0.82), "blend": 0.15},
	},
	# Inner ends down for angry, both brows lifted for scared. The near brow's
	# inner end is its right one, the far brow's its left, so they tilt opposite.
	"Brows/BrowL": {
		"scared": {"position": Vector2(0, -7), "rotation": -0.06, "blend": 0.12},
		"angry": {"position": Vector2(0, 3), "rotation": 0.2, "blend": 0.15},
	},
	"Brows/BrowR": {
		"scared": {"position": Vector2(0, -7), "rotation": 0.06, "blend": 0.12},
		"angry": {"position": Vector2(0, 3), "rotation": -0.2, "blend": 0.15},
	},
}


func _initialize() -> void:
	var ok := _author()
	if not ok:
		push_error("[author_face_reactions] FAILED")
	quit(0 if ok else 1)


func _author() -> bool:
	var packed := load(SCENE_PATH) as PackedScene
	if not packed:
		push_error("Could not load scene: " + SCENE_PATH)
		return false
	var root := packed.instantiate() as WarriorRig
	var face := root.find_child("Face", true, false) as Face
	if not face:
		push_error("No Face node in " + SCENE_PATH)
		return false

	for node_path in REACTIONS:
		var component := face.get_node_or_null(NodePath(node_path)) as FaceComponent
		if not component:
			push_error("No FaceComponent at Face/%s" % node_path)
			return false
		var authored: Array[FaceReaction] = []
		var intents: Dictionary = REACTIONS[node_path]
		for reaction in component.reactions:
			# Regenerate ours; leave the artwork's texture swaps alone.
			if reaction and not intents.has(String(reaction.intent)):
				authored.append(reaction)
		for intent in intents:
			var spec: Dictionary = intents[intent]
			var reaction := FaceReaction.new()
			reaction.intent = StringName(intent)
			reaction.position_delta = spec.get("position", Vector2.ZERO)
			reaction.rotation_delta = spec.get("rotation", 0.0)
			reaction.scale_delta = spec.get("scale", Vector2.ONE)
			reaction.blend_time = spec.get("blend", 0.0)
			authored.append(reaction)
		component.reactions = authored
		print("  %s: %d reactions" % [node_path, authored.size()])

	var out := PackedScene.new()
	var err := out.pack(root)
	if err != OK:
		push_error("PackedScene.pack failed: %d" % err)
		return false
	err = ResourceSaver.save(out, SCENE_PATH)
	if err != OK:
		push_error("ResourceSaver.save failed: %d" % err)
		return false
	print("[author_face_reactions] Authored into %s" % SCENE_PATH)
	return true
