class_name StageView
extends Control

const BUBBLE_OFFSET_Y: float = 40.0
const MARCH_Y_BASE: float = 50.0
const MARCH_SPACING_X: float = 80.0
const MARCH_SPEED: float = 60.0

const BACKDROP_PROP_ID: String = "__backdrop__"

@onready var background_image: TextureRect = get_node_or_null("BackgroundImage")
@onready var stage_viewport: SubViewport = $StageContainer/StageViewport
@onready var stage_camera: StageCamera = $StageContainer/StageViewport/StageCamera
@onready var warrior_container: Node2D = $StageContainer/StageViewport/WarriorContainer
@onready var bubble_layer: Control = $BubbleLayer
@onready var presenter: StagePresenter = $StagePresenter

var rigs: Dictionary = {}
var bubbles: Array[SpeechBubble] = []
var props: Dictionary = {}
var scenery_layer: Node2D
var _is_marching: bool = false


func _ready() -> void:
	presenter.bind_view(self )
	_ensure_scenery_layer()


func _process(delta: float) -> void:
	if _is_marching:
		_update_march(delta)
	_update_bubble_positions()
	_update_parallax()


func spawn_warriors(warriors: Array[StrategyEntity]) -> void:
	clear_warriors()
	for i in warriors.size():
		var warrior = warriors[i]
		if warrior.is_dead:
			continue
		var rig = WarriorRigFactory.create_rig_for_warrior(warrior)
		warrior_container.add_child(rig)
		rig.position = Vector2(i * MARCH_SPACING_X - (warriors.size() * MARCH_SPACING_X * 0.5), MARCH_Y_BASE + (i % 2) * 15.0)
		rigs[warrior.id] = rig


func get_rig(character_id: String) -> WarriorRig:
	return rigs.get(character_id) as WarriorRig


func clear_warriors() -> void:
	for rig in rigs.values():
		if is_instance_valid(rig):
			rig.queue_free()
	rigs.clear()


func set_all_behavior(behavior: AnimTypes.Behavior) -> void:
	for rig in rigs.values():
		if is_instance_valid(rig):
			rig.play_behavior(behavior)


func reset_talking_to_idle() -> void:
	for rig in rigs.values():
		if is_instance_valid(rig) and rig.anim_controller.current_behavior == AnimTypes.Behavior.TALKING:
			rig.play_behavior(AnimTypes.Behavior.IDLE)


func set_background(texture: Texture2D) -> void:
	if not background_image:
		return
	background_image.texture = texture
	background_image.visible = texture != null


func start_march() -> void:
	_is_marching = true
	stage_camera.reset_to_wide(0.3)
	set_all_behavior(AnimTypes.Behavior.WALKING)


func stop_march() -> void:
	_is_marching = false
	set_all_behavior(AnimTypes.Behavior.IDLE)


func set_march_positions(warriors: Array[StrategyEntity]) -> void:
	var width = _get_stage_width()
	var spacing = width / maxf(warriors.size(), 1)
	for i in warriors.size():
		var warrior = warriors[i]
		var rig = rigs.get(warrior.id) as WarriorRig
		if rig and is_instance_valid(rig):
			rig.position = Vector2(
				i * spacing - (warriors.size() * spacing * 0.5),
				MARCH_Y_BASE + (i % 2) * 15.0,
			)


func _get_stage_width() -> float:
	if stage_viewport:
		return float(stage_viewport.size.x)
	return 800.0


func _update_march(delta: float) -> void:
	var width = _get_stage_width()
	for rig in rigs.values():
		if not is_instance_valid(rig):
			continue
		if rig.anim_controller.current_behavior != AnimTypes.Behavior.WALKING:
			rig.play_behavior(AnimTypes.Behavior.WALKING)
		rig.position.x += MARCH_SPEED * delta
		if rig.position.x > width * 0.5:
			rig.position.x -= width

#region Scenery (backdrops + props)

func _ensure_scenery_layer() -> void:
	scenery_layer = stage_viewport.get_node_or_null("Scenery") as Node2D
	if not scenery_layer:
		scenery_layer = Node2D.new()
		scenery_layer.name = "Scenery"
		stage_viewport.add_child(scenery_layer)
	# Draw scenery before the rigs so props sit behind characters by default
	# (per-prop z_index can still override).
	stage_viewport.move_child(scenery_layer, 0)


