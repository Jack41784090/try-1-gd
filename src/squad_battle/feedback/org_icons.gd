class_name OrgIconsFeedback
extends FeedbackEffect

const ORG_ICON_SCENE := preload("res://scenes/feedback/org_icon.tscn")
const ICON_SPACING: float = 10.0
const ICON_SIZE: float = 6.0
const MAX_DISPLAY: int = 10

var _container: Node2D
var _icons: Array[ColorRect] = []
var _current_count: int = 0


func setup(host: BattleEntityDisplay) -> void:
	super.setup(host)
	var head_pos := Vector2(0, -100)
	if _host.rig:
		head_pos = _host.rig.get_head_position() - _host.rig.global_position

	_container = Node2D.new()
	_container.position = Vector2(0, head_pos.y - 10.0 - ICON_SIZE - 4.0)
	_host.add_child(_container)

	refresh()


func refresh() -> void:
	if not _host.squad_entity:
		return
	var org := _host.squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
	var count := mini(ceili(org), MAX_DISPLAY)
	_current_count = count
	_rebuild(count)


func wants(change: EntityChange, role: int) -> bool:
	return role == Role.TARGET and change.property == SquadBattleTypes.EntityChangeable.ORG


func play(update: EntityUpdate, _role: int) -> void:
	var change := update.change
	var old_count := mini(ceili(change.from), MAX_DISPLAY)
	var new_count := mini(ceili(change.to), MAX_DISPLAY)

	if new_count >= old_count:
		_rebuild(new_count)
		_current_count = new_count
		return

	var icons_to_remove := old_count - new_count
	var tween := _host.create_tween()
	for i in range(icons_to_remove):
		var idx := _icons.size() - 1 - i
		if idx >= 0 and idx < _icons.size():
			var icon := _icons[idx]
			if is_instance_valid(icon):
				tween.set_parallel(true)
				tween.tween_property(icon, "modulate:a", 0.0, 0.3)
				tween.tween_property(icon, "scale", Vector2(0.3, 0.3), 0.3)

	tween.chain().tween_callback(func():
		_rebuild(new_count)
		_current_count = new_count
	)


func _rebuild(count: int) -> void:
	for icon in _icons:
		if is_instance_valid(icon):
			icon.queue_free()
	_icons.clear()

	if not _container:
		return
	var total_width := (count - 1) * ICON_SPACING
	var start_x := -total_width / 2.0

	for i in range(count):
		var icon: ColorRect = ORG_ICON_SCENE.instantiate()
		icon.position = Vector2(start_x + i * ICON_SPACING - ICON_SIZE / 2.0, -ICON_SIZE / 2.0)
		_container.add_child(icon)
		_icons.append(icon)
