class_name BattlefieldView2D
extends Control

const UNIT_Y_SPACING: float = 120.0
const MOVE_ANIMATION_DURATION: float = 0.5
const RETURN_ANIMATION_DURATION: float = 0.4
const META_ORIGINAL_POSITION: String = "original_position"

@onready var attacker_front: Node2D = $BattleViewportContainer/BattleViewport/BattleArena/AttackerSide/FrontRow
@onready var attacker_middle: Node2D = $BattleViewportContainer/BattleViewport/BattleArena/AttackerSide/MiddleRow
@onready var attacker_back: Node2D = $BattleViewportContainer/BattleViewport/BattleArena/AttackerSide/BackRow
@onready var defender_front: Node2D = $BattleViewportContainer/BattleViewport/BattleArena/DefenderSide/FrontRow
@onready var defender_middle: Node2D = $BattleViewportContainer/BattleViewport/BattleArena/DefenderSide/MiddleRow
@onready var defender_back: Node2D = $BattleViewportContainer/BattleViewport/BattleArena/DefenderSide/BackRow


func add_unit_to_row(row_node: Node2D, unit_index: int,
		unit_name: String, entity: CombatEntity) -> Node2D:
	var display = BattleEntityDisplay.new()
	display.name = "%s_%d" % [unit_name, unit_index]
	row_node.add_child(display)
	display.setup(entity)

	var row_parent := row_node.get_parent()
	var is_attacker := row_parent and row_parent.name == "AttackerSide"
	if not is_attacker and display.rig:
		display.rig.scale.x = -1
	display.refresh_display()

	display.set_meta(META_ORIGINAL_POSITION, display.position)
	return display


func update_row_positions(row_node: Node2D, animate: bool = false) -> void:
	var opposing_row := _get_opposing_row(row_node)
	var positions := _calculate_unit_positions(row_node, opposing_row)
	var children = row_node.get_children()

	for i in range(children.size()):
		var child = children[i]
		if child is BattleEntityDisplay and i < positions.size():
			var target_pos = Vector2(0, positions[i])
			if animate and is_instance_valid(child):
				var tween := create_tween()
				tween.tween_property(child, "position", target_pos,
					MOVE_ANIMATION_DURATION * 0.6) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			else:
				child.position = target_pos
			child.set_meta(META_ORIGINAL_POSITION, target_pos)


func _calculate_unit_positions(row_node: Node2D, opposing_row: Node2D) -> Array[float]:
	var our_count = row_node.get_child_count()
	var their_count = opposing_row.get_child_count() if opposing_row else our_count
	if our_count == 0:
		return []

	var max_count = max(our_count, their_count)
	var total_spread = float((max_count - 1)) * UNIT_Y_SPACING
	var positions: Array[float] = []

	for i in range(our_count):
		var normalized = float(i) / float(max(1, our_count - 1)) if our_count > 1 else 0.5
		positions.append((normalized * total_spread) - (total_spread / 2.0))
	return positions


func _get_opposing_row(row_node: Node2D) -> Node2D:
	var parent := row_node.get_parent()
	if not parent:
		return null
	var row_name := row_node.name

	if parent.name == "AttackerSide":
		match row_name:
			"FrontRow": return defender_front
			"MiddleRow": return defender_middle
			"BackRow": return defender_back
	elif parent.name == "DefenderSide":
		match row_name:
			"FrontRow": return attacker_front
			"MiddleRow": return attacker_middle
			"BackRow": return attacker_back
	return null



func animate_move_to_row(unit_node: Node2D, target_row: Node2D, _target_index: int = -1) -> void:
	if not unit_node or not is_instance_valid(unit_node) or not target_row:
		return

	var old_row := unit_node.get_parent()
	var start_world_pos := unit_node.global_position

	if old_row:
		old_row.remove_child(unit_node)
	target_row.add_child(unit_node)
	unit_node.global_position = start_world_pos

	var opposing_new := _get_opposing_row(target_row)
	var target_positions := _calculate_unit_positions(target_row, opposing_new)
	var target_children := target_row.get_children()
	var moving_index := target_children.find(unit_node)
	if moving_index < 0 or moving_index >= target_positions.size():
		return

	var target_local_pos := Vector2(0, target_positions[moving_index])

	var ally_old_positions: Dictionary = {}
	var final_positions: Dictionary = {}
	for i in range(target_children.size()):
		var child := target_children[i]
		if is_instance_valid(child) and i < target_positions.size():
			if child != unit_node:
				ally_old_positions[child] = child.position
			final_positions[child] = Vector2(0, target_positions[i])

	unit_node.global_position = start_world_pos
	var tween := create_tween()
	tween.tween_property(unit_node, "position", target_local_pos, MOVE_ANIMATION_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	for child in ally_old_positions.keys():
		if is_instance_valid(child) and child in final_positions:
			var new_pos: Vector2 = final_positions[child]
			if ally_old_positions[child].distance_to(new_pos) > 0.5:
				var ally_tween := create_tween()
				ally_tween.tween_property(child, "position", new_pos,
					MOVE_ANIMATION_DURATION * 0.6) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			else:
				child.position = new_pos

	if old_row and is_instance_valid(old_row):
		update_row_positions(old_row, true)

	await tween.finished

	for child in target_row.get_children():
		if is_instance_valid(child):
			child.set_meta(META_ORIGINAL_POSITION, child.position)


func animate_return_all_to_positions() -> void:
	var all_rows := [
		attacker_front, attacker_middle, attacker_back,
		defender_front, defender_middle, defender_back
	]
	var units_to_animate: Array[Node2D] = []

	for row in all_rows:
		for child in row.get_children():
			if is_instance_valid(child) and child is Node2D:
				if child.has_meta(META_ORIGINAL_POSITION):
					var original_pos: Vector2 = child.get_meta(META_ORIGINAL_POSITION)
					if child.position.distance_to(original_pos) > 0.5:
						units_to_animate.append(child)

	for unit in units_to_animate:
		if is_instance_valid(unit) and unit.has_meta(META_ORIGINAL_POSITION):
			var original_pos: Vector2 = unit.get_meta(META_ORIGINAL_POSITION)
			if unit.position.distance_to(original_pos) >= 0.5:
				create_tween().tween_property(
					unit, "position", original_pos, RETURN_ANIMATION_DURATION
				).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	if units_to_animate.size() > 0:
		await get_tree().create_timer(RETURN_ANIMATION_DURATION).timeout

func clear_all_rownodes() -> void:
	clear_row(attacker_back)
	clear_row(attacker_front)
	clear_row(attacker_middle)
	clear_row(defender_back)
	clear_row(defender_front)
	clear_row(defender_middle)

func clear_row(row_node: Node2D) -> void:
	for child in row_node.get_children():
		child.queue_free()
