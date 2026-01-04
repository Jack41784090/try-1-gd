extends Node3D
class_name EntityDisplay
signal animation_completed

# Reference to the data model
var squad_entity: SquadEntity

# Visual components (may be created programmatically or from scene)
@onready var sprite: Sprite3D = $Sprite3D
@onready var name_label: Label3D = $InfoLayer/Name
@onready var info_label: Label3D = $InfoLayer/Info
@onready var damage_num_origin: Node3D = $DamageOrigin

# Stats display components
@onready var stats_display: Node3D = $StatsDisplay
@onready var hp_bar_bg: CSGBox3D = $StatsDisplay/HPBarBackground
@onready var hp_bar_fill: CSGBox3D = $StatsDisplay/HPBarFill
@onready var hp_label: Label3D = $StatsDisplay/HPLabel
@onready var org_container: Node3D = $StatsDisplay/ORGContainer

# HP Bar configuration
const HP_BAR_MAX_WIDTH: float = 1.3
const HP_BAR_HEIGHT: float = 0.08
const HP_BAR_DEPTH: float = 0.02

# ORG display configuration
const ORG_ICON_SPACING: float = 0.18
const ORG_ICON_SIZE: float = 0.15
const ORG_MAX_DISPLAY: int = 10

var is_programmatic: bool = false
var _org_icons: Array[Sprite3D] = []
var _current_org_display: int = 0

var _debug_id: String = ""

## Initialize the display with entity data (scene-based mode for old 2D system)
## This is called by the GUI when spawning entities from entity.tscn
func setup(entity: SquadEntity) -> void:
	print("[EntityDisplay] Setting up display for entity %s [%d]" % [entity.entity_name, entity.player_id])
	squad_entity = entity
	_debug_id = "[Display:%s[%d]]" % [entity.entity_name, entity.player_id]
	
	var unique_material = sprite.material_override.duplicate() as ShaderMaterial
	unique_material.set_shader_parameter("albedo_texture", entity.icon)
	sprite.material_override = unique_material
	
	# Initialize stats display
	_initialize_hp_bar()
	_initialize_org_icons()

	switch_sprite("idle")

## Refresh all visual elements based on current entity data
func refresh_display() -> void:
	if not squad_entity:
		return
	
	# Update name (only if label exists)
	if name_label:
		name_label.text = "%s [%s]" % [squad_entity.entity_name, str(squad_entity.player_id)]
	
	# Update info label (only if exists - not in programmatic mode)
	if info_label:
		_update_info_label()
	
	# Update HP bar
	_update_hp_bar_display()
	
	# Update ORG icons
	_update_org_display()

## Called when a stat changes - updates only what's needed
## This is the main entry point for the GUI to update this display
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
			_handle_pos_change(old_val, new_val)
		SquadBattleTypes.EntityChangeable.MAG:
			_handle_mag_change(old_val, new_val)
		SquadBattleTypes.EntityChangeable.LOC:
			_handle_loc_change(old_val, new_val)
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

#region Private update handlers

func _update_info_label() -> void:
	if not info_label or not squad_entity:
		return
		
	var hp = squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var max_hp = squad_entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	var org = squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
	var loc = squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
	
	info_label.text = "HP: %.0f/%.0f\nORG: %.0f\nLOC: %d" % [hp, max_hp, org, loc]

#region HP Bar Management

func _initialize_hp_bar() -> void:
	if not squad_entity or not hp_bar_fill or not hp_label:
		return
	
	_update_hp_bar_display()

func _update_hp_bar_display() -> void:
	if not squad_entity or not hp_bar_fill or not hp_label:
		return
	
	var hp = squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var max_hp = squad_entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	var hp_ratio = clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0 else 0.0
	
	# Update fill bar width
	var new_width = HP_BAR_MAX_WIDTH * hp_ratio
	hp_bar_fill.size.x = maxf(new_width, 0.01)
	
	# Offset the fill bar to align left edge
	var offset = (HP_BAR_MAX_WIDTH - new_width) / 2.0
	hp_bar_fill.position.x = -offset
	
	# Update HP label text
	hp_label.text = "%.0f/%.0f" % [hp, max_hp]
	
	# Update color based on HP percentage
	var fill_material = hp_bar_fill.material as StandardMaterial3D
	if fill_material:
		fill_material = fill_material.duplicate() as StandardMaterial3D
		hp_bar_fill.material = fill_material
		
		if hp_ratio > 0.6:
			fill_material.albedo_color = Color(0.2, 0.85, 0.3, 1.0)  # Green
		elif hp_ratio > 0.3:
			fill_material.albedo_color = Color(0.95, 0.75, 0.2, 1.0)  # Yellow/Orange
		else:
			fill_material.albedo_color = Color(0.9, 0.2, 0.2, 1.0)  # Red

