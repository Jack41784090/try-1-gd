class_name HpBarFeedback
extends FeedbackEffect

const HP_BAR_SCENE := preload("res://scenes/feedback/hp_bar.tscn")
const BAR_WIDTH: float = 60.0
const BAR_OFFSET_Y: float = -10.0

var _bg: ColorRect
var _fill: ColorRect


func setup(host: BattleEntityDisplay) -> void:
	super.setup(host)
	var head_pos := Vector2(0, -100)
	if _host.rig:
		head_pos = _host.rig.get_head_position() - _host.rig.global_position

	var bar := HP_BAR_SCENE.instantiate()
	bar.position = Vector2(0, head_pos.y + BAR_OFFSET_Y)
	_host.add_child(bar)

	_bg = bar.get_node("Bg")
	_fill = bar.get_node("Fill")

	refresh()


func refresh() -> void:
	if not _host.squad_entity or not _fill:
		return
	var hp := _host.squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var max_hp := _host.squad_entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	var ratio := clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0 else 0.0
	_fill.size.x = BAR_WIDTH * ratio
	_update_color(ratio)


func wants(change: EntityChange, role: int) -> bool:
	return role == Role.TARGET and change.property == SquadBattleTypes.EntityChangeable.HP


func play(update: EntityUpdate, _role: int) -> void:
	var change := update.change
	var max_hp := _host.squad_entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	if max_hp <= 0:
		return

	var new_ratio := clampf(change.to / max_hp, 0.0, 1.0)
	var delta := change.to - change.from

	if delta < 0:
		FeedbackEffect.spawn_floating_text(_host, _host.rig, str(int(abs(delta))), Color(1.0, 0.3, 0.2), 20)
	elif delta > 0:
		FeedbackEffect.spawn_floating_text(_host, _host.rig, "+" + str(int(delta)), Color(0.3, 1.0, 0.4), 16)

	var tween := _host.create_tween()
	tween.tween_property(_fill, "size:x", BAR_WIDTH * new_ratio, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _host.rig:
		var flash := Color(1.5, 0.5, 0.5) if delta < 0 else Color(0.5, 1.5, 0.5)
		_host.rig.modulate = flash
		tween.parallel().tween_property(_host.rig, "modulate", Color.WHITE, 0.2)

	tween.tween_callback(func(): _update_color(new_ratio))


func _update_color(ratio: float) -> void:
	if not _fill:
		return
	if ratio > 0.6:
		_fill.color = Color(0.2, 0.85, 0.3, 1.0)
	elif ratio > 0.3:
		_fill.color = Color(0.95, 0.75, 0.2, 1.0)
	else:
		_fill.color = Color(0.9, 0.2, 0.2, 1.0)