func apply_stage_set(stage_set: StageSet) -> void:
	clear_scenery()
	if not stage_set:
		return
	if not stage_set.backdrop_svg_path.is_empty():
		set_backdrop(
			stage_set.backdrop_svg_path,
			stage_set.backdrop_position,
			stage_set.backdrop_scale,
			stage_set.backdrop_z,
			stage_set.backdrop_parallax,
			stage_set.backdrop_svg_scale,
		)
	for prop in stage_set.props:
		add_prop(prop)


func clear_scenery() -> void:
	if scenery_layer:
		for child in scenery_layer.get_children():
			child.queue_free()
	props.clear()


func add_prop(prop: StageProp) -> Sprite2D:
	if not prop or prop.prop_id.is_empty():
		return null
	var spr := _build_sprite(prop.prop_id, prop.svg_path, prop.svg_scale)
	spr.position = prop.position
	spr.scale = Vector2(prop.scale, prop.scale)
	spr.z_index = prop.z_index
	spr.flip_h = prop.flip_h
	spr.modulate = prop.modulate
	spr.set_meta("parallax", prop.parallax)
	spr.set_meta("base_position", prop.position)
	return spr


func remove_prop(prop_id: String) -> void:
	var spr = props.get(prop_id)
	if spr and is_instance_valid(spr):
		spr.queue_free()
	props.erase(prop_id)


func move_prop(prop_id: String, target: Vector2, duration: float) -> void:
	var spr = props.get(prop_id)
	if not spr or not is_instance_valid(spr):
		return
	spr.set_meta("base_position", target)
	if duration <= 0.0:
		spr.position = target
		return
	var tween := create_tween()
	tween.tween_property(spr, "position", target, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)


func modulate_prop(prop_id: String, color: Color, duration: float) -> void:
	var spr = props.get(prop_id)
	if not spr or not is_instance_valid(spr):
		return
	if duration <= 0.0:
		spr.modulate = color
		return
	var tween := create_tween()
	tween.tween_property(spr, "modulate", color, duration)


func set_prop_visible(prop_id: String, is_visible: bool) -> void:
	var spr = props.get(prop_id)
	if spr and is_instance_valid(spr):
		spr.visible = is_visible


func set_backdrop(svg_path: String, position: Vector2, scale: float, z: int, parallax: float, svg_scale: float = 4.0) -> void:
	remove_prop(BACKDROP_PROP_ID)
	var spr := _build_sprite(BACKDROP_PROP_ID, svg_path, svg_scale)
	spr.position = position
	spr.scale = Vector2(scale, scale)
	spr.z_index = z
	spr.set_meta("parallax", parallax)
	spr.set_meta("base_position", position)


func reload_scenery_textures() -> void:
	# Re-rasterizes each prop's SVG from disk (used by editor hot-reload).
	for spr in props.values():
		if not is_instance_valid(spr):
			continue
		var svg_path: String = spr.get_meta("svg_path", "")
		var svg_scale: float = spr.get_meta("svg_scale", 4.0)
		if svg_path.is_empty():
			continue
		var tex := SvgLoader.load_svg(svg_path, svg_scale)
		if tex:
			spr.texture = tex


func scenery_svg_paths() -> Array[String]:
	var paths: Array[String] = []
	for spr in props.values():
		if not is_instance_valid(spr):
			continue
		var svg_path: String = spr.get_meta("svg_path", "")
		if not svg_path.is_empty():
			paths.append(svg_path)
	return paths


func _build_sprite(prop_id: String, svg_path: String, svg_scale: float) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.name = prop_id
	var tex := SvgLoader.load_svg(svg_path, svg_scale)
	if tex:
		spr.texture = tex
	spr.set_meta("svg_path", svg_path)
	spr.set_meta("svg_scale", svg_scale)
	scenery_layer.add_child(spr)
	props[prop_id] = spr
	return spr


func _update_parallax() -> void:
	if not scenery_layer:
		return
	var cam_pos := stage_camera.global_position
	for spr in scenery_layer.get_children():
		var p: float = spr.get_meta("parallax", 1.0)
		if p >= 1.0:
			continue
		var base: Vector2 = spr.get_meta("base_position", spr.position)
		spr.position = base + cam_pos * (1.0 - p)