func _animate_hp_bar_change(old_hp: float, new_hp: float) -> Tween:
	if not squad_entity or not hp_bar_fill or not hp_label:
		return null
	
	var max_hp = squad_entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	if max_hp <= 0:
		return null
	
	var old_ratio = clampf(old_hp / max_hp, 0.0, 1.0)
	var new_ratio = clampf(new_hp / max_hp, 0.0, 1.0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Animate bar width
	var old_width = HP_BAR_MAX_WIDTH * old_ratio
	var new_width = HP_BAR_MAX_WIDTH * new_ratio
	
	tween.tween_method(
		func(width: float):
			hp_bar_fill.size.x = maxf(width, 0.01)
			var offset = (HP_BAR_MAX_WIDTH - width) / 2.0
			hp_bar_fill.position.x = -offset,
		old_width, new_width, 0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Update label at end
	tween.chain().tween_callback(func():
		hp_label.text = "%.0f/%.0f" % [new_hp, max_hp]
		_update_hp_bar_color(new_ratio)
	)
	
	return tween

func _update_hp_bar_color(hp_ratio: float) -> void:
	var fill_material = hp_bar_fill.material as StandardMaterial3D
	if not fill_material:
		return
	
	fill_material = fill_material.duplicate() as StandardMaterial3D
	hp_bar_fill.material = fill_material
	
	if hp_ratio > 0.6:
		fill_material.albedo_color = Color(0.2, 0.85, 0.3, 1.0)
	elif hp_ratio > 0.3:
		fill_material.albedo_color = Color(0.95, 0.75, 0.2, 1.0)
	else:
		fill_material.albedo_color = Color(0.9, 0.2, 0.2, 1.0)

#endregion

#region ORG Icons Management

func _initialize_org_icons() -> void:
	if not squad_entity or not org_container:
		return
	
	# Clear any existing icons
	for icon in _org_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	_org_icons.clear()
	
	var org = squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
	var org_count = mini(ceili(org), ORG_MAX_DISPLAY)
	_current_org_display = org_count
	
	_create_org_icons(org_count)

func _create_org_icons(count: int) -> void:
	if not org_container:
		return
	
	var total_width = (count - 1) * ORG_ICON_SPACING
	var start_x = -total_width / 2.0
	
	for i in range(count):
		var icon = Sprite3D.new()
		icon.name = "ORG_%d" % i
		icon.texture = preload("res://assets/icon.svg")
		icon.pixel_size = 0.008
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.render_priority = 105
		icon.modulate = Color(1.0, 0.85, 0.2, 1.0)  # Golden yellow
		icon.position = Vector3(start_x + i * ORG_ICON_SPACING, 0, 0)
		
		org_container.add_child(icon)
		_org_icons.append(icon)

func _update_org_display() -> void:
	if not squad_entity or not org_container:
		return
	
	var org = squad_entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
	var new_count = mini(ceili(org), ORG_MAX_DISPLAY)
	
	if new_count != _current_org_display:
		_rebuild_org_icons(new_count)

func _rebuild_org_icons(new_count: int) -> void:
	for icon in _org_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	_org_icons.clear()
	
	_current_org_display = new_count
	_create_org_icons(new_count)

func _animate_org_change(old_org: float, new_org: float) -> Tween:
	var old_count = mini(ceili(old_org), ORG_MAX_DISPLAY)
	var new_count = mini(ceili(new_org), ORG_MAX_DISPLAY)
	
	if new_count >= old_count:
		# ORG increased - just rebuild
		_rebuild_org_icons(new_count)
		return null
	
	# ORG decreased - animate icons being lost
	var icons_to_remove = old_count - new_count
	var tween = create_tween()
	
	for i in range(icons_to_remove):
		var icon_index = _org_icons.size() - 1 - i
		if icon_index >= 0 and icon_index < _org_icons.size():
			var icon = _org_icons[icon_index]
			if is_instance_valid(icon):
				# Shake and fade animation
				var original_pos = icon.position
				tween.set_parallel(true)
				
				# Shake effect
				for j in range(4):
					var shake_offset = Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), 0)
					tween.tween_property(icon, "position", original_pos + shake_offset, 0.05)
				
				# Fade and scale down
				tween.tween_property(icon, "modulate:a", 0.0, 0.3).set_delay(0.2)
				tween.tween_property(icon, "scale", Vector3(0.3, 0.3, 0.3), 0.3).set_delay(0.2)
	
	# Remove icons after animation
	tween.chain().tween_callback(func():
		_rebuild_org_icons(new_count)
	)
	
	return tween

#endregion

func _flash_colour(colour: Color, to_colour_time: float = .1, back_to_original_time: float = .1):
	if not sprite or not sprite.material_override:
		return null
	
	var material = sprite.material_override as ShaderMaterial
	if not material:
		return null
	
	var tween = create_tween()
	
	# Set the flash color once
	material.set_shader_parameter("flash_color", colour)
	
	# Animate the intensity from 0 -> 1 -> 0
	tween.tween_method(
		func(value: float): material.set_shader_parameter("flash_intensity", value),
		0.0, .75, to_colour_time
	)
	tween.tween_method(
		func(value: float): material.set_shader_parameter("flash_intensity", value),
		.75, 0.0, back_to_original_time
	)
	
	return tween

