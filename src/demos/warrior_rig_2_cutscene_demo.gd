extends Control
## Cutscene test harness for warrior_rig_2 (the new-proportion rig).
##
## Drives GroupPlayback DIRECTLY — no EventChain. The cutscene is a CinematicGroup
## resource attached to the `cutscene` export (a saved .tres). That resource is
## the single source of truth: edit it in the inspector and press R to replay.
## Visuals are dispatched through the existing VnPresenter (the director) →
## StagePresenter (the theater), so no playback or stage logic is reimplemented.
##
## Authoring a cutscene = build a CinematicGroup .tres and attach it here. The
## GroupPlayback engine (src/strategy/ui/vn/group_playback.gd) is driven unmodified.
##
## Controls: SPACE / click = advance gate   R = replay

const RIG_2_SCENE_PATH := "res://scenes/rig/warrior_rig_2.tscn"
const POLL_INTERVAL := 0.4
const SVG_RENDER_SCALE := 4.0

## The CinematicGroup cutscene fed straight into GroupPlayback (no EventChain).
@export var cutscene: CinematicGroup

## Default textured config (rachelle). Used for any character without a per-id
## entry in character_configs — the Duchess and Gretchen reuse this look.
@export var config: WarriorRigConfig

## Per-character look overrides: character_id -> WarriorRigConfig. Lets each
## delegate in the parliament wear a different class look. Missing ids fall back
## to `config`.
@export var character_configs: Dictionary = {}

## Fixed chamber seats: character_id -> Vector2. Characters without an entry are
## auto-spread left→right. Facing is derived from x sign.
@export var seat_positions: Dictionary = {}

## One warrior_rig_2 per id, placed across the chamber facing inward.
@export var character_ids: Array[String] = ["aldric", "rachelle"]

## Static set dressing (backdrop + props) applied at scene setup.
@export var stage_set: StageSet

@onready var vn_view: VnView = $VnView
@onready var stage_view: StageView = $StageView
@onready var status_label: Label = $StatusLabel

var _presenter: VnPresenter
var _stage: StagePresenter
var _playback: GroupPlayback
var _poll_accum: float = 0.0
var _mtimes: Dictionary = {}
var _completed: bool = false
var _rig_configs: Dictionary = {}


func _ready() -> void:
	_presenter = vn_view.presenter
	_stage = stage_view.presenter
	_playback = _presenter._playback
	_presenter.stage_presenter = _stage
	## The presenter normally learns these from an EventChain in load_chain(); we
	## set them directly so its dispatch (_on_instruction_fired) works without one.
	_presenter.character_ids_in_chain = character_ids.duplicate()

	## Take over completion: the presenter's default handler assumes a current_chain.
	if _playback.timeline_complete.is_connected(_presenter._on_timeline_complete):
		_playback.timeline_complete.disconnect(_presenter._on_timeline_complete)
	_playback.timeline_complete.connect(_on_playback_complete)
	_playback.gate_reached.connect(_on_gate_reached)

	print("=== warrior_rig_2 Cutscene Demo (direct GroupPlayback) ===")
	print("SPACE/click: advance gate | R: replay")

	# --- spawn rigs ---
	var scene := load(RIG_2_SCENE_PATH) as PackedScene
	assert(scene != null, "Failed to load %s" % RIG_2_SCENE_PATH)
	for char_id in character_ids:
		var rig := scene.instantiate() as WarriorRig
		rig.setup_default(char_id)
		var cfg: WarriorRigConfig = character_configs.get(char_id, config)
		_rig_configs[char_id] = cfg
		if cfg:
			rig.apply_config(cfg)
		stage_view.warrior_container.add_child(rig)
		stage_view.rigs[char_id] = rig

	_play_cutscene()
	_snapshot_mtimes()

	if DisplayServer.get_name() == "headless":
		# --- headless smoke test ---
		print("=== HEADLESS SMOKE TEST ===")
		var fired: Array[String] = []
		_playback.instruction_fired.connect(func(inst: CinematicInstruction) -> void:
			if inst is DialogueInstruction:
				fired.append("dialogue")
			elif inst is CameraInstruction:
				fired.append("camera")
			elif inst is CharacterInstruction:
				if inst.action == CharacterInstruction.Action.EXPRESSION:
					fired.append("expression:%s" % inst.expression)
				else:
					fired.append("behavior:%s" % inst.behavior)
			elif inst is SceneryInstruction:
				fired.append("scenery:%d" % inst.action)
		)
		assert(not stage_view.props.is_empty(), "Stage set produced no scenery props")
		print("[SmokeTest] scenery props applied: %s" % str(stage_view.props.keys()))
		var start_ms := Time.get_ticks_msec()
		while not _completed and Time.get_ticks_msec() - start_ms < 180000:
			_playback.on_input()
			await get_tree().process_frame
		if _completed:
			print("=== SMOKE TEST PASSED — fired %d instructions: %s ===" % [fired.size(), str(fired)])
			get_tree().quit(0)
		else:
			printerr("=== SMOKE TEST FAILED (state=%d, %dms) ===" % [_playback.state, Time.get_ticks_msec() - start_ms])
			get_tree().quit(1)


