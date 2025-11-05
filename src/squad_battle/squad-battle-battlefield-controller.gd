class_name d25BattlefieldController extends Node3D

const BATTLEFIELD_WIDTH: float = 20.0
const BATTLEFIELD_DEPTH: float = 24.0
const ROW_SPACING: float = 2.5
const BASE_UNIT_SPACING: float = 3.75
const UNIT_HEIGHT_OFFSET: float = 1
const UNIT_PIXEL_SIZE: float = 0.0125
const PLACEHOLDER_TEXTURE = preload("res://assets/icon.svg")
const ENTITY_SCENE = preload("res://scenes/entity.tscn")

const MOVE_ANIMATION_DURATION: float = 0.5
const RECOIL_ANIMATION_DURATION: float = 0.3
const RETURN_ANIMATION_DURATION: float = 0.4
const RECOIL_DISTANCE: float = 0.3
const META_ORIGINAL_POSITION: String = "original_position"

const ORG_ARC_RADIUS: float = 0.8
const ORG_ARC_ANGLE: float = 120.0
const ORG_ICON_SIZE: float = 0.01
const ORG_SHAKE_DURATION: float = 0.3
const ORG_FADE_DURATION: float = 0.4

@onready var attacker_front: Node3D = $Battlefield/AttackerSide/FrontRow
@onready var attacker_middle: Node3D = $Battlefield/AttackerSide/MiddleRow
@onready var attacker_back: Node3D = $Battlefield/AttackerSide/BackRow
@onready var defender_front: Node3D = $Battlefield/DefenderSide/FrontRow
@onready var defender_middle: Node3D = $Battlefield/DefenderSide/MiddleRow
@onready var defender_back: Node3D = $Battlefield/DefenderSide/BackRow

func add_unit_to_row(row_node: Node3D, unit_index: int, unit_name: String = "Unit", entity: SquadEntity = null) -> Node3D:
	var unit_node: Node3D
	
	if entity:
		var display = ENTITY_SCENE.instantiate() as EntityDisplay
		display.name = "%s_%d" % [unit_name, unit_index]
		display.position = Vector3(0, UNIT_HEIGHT_OFFSET, 0)
		row_node.add_child(display)
		display.setup(entity)
		
		if entity.icon:
			display.sprite.texture = entity.icon
		display.sprite.pixel_size = UNIT_PIXEL_SIZE
		
		var parent = row_node.get_parent()
		if parent:
			display.sprite.modulate = Color(1, 0.3, 0.3) if parent.name == "AttackerSide" else Color(0.3, 0.3, 1)
		
		display.refresh_display()
		unit_node = display
	else:
		var sprite = Sprite3D.new()
		sprite.name = "%s_%d" % [unit_name, unit_index]
		sprite.texture = PLACEHOLDER_TEXTURE
		sprite.pixel_size = UNIT_PIXEL_SIZE
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = true
		sprite.position = Vector3(0, UNIT_HEIGHT_OFFSET, 0)
		row_node.add_child(sprite)
		unit_node = sprite
	
	if is_instance_valid(unit_node):
		unit_node.set_meta(META_ORIGINAL_POSITION, unit_node.position)
	return unit_node