func _jump() -> Tween:
	if not sprite:
		return null
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
	tween.tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	return tween

func switch_sprite(sprite_mode):
	var sprite_name = "res://assets/%s-%s.png" % [squad_entity.class_id, sprite_mode]
	var texture = load(sprite_name)
	assert(texture != null, "%s not found." % sprite_name)
	sprite.material_override.set_shader_parameter("albedo_texture", texture)

#region Change handlers with animations

func _handle_hp_change(old_val: float, new_val: float) -> void:
	print("%s HP: %.1f → %.1f" % [_debug_id, old_val, new_val])

	var change = new_val - old_val
	DamageNumbersManager.DisplayDamageNumber(change, damage_num_origin.global_position)

	if not sprite:
		print("%s [HP] No sprite, emitting completion" % _debug_id)
		animation_completed.emit.call_deferred()
		return

	# Animate HP bar
	var hp_tween = _animate_hp_bar_change(old_val, new_val)
	
	if change < 0:
		_flash_colour(Color(1.5,.5,.5))
	else:
		_flash_colour(Color(.5,1.5,.5))

	var jump_tween = _jump()
	
	# Wait for both animations to complete using dictionary to capture by reference
	var completion := {"jump": jump_tween == null, "hp": hp_tween == null}
	
	if jump_tween:
		jump_tween.finished.connect(func(): completion["jump"] = true, CONNECT_ONE_SHOT)
	
	if hp_tween:
		hp_tween.finished.connect(func(): completion["hp"] = true, CONNECT_ONE_SHOT)
	
	# If both are already null/complete, emit immediately
	if completion["jump"] and completion["hp"]:
		animation_completed.emit()
		return
	
	# Wait until both complete with safety timeout
	var wait_frames := 0
	while not (completion["jump"] and completion["hp"]):
		await get_tree().process_frame
		wait_frames += 1
		if wait_frames > 300:  # Safety timeout ~5 seconds at 60fps
			push_warning("%s [HP] TIMEOUT waiting for animations! State: %s" % [_debug_id, completion])
			break
	
	animation_completed.emit()

func _handle_sta_change(old_val: float, new_val: float) -> void:
	print("%s STA: %.1f → %.1f" % [_debug_id, old_val, new_val])
	_update_info_label()
	# No animation, emit on next frame so await can set up listener
	animation_completed.emit.call_deferred()

func _handle_org_change(old_val: float, new_val: float) -> void:
	print("%s ORG: %.1f → %.1f" % [_debug_id, old_val, new_val])
	_update_info_label()
	
	# Animate ORG icons
	var tween = _animate_org_change(old_val, new_val)
	if tween:
		tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)
	else:
		animation_completed.emit.call_deferred()

func _handle_pos_change(old_val: float, new_val: float) -> void:
	print("%s POS: %.1f → %.1f" % [_debug_id, old_val, new_val])
	_update_info_label()
	animation_completed.emit.call_deferred()

func _handle_mag_change(old_val: float, new_val: float) -> void:
	print("%s MAG: %.1f → %.1f" % [_debug_id, old_val, new_val])
	_update_info_label()
	animation_completed.emit.call_deferred()

func _handle_loc_change(old_val: float, new_val: float) -> void:
	print("%s LOC: %.1f → %.1f" % [_debug_id, old_val, new_val])
	_update_info_label()
	
	# Note: Actual position is animated by the GUI via _animate_position_change()
	# We just update visual indicators here (z-index, etc.)
	animation_completed.emit.call_deferred()

func _handle_death() -> void:
	print("%s ☠️ DIED" % _debug_id)
	
	if not sprite:
		animation_completed.emit.call_deferred()
		return
	
	var tween = create_tween()
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite, "rotation:y", PI * 2, 0.5)
	tween.parallel().tween_property(sprite, "scale", Vector3(0.5, 0.5, 0.5), 0.5)
	
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_capitulate() -> void:
	print("%s 🏳️ CAPITULATED" % _debug_id)
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	animation_completed.emit.call_deferred()

func _handle_clink() -> void:
	print("%s ⚔️ CLINK (blocked)" % _debug_id)

	if not sprite:
		animation_completed.emit.call_deferred()
		return

	# Flash white briefly
	var tween = _flash_colour(Color.WHITE, .05, .05)
	if tween:
		tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)
	else:
		animation_completed.emit.call_deferred()

func _handle_dodge() -> void:
	print("%s 💨 DODGE" % _debug_id)
	
	var tween = create_tween()
	tween.tween_property(self, "position:z", position.z + 0.5, 0.1)
	tween.tween_property(self, "position:z", position.z, 0.1)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_proc() -> void:
	print("%s ✨ PROC (skill triggered)" % _debug_id)
	
	if not sprite:
		animation_completed.emit.call_deferred()
		return
		
	# Sparkle effect
	var original_modulate = sprite.modulate
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(sprite, "modulate", original_modulate, 0.1)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

#endregion