func _process(delta: float) -> void:
	if _rig_configs.is_empty():
		return
	_poll_accum += delta
	if _poll_accum < POLL_INTERVAL:
		return
	_poll_accum = 0.0
	if _disk_changed():
		# --- reapply config to rigs ---
		for char_id in _rig_configs:
			var src: WarriorRigConfig = _rig_configs[char_id]
			var rig = stage_view.rigs.get(char_id)
			if not src or not is_instance_valid(rig):
				continue
			# --- rebuild config from disk ---
			var rebuilt: WarriorRigConfig = src.duplicate()
			for bone_name in src.get_bone_textures():
				var tex: Texture2D = src.get_bone_textures()[bone_name]
				var out_tex: Texture2D = tex
				if tex and not tex.resource_path.is_empty():
					var abs_path := ProjectSettings.globalize_path(tex.resource_path)
					if FileAccess.file_exists(abs_path):
						var reloaded := _load_texture_from_disk(abs_path)
						if reloaded:
							out_tex = reloaded
				_set_slot(rebuilt, bone_name, out_tex)
			rig.apply_config(rebuilt)
		stage_view.reload_scenery_textures()
		_snapshot_mtimes()
		Log.info("RigCutsceneDemo", "Rig + scenery textures reloaded from disk")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_playback.on_input()
		return
	match event.keycode:
		KEY_R:
			_play_cutscene()
			_update_status("Replaying")
		KEY_SPACE, KEY_ENTER:
			_playback.on_input()


#region Direct GroupPlayback playback

func _play_cutscene() -> void:
	_completed = false
	_stage.dismiss_all_speech()
	_stage.return_to_wide()
	vn_view.hide_narrator_box()
	_stage.prepare_for_dialogue(character_ids)
	_stage.apply_stage_set(stage_set)
	# --- place characters ---
	var n := character_ids.size()
	for i in n:
		var char_id := character_ids[i]
		var pos: Vector2
		if seat_positions.has(char_id):
			pos = seat_positions[char_id]
		else:
			pos = Vector2(-90.0 + (180.0 * i / maxf(n - 1, 1)), 50.0)
		var face := -1 if pos.x > 0.0 else 1
		_stage.place_character(char_id, pos, face)
	assert(cutscene != null, "No CinematicGroup attached to the `cutscene` export")
	print("[RigCutsceneDemo] Playing group '%s' — %d children" % [cutscene.id, cutscene.children.size()])
	_playback.reset()
	_playback.load_group(cutscene)
	_update_status("Playing cutscene...")


#endregion

#region Status / callbacks

func _on_gate_reached() -> void:
	_update_status("Gate — SPACE/click to advance")


func _on_playback_complete() -> void:
	_completed = true
	_stage.dismiss_all_speech()
	vn_view.hide_narrator_box()
	_update_status("Cutscene complete! Press R to replay")
	print("=== Cutscene complete ===")


func _update_status(text: String) -> void:
	if status_label:
		status_label.text = "%s   [SPACE advance | R replay]" % text

#endregion

#region Rig texture hot-reload

func _disk_changed() -> bool:
	for abs_path in _watched_paths():
		if not FileAccess.file_exists(abs_path):
			continue
		if _mtimes.get(abs_path, -1) != FileAccess.get_modified_time(abs_path):
			return true
	return false


func _watched_paths() -> Array[String]:
	var paths: Array[String] = []
	for src in _rig_configs.values():
		if not src:
			continue
		for tex in src.get_bone_textures().values():
			if tex and not tex.resource_path.is_empty():
				var p := ProjectSettings.globalize_path(tex.resource_path)
				if not paths.has(p):
					paths.append(p)
	for svg_path in stage_view.scenery_svg_paths():
		var sp := ProjectSettings.globalize_path(svg_path)
		if not paths.has(sp):
			paths.append(sp)
	return paths


func _snapshot_mtimes() -> void:
	_mtimes.clear()
	for abs_path in _watched_paths():
		if FileAccess.file_exists(abs_path):
			_mtimes[abs_path] = FileAccess.get_modified_time(abs_path)


func _load_texture_from_disk(abs_path: String) -> Texture2D:
	return SvgLoader.load_svg(abs_path, SVG_RENDER_SCALE)


func _set_slot(cfg: WarriorRigConfig, bone_name: String, tex: Texture2D) -> void:
	match bone_name:
		"Head": cfg.head_texture = tex
		"Torso": cfg.torso_texture = tex
		"Hips": cfg.hips_texture = tex
		"LeftArm": cfg.left_arm_texture = tex
		"LeftForearm": cfg.left_forearm_texture = tex
		"LeftHand": cfg.left_hand_texture = tex
		"RightArm": cfg.right_arm_texture = tex
		"RightForearm": cfg.right_forearm_texture = tex
		"RightHand": cfg.right_hand_texture = tex
		"LeftLeg": cfg.left_leg_texture = tex
		"LeftShin": cfg.left_shin_texture = tex
		"LeftFoot": cfg.left_foot_texture = tex
		"RightLeg": cfg.right_leg_texture = tex
		"RightShin": cfg.right_shin_texture = tex
		"RightFoot": cfg.right_foot_texture = tex

#endregion