#endregion

#region Speech Bubbles

func show_bubble(character_id: String, speaker_name: String, text: String) -> SpeechBubble:
	var bubble_scene = load("res://scenes/stage/speech_bubble.tscn") as PackedScene
	var bubble = bubble_scene.instantiate() as SpeechBubble
	bubble_layer.add_child(bubble)
	bubble.setup(character_id, speaker_name, text)
	bubbles.append(bubble)
	bubble.appear()
	return bubble


func dismiss_bubble(bubble: SpeechBubble) -> void:
	if bubble and is_instance_valid(bubble):
		bubbles.erase(bubble)
		bubble.dismiss()


func dismiss_all_bubbles() -> void:
	for bubble in bubbles:
		if is_instance_valid(bubble):
			bubble.dismiss()
	bubbles.clear()


func _update_bubble_positions() -> void:
	var vp_size: Vector2 = Vector2(stage_viewport.size) if stage_viewport else Vector2(800, 600)
	var margin := 8.0
	for bubble in bubbles:
		if not is_instance_valid(bubble):
			continue
		var rig = rigs.get(bubble.target_character_id)
		if not rig or not is_instance_valid(rig):
			continue
		var head_world = rig.get_head_position()
		var screen_pos = stage_camera.get_screen_position(head_world)
		var target = screen_pos + Vector2(0, -BUBBLE_OFFSET_Y)
		var bw = bubble.size.x
		var bh = bubble.size.y
		target.x = clampf(target.x, margin + bw * 0.5, vp_size.x - margin - bw * 0.5)
		target.y = clampf(target.y, margin + bh, vp_size.y - margin)
		bubble.set_screen_position(target)

#endregion

#region Camera Delegation

func focus_camera_on(character_id: String, zoom_val: float, duration: float) -> void:
	var rig = rigs.get(character_id) as WarriorRig
	if rig and is_instance_valid(rig):
		stage_camera.focus_on(rig.global_position, zoom_val, duration)


func focus_camera_between(character_ids: Array[String], duration: float) -> void:
	var positions: Array[Vector2] = []
	for cid in character_ids:
		var rig = rigs.get(cid) as WarriorRig
		if rig and is_instance_valid(rig):
			positions.append(rig.global_position)
	if not positions.is_empty():
		stage_camera.focus_between(positions, 100.0, duration)


func set_camera_include(character_ids: Array[String], duration: float = 0.4) -> void:
	var lookup := func(id: String) -> WarriorRig:
		return rigs.get(id) as WarriorRig
	stage_camera.set_include_targets(character_ids, lookup, duration)


func move_camera(offset: Vector2, duration: float) -> void:
	stage_camera.move_by(offset, duration)


func zoom_camera(zoom_level: float, duration: float) -> void:
	stage_camera.zoom_to(zoom_level, duration)


func reset_camera(duration: float) -> void:
	stage_camera.reset_to_wide(duration)

#endregion

#region Anchor Resolution

func resolve_anchor(anchor: CharacterInstruction.StageAnchor) -> Vector2:
	var width = _get_stage_width()
	var half_w = width * 0.5
	match anchor:
		CharacterInstruction.StageAnchor.OFFSCREEN_LEFT:
			return Vector2(-half_w - 100.0, MARCH_Y_BASE)
		CharacterInstruction.StageAnchor.OFFSCREEN_RIGHT:
			return Vector2(half_w + 100.0, MARCH_Y_BASE)
		CharacterInstruction.StageAnchor.OFFSCREEN_TOP:
			return Vector2(0.0, -200.0)
		CharacterInstruction.StageAnchor.OFFSCREEN_BOTTOM:
			return Vector2(0.0, 300.0)
		CharacterInstruction.StageAnchor.CENTER:
			return Vector2(0.0, MARCH_Y_BASE)
		CharacterInstruction.StageAnchor.LEFT_QUARTER:
			return Vector2(-half_w * 0.5, MARCH_Y_BASE)
		CharacterInstruction.StageAnchor.RIGHT_QUARTER:
			return Vector2(half_w * 0.5, MARCH_Y_BASE)
		_:
			return Vector2(0.0, MARCH_Y_BASE)

#endregion
