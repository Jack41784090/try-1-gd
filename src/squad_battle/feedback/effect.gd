class_name FeedbackEffect
extends Resource

const FLOAT_TEXT_SCENE := preload("res://scenes/feedback/floating_text.tscn")
const FLOAT_TEXT_RISE: float = 40.0
const FLOAT_TEXT_LIFETIME: float = 0.9

enum Role { SOURCE, TARGET }

var _host: BattleEntityDisplay


func setup(host: BattleEntityDisplay) -> void:
	_host = host
	host.change_received.connect(_on_change)


func _on_change(update: EntityUpdate, role: int) -> void:
	if wants(update.change, role):
		play(update, role)


func wants(_change: EntityChange, _role: int) -> bool:
	return false


func play(_update: EntityUpdate, _role: int) -> void:
	pass


static func spawn_floating_text(host: Node2D, rig: WarriorRig, text: String,
		color: Color, font_size: int = 18) -> void:
	var label: Label = FLOAT_TEXT_SCENE.instantiate()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

	var head_pos := Vector2(0, -100)
	if rig:
		head_pos = rig.get_head_position() - rig.global_position
	label.position = Vector2(head_pos.x + randf_range(-8.0, 8.0), head_pos.y - 30.0)
	host.add_child(label)

	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - FLOAT_TEXT_RISE, FLOAT_TEXT_LIFETIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TEXT_LIFETIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)
