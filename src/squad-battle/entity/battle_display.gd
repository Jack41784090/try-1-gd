extends Node2D
class_name BattleEntityDisplay

signal animation_completed

var squad_entity: CombatEntity
var rig: WarriorRig

const HP_BAR_WIDTH: float = 60.0
const HP_BAR_HEIGHT: float = 6.0
const HP_BAR_OFFSET_Y: float = -10.0
const ORG_ICON_SPACING: float = 10.0
const ORG_ICON_SIZE: float = 6.0
const ORG_MAX_DISPLAY: int = 10

var _hp_bar_bg: ColorRect
var _hp_bar_fill: ColorRect
var _org_container: Node2D
var _org_icons: Array[ColorRect] = []
var _current_org_display: int = 0
var _debug_id: String = ""


func setup(entity: CombatEntity) -> void:
	squad_entity = entity
	_debug_id = "[BattleDisplay:%s[%d]]" % [entity.entity_name, entity.player_id]

	rig = WarriorRigFactory.create_rig_for_entity(null, str(entity.player_id))
	add_child(rig)
	rig.position = Vector2.ZERO

	_build_stat_bars()
	_initialize_hp_bar()
	_initialize_org_icons()
	rig.play_behavior(AnimTypes.Behavior.IDLE)


func refresh_display() -> void:
	if not squad_entity:
		return
	_update_hp_bar_display()
	_update_org_display()


func update_stat(property: SquadBattleTypes.EntityChangeable,
		old_val: float, new_val: float) -> void:
	if not squad_entity:
		return
	match property:
		SquadBattleTypes.EntityChangeable.HP:
			_handle_hp_change(old_val, new_val)
		SquadBattleTypes.EntityChangeable.STA:
			_handle_sta_change(old_val, new_val)
		SquadBattleTypes.EntityChangeable.ORG:
			_handle_org_change(old_val, new_val)
		SquadBattleTypes.EntityChangeable.POS:
			animation_completed.emit.call_deferred()
		SquadBattleTypes.EntityChangeable.MAG:
			animation_completed.emit.call_deferred()
		SquadBattleTypes.EntityChangeable.LOC:
			animation_completed.emit.call_deferred()
		SquadBattleTypes.EntityChangeable.DIE:
			_handle_death()
		SquadBattleTypes.EntityChangeable.CAPITULATE:
			_handle_capitulate()
		SquadBattleTypes.EntityChangeable.CLINK:
			_handle_clink()
		SquadBattleTypes.EntityChangeable.DODGE:
			_handle_dodge()
		SquadBattleTypes.EntityChangeable.PROC:
			_handle_proc()


func play_behavior(behavior: AnimTypes.Behavior) -> void:
	if rig:
		rig.play_behavior(behavior)


func _build_stat_bars() -> void:
	var head_pos := Vector2(0, -100)
	if rig:
		head_pos = rig.get_head_position() - rig.global_position

	var bar_y := head_pos.y + HP_BAR_OFFSET_Y

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_bg.position = Vector2(-HP_BAR_WIDTH / 2.0, bar_y)
	_hp_bar_bg.color = Color(0.15, 0.15, 0.15, 0.9)
	add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_fill.position = Vector2(-HP_BAR_WIDTH / 2.0, bar_y)
	_hp_bar_fill.color = Color(0.2, 0.85, 0.3, 1.0)
	add_child(_hp_bar_fill)

	_org_container = Node2D.new()
	_org_container.position = Vector2(0, bar_y - ORG_ICON_SIZE - 4.0)
	add_child(_org_container)


func _initialize_hp_bar() -> void:
	if squad_entity:
		_update_hp_bar_display()


func _update_hp_bar_display() -> void:
	if not squad_entity or not _hp_bar_fill:
		return
	# DISABLED: get_ceiling_changeable_stat is commented out during the CombatEntity
	# stat-system rewrite, so the HP ratio cannot be computed. Skipping bar update.
	return
	# var hp := squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	# var max_hp := squad_entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	# var hp_ratio := clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0 else 0.0
	# _hp_bar_fill.size.x = HP_BAR_WIDTH * hp_ratio
	# _update_hp_bar_color(hp_ratio)


func _update_hp_bar_color(hp_ratio: float) -> void:
	if not _hp_bar_fill:
		return
	if hp_ratio > 0.6:
		_hp_bar_fill.color = Color(0.2, 0.85, 0.3, 1.0)
	elif hp_ratio > 0.3:
		_hp_bar_fill.color = Color(0.95, 0.75, 0.2, 1.0)
	else:
		_hp_bar_fill.color = Color(0.9, 0.2, 0.2, 1.0)


func _initialize_org_icons() -> void:
	if not squad_entity:
		return
	var org := squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
	var org_count := mini(ceili(org), ORG_MAX_DISPLAY)
	_current_org_display = org_count
	_create_org_icons(org_count)


