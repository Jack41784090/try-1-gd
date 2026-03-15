class_name StageView
extends Control

const BUBBLE_OFFSET_Y: float = 40.0
const MARCH_Y_BASE: float = 50.0
const MARCH_SPACING_X: float = 80.0
const MARCH_SPEED: float = 60.0

@onready var background_image: TextureRect = $BackgroundImage
@onready var stage_viewport: SubViewport = $StageContainer/StageViewport
@onready var stage_camera: StageCamera = $StageContainer/StageViewport/StageCamera
@onready var warrior_container: Node2D = $StageContainer/StageViewport/WarriorContainer
@onready var bubble_layer: Control = $BubbleLayer
@onready var presenter: StagePresenter = $StagePresenter

var rigs: Dictionary = { }
var bubbles: Array[SpeechBubble] = []
var _is_marching: bool = false


func _ready() -> void:
	presenter.bind_view(self)


func _process(delta: float) -> void:
	if _is_marching:
		_update_march(delta)
	_update_bubble_positions()


func spawn_warriors(warriors: Array[CharacterSocialStats]) -> void:
	clear_warriors()
	for i in warriors.size():
		var warrior = warriors[i]
		if warrior.is_dead:
			continue
		var rig = await WarriorRigFactory.create_rig_for_warrior(warrior)
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
	background_image.texture = texture
	background_image.visible = texture != null


func start_march() -> void:
	_is_marching = true
	stage_camera.reset_to_wide(0.3)
	set_all_behavior(AnimTypes.Behavior.WALKING)


func stop_march() -> void:
	_is_marching = false
	set_all_behavior(AnimTypes.Behavior.IDLE)


func set_march_positions(warriors: Array[CharacterSocialStats]) -> void:
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

#region Speech Bubbles

func show_bubble(character_id: String, speaker_name: String, text: String) -> SpeechBubble:
	var bubble_scene = load("res://scenes/speech_bubble.tscn") as PackedScene
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
	var vp_size = stage_viewport.size if stage_viewport else Vector2(800, 600)
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