func update_row_positions(row_node: Node3D, animate: bool = false) -> void:
	var opposing_row = _get_opposing_row(row_node)
	var positions = _calculate_unit_positions_for_row(row_node, opposing_row)
	var children = row_node.get_children()

	for i in range(children.size()):
		var child = children[i]
		if (child is Sprite3D or child is EntityDisplay) and i < positions.size():
			var target_pos = Vector3(0, UNIT_HEIGHT_OFFSET, positions[i])
			if animate and is_instance_valid(child):
				create_tween().tween_property(child, "position", target_pos, MOVE_ANIMATION_DURATION * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			else:
				child.position = target_pos
			if is_instance_valid(child):
				child.set_meta(META_ORIGINAL_POSITION, target_pos)

func _calculate_unit_positions_for_row(row_node: Node3D, opposing_row: Node3D) -> Array[float]:
	var our_count = row_node.get_child_count()
	var their_count = opposing_row.get_child_count() if opposing_row else our_count
	if our_count == 0:
		return []
	
	var max_count = max(our_count, their_count)
	var total_spread = (max_count - 1) * BASE_UNIT_SPACING
	var positions: Array[float] = []
	
	for i in range(our_count):
		var normalized_pos = float(i) / max(1, our_count - 1) if our_count > 1 else 0.5
		positions.append((normalized_pos * total_spread) - (total_spread / 2.0))
	return positions

func _get_opposing_row(row_node: Node3D) -> Node3D:
	var parent = row_node.get_parent()
	if not parent:
		return null
	var row_name = row_node.name
	
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

func animate_move_to_row(unit_node: Node3D, target_row: Node3D, _target_index: int = -1) -> void:
	if not unit_node or not is_instance_valid(unit_node) or not target_row:
		return
	
	var old_row = unit_node.get_parent()
	var start_world_pos = unit_node.global_position
	
	if old_row:
		old_row.remove_child(unit_node)
	target_row.add_child(unit_node)
	unit_node.global_position = start_world_pos
	
	var opposing_new = _get_opposing_row(target_row)
	var target_positions = _calculate_unit_positions_for_row(target_row, opposing_new)
	var target_children = target_row.get_children()
	
	var moving_unit_index = target_children.find(unit_node)
	if moving_unit_index < 0 or moving_unit_index >= target_positions.size():
		return
	
	var target_local_pos = Vector3(0, UNIT_HEIGHT_OFFSET, target_positions[moving_unit_index])
	
	var ally_old_positions: Dictionary = {}
	var final_positions: Dictionary = {}
	for i in range(target_children.size()):
		var child = target_children[i]
		if is_instance_valid(child) and i < target_positions.size():
			if child != unit_node:
				ally_old_positions[child] = child.position
			final_positions[child] = Vector3(0, UNIT_HEIGHT_OFFSET, target_positions[i])
	
	unit_node.global_position = start_world_pos
	var tween = create_tween()
	tween.tween_property(unit_node, "position", target_local_pos, MOVE_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	for child in ally_old_positions.keys():
		if is_instance_valid(child) and child in final_positions:
			var new_pos = final_positions[child]
			if ally_old_positions[child].distance_to(new_pos) > 0.01:
				create_tween().tween_property(child, "position", new_pos, MOVE_ANIMATION_DURATION * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			else:
				child.position = new_pos
	
	if old_row and is_instance_valid(old_row):
		update_row_positions(old_row, true)
	
	await tween.finished
	
	for child in target_row.get_children():
		if is_instance_valid(child):
			child.set_meta(META_ORIGINAL_POSITION, child.position)

func animate_attack_recoil(unit_node: Node3D, attack_direction: Vector3 = Vector3.ZERO) -> void:
	if not unit_node or not is_instance_valid(unit_node):
		return
	
	if attack_direction == Vector3.ZERO:
		var parent = unit_node.get_parent()
		if parent:
			var grandparent = parent.get_parent()
			attack_direction = Vector3(-1, 0, 0) if (grandparent and grandparent.name == "AttackerSide") else Vector3(1, 0, 0)
		else:
			attack_direction = Vector3(-1, 0, 0)
	
	var recoil_pos = unit_node.position + attack_direction.normalized() * RECOIL_DISTANCE
	await create_tween().tween_property(unit_node, "position", recoil_pos, RECOIL_ANIMATION_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).finished

func animate_attack_lunge(unit_node: Node3D, attack_direction: Vector3 = Vector3.ZERO) -> void:
	if not unit_node or not is_instance_valid(unit_node):
		return
	
	if attack_direction == Vector3.ZERO:
		var parent = unit_node.get_parent()
		if parent:
			var grandparent = parent.get_parent()
			attack_direction = Vector3(1, 0, 0) if (grandparent and grandparent.name == "AttackerSide") else Vector3(-1, 0, 0)
		else:
			attack_direction = Vector3(1, 0, 0)
	
	var lunge_pos = unit_node.position + attack_direction.normalized() * RECOIL_DISTANCE
	await create_tween().tween_property(unit_node, "position", lunge_pos, RECOIL_ANIMATION_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).finished

func animate_clink(unit_node: Node3D) -> void:
	if not unit_node or not is_instance_valid(unit_node):
		return
	
	var original_pos = unit_node.position
	var forward_push = original_pos + Vector3(0, 0.1, 0)
	var tween = create_tween()
	tween.tween_property(unit_node, "position", forward_push, RECOIL_ANIMATION_DURATION * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit_node, "position", original_pos, RECOIL_ANIMATION_DURATION * 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tween.finished

func animate_return_to_position(unit_node: Node3D) -> void:
	if not unit_node or not is_instance_valid(unit_node) or not unit_node.has_meta(META_ORIGINAL_POSITION):
		return
	
	var original_pos = unit_node.get_meta(META_ORIGINAL_POSITION)
	if unit_node.position.distance_to(original_pos) < 0.01:
		return
	
	await create_tween().tween_property(unit_node, "position", original_pos, RETURN_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).finished

func animate_return_all_to_positions() -> void:
	var all_rows = [attacker_front, attacker_middle, attacker_back, defender_front, defender_middle, defender_back]
	var units_to_animate = []
	
	for row in all_rows:
		for child in row.get_children():
			if is_instance_valid(child) and (child is Sprite3D or child is EntityDisplay):
				if child.has_meta(META_ORIGINAL_POSITION):
					var original_pos = child.get_meta(META_ORIGINAL_POSITION)
					if child.position.distance_to(original_pos) > 0.01:
						units_to_animate.append(child)
	
	for unit in units_to_animate:
		if is_instance_valid(unit):
			animate_return_to_position(unit)
	
	if units_to_animate.size() > 0:
		await get_tree().create_timer(RETURN_ANIMATION_DURATION).timeout

func clear_row(row_node: Node3D) -> void:
	for child in row_node.get_children():
		child.queue_free()

func create_org_arc(unit_node: Node3D, org_value: float) -> Node3D:
	var org_container = Node3D.new()
	org_container.name = "ORGArc"
	unit_node.add_child(org_container)
	
	var org_count = ceili(org_value)
	if org_count <= 0:
		return org_container
	
	var start_angle = -ORG_ARC_ANGLE / 2.0
	var angle_step = ORG_ARC_ANGLE / max(1, org_count - 1) if org_count > 1 else 0.0
	
	for i in range(org_count):
		var angle = deg_to_rad(start_angle + (i * angle_step))
		var x = sin(angle) * ORG_ARC_RADIUS
		var y = cos(angle) * ORG_ARC_RADIUS + 0.8
		
		var org_icon = Sprite3D.new()
		org_icon.name = "ORGIcon_%d" % i
		org_icon.texture = PLACEHOLDER_TEXTURE
		org_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		org_icon.shaded = false
		org_icon.pixel_size = ORG_ICON_SIZE
		org_icon.position = Vector3(0, y, x)
		org_icon.modulate = Color(1, 0.8, 0.2)
		
		org_container.add_child(org_icon)
	
	return org_container

func update_org_arc(unit_node: Node3D, old_org: float, new_org: float) -> void:
	var org_container = unit_node.get_node_or_null("ORGArc")
	if not org_container:
		org_container = create_org_arc(unit_node, new_org)
		return
	
	var old_count = ceili(old_org)
	var new_count = ceili(new_org)
	
	if new_count < old_count:
		for i in range(new_count, old_count):
			var icon = org_container.get_node_or_null("ORGIcon_%d" % i)
			if icon:
				animate_org_loss(icon)

func animate_org_loss(icon: Sprite3D) -> void:
	if not is_instance_valid(icon):
		return
	
	var original_pos = icon.position
	var shake_tween = create_tween()
	shake_tween.set_parallel(true)
	
	for j in range(6):
		var offset = Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
		shake_tween.tween_property(icon, "position", original_pos + offset, ORG_SHAKE_DURATION / 6.0)
	
	shake_tween.chain().tween_property(icon, "position", original_pos, 0.05)
	
	await shake_tween.finished
	
	if is_instance_valid(icon):
		var shader_material = ShaderMaterial.new()
		shader_material.shader = _create_org_shader()
		shader_material.set_shader_parameter("texture_albedo", icon.texture)
		shader_material.set_shader_parameter("dissolve_amount", 0.0)
		icon.material_override = shader_material
		
		var fade_tween = create_tween()
		fade_tween.tween_method(func(val): shader_material.set_shader_parameter("dissolve_amount", val), 0.0, 1.0, ORG_FADE_DURATION)
		await fade_tween.finished
		
		if is_instance_valid(icon):
			icon.queue_free()

func _create_org_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded, depth_test_disabled;

uniform sampler2D texture_albedo : source_color, hint_default_white;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	vec4 albedo_tex = texture(texture_albedo, uv);
	if (albedo_tex.a < 0.01) {
		discard;
	}
	
	float noise = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
	float dissolve = step(dissolve_amount, noise);
	
	ALBEDO = albedo_tex.rgb;
	ALPHA = albedo_tex.a * dissolve;
	
	if (ALPHA < 0.01) {
		discard;
	}
}
"""
	return shader