func _create_org_icons(count: int) -> void:
	if not _org_container:
		return
	var total_width := (count - 1) * ORG_ICON_SPACING
	var start_x := -total_width / 2.0

	for i in range(count):
		var icon := ColorRect.new()
		icon.size = Vector2(ORG_ICON_SIZE, ORG_ICON_SIZE)
		icon.color = Color(1.0, 0.85, 0.2, 1.0)
		icon.position = Vector2(start_x + i * ORG_ICON_SPACING - ORG_ICON_SIZE / 2.0, -ORG_ICON_SIZE / 2.0)
		_org_container.add_child(icon)
		_org_icons.append(icon)


func _update_org_display() -> void:
	if not squad_entity:
		return
	var org := squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
	var new_count := mini(ceili(org), ORG_MAX_DISPLAY)
	if new_count != _current_org_display:
		_rebuild_org_icons(new_count)


func _rebuild_org_icons(new_count: int) -> void:
	for icon in _org_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	_org_icons.clear()
	_current_org_display = new_count
	_create_org_icons(new_count)


#region Change handlers

func _handle_hp_change(_old_val: float, _new_val: float) -> void:
	# DISABLED: get_ceiling_changeable_stat is commented out during the CombatEntity
	# stat-system rewrite, so the HP ratio cannot be computed. Emit completion so the
	# animation pipeline keeps flowing.
	animation_completed.emit.call_deferred()
	# var max_hp := squad_entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	# if max_hp <= 0:
	# 	animation_completed.emit.call_deferred()
	# 	return
	#
	# var new_ratio := clampf(_new_val / max_hp, 0.0, 1.0)
	# var target_width := HP_BAR_WIDTH * new_ratio
	# var change := _new_val - _old_val
	#
	# var tween := create_tween()
	# tween.set_parallel(true)
	# tween.tween_property(_hp_bar_fill, "size:x", target_width, 0.3) \
	# 	.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	#
	# if rig:
	# 	var flash_color := Color(1.5, 0.5, 0.5) if change < 0 else Color(0.5, 1.5, 0.5)
	# 	rig.modulate = flash_color
	# 	tween.tween_property(rig, "modulate", Color.WHITE, 0.2)
	#
	# var completion := {"bar": false, "jump": false}
	# tween.finished.connect(func():
	# 	completion["bar"] = true
	# 	_update_hp_bar_color(new_ratio)
	# 	if completion["jump"]:
	# 		animation_completed.emit()
	# , CONNECT_ONE_SHOT)
	#
	# if rig:
	# 	var jump_tween := create_tween()
	# 	jump_tween.tween_property(rig, "scale", Vector2(1.2, 1.2), 0.1)
	# 	jump_tween.tween_property(rig, "scale", Vector2(1.0, 1.0), 0.1)
	# 	jump_tween.finished.connect(func():
	# 		completion["jump"] = true
	# 		if completion["bar"]:
	# 			animation_completed.emit()
	# 	, CONNECT_ONE_SHOT)
	# else:
	# 	completion["jump"] = true


func _handle_sta_change(_old_val: float, _new_val: float) -> void:
	animation_completed.emit.call_deferred()


func _handle_org_change(old_val: float, new_val: float) -> void:
	var old_count := mini(ceili(old_val), ORG_MAX_DISPLAY)
	var new_count := mini(ceili(new_val), ORG_MAX_DISPLAY)

	if new_count >= old_count:
		_rebuild_org_icons(new_count)
		animation_completed.emit.call_deferred()
		return

	var icons_to_remove := old_count - new_count
	var tween := create_tween()
	for i in range(icons_to_remove):
		var icon_index := _org_icons.size() - 1 - i
		if icon_index >= 0 and icon_index < _org_icons.size():
			var icon := _org_icons[icon_index]
			if is_instance_valid(icon):
				tween.set_parallel(true)
				tween.tween_property(icon, "modulate:a", 0.0, 0.3)
				tween.tween_property(icon, "scale", Vector2(0.3, 0.3), 0.3)

	tween.chain().tween_callback(func():
		_rebuild_org_icons(new_count)
	)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)


func _handle_death() -> void:
	if rig:
		rig.play_behavior(AnimTypes.Behavior.DYING)
	var tween := create_tween()
	tween.tween_property(self , "modulate:a", 0.0, 0.5)
	tween.tween_property(self , "scale", Vector2(0.5, 0.5), 0.5)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)


func _handle_capitulate() -> void:
	modulate = Color(0.5, 0.5, 0.5, 0.5)
	animation_completed.emit.call_deferred()


func _handle_clink() -> void:
	if rig:
		rig.modulate = Color.WHITE * 1.5
		var tween := create_tween()
		tween.tween_property(rig, "modulate", Color.WHITE, 0.1)
		tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)
	else:
		animation_completed.emit.call_deferred()


func _handle_dodge() -> void:
	var tween := create_tween()
	tween.tween_property(self , "position:y", position.y - 15.0, 0.1)
	tween.tween_property(self , "position:y", position.y, 0.1)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)


func _handle_proc() -> void:
	if rig:
		var original: Color = rig.modulate
		var tween := create_tween()
		tween.tween_property(rig, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tween.tween_property(rig, "modulate", original, 0.1)
		tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)
	else:
		animation_completed.emit.call_deferred()

#endregion
