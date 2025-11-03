extends Node3D
class_name EntityDisplay

## Visual representation of a SquadEntity
## This class handles all graphics, animations, and UI for a single entity
## It references the data but doesn't modify it - it only displays it
## 
## Can work in two modes:
## 1. Scene-based (old 2D system): Uses child nodes from entity.tscn
## 2. Programmatic (new 2.5D system): Creates Sprite3D programmatically

## Signal emitted when an animation completes
## Used to await visual updates in async code
signal animation_completed

# const Types = preload("res://src/squad_battle/types.gd")

# Reference to the data model
var entity_data: SquadEntity

# Visual components (may be created programmatically or from scene)
var sprite: Sprite3D
var name_label: Label
var info_label: Label
var damage_num_origin: Node3D

# Mode detection
var is_programmatic: bool = false

## Initialize the display with entity data (programmatic mode for 2.5D)
## texture: The sprite texture to use
## team_color: Color tint for team identification
## pixel_size: Scale of the sprite
func setup_programmatic(entity: SquadEntity, texture: Texture2D, team_color: Color, pixel_size: float = 0.0125) -> void:
	entity_data = entity
	is_programmatic = true
	
	# Create sprite programmatically
	sprite = Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	sprite.pixel_size = pixel_size
	sprite.modulate = team_color
	add_child(sprite)
	
	# Optional: Create damage number origin point
	damage_num_origin = Node3D.new()
	damage_num_origin.name = "DamageNumberOrigin"
	damage_num_origin.position = Vector3(0, 0.5, 0)
	add_child(damage_num_origin)
	
	refresh_display()

## Initialize the display with entity data (scene-based mode for old 2D system)
## This is called by the GUI when spawning entities from entity.tscn
func setup(entity: SquadEntity) -> void:
	entity_data = entity
	is_programmatic = false
	
	# Wait for nodes to be ready before refreshing
	if is_node_ready():
		_assign_scene_nodes()
		refresh_display()
	else:
		await ready
		_assign_scene_nodes()
		refresh_display()

## Assign references to child nodes (scene-based mode only)
func _assign_scene_nodes() -> void:
	sprite = get_node_or_null("Sprite3D")
	name_label = get_node_or_null("Name")
	info_label = get_node_or_null("INFO")
	damage_num_origin = get_node_or_null("DamageNumberOrigin")

## Refresh all visual elements based on current entity data
func refresh_display() -> void:
	if not entity_data:
		return
	
	# Update name (only if label exists)
	if name_label:
		name_label.text = entity_data.entity_name
	
	# Update visual appearance based on stats
	_update_hp_visual()
	_update_position_visual()
	
	# Update info label (only if exists - not in programmatic mode)
	if info_label:
		_update_info_label()

## Called when a stat changes - updates only what's needed
## This is the main entry point for the GUI to update this display
func update_stat(property: SquadBattleTypes.EntityChangeable, old_val: float, new_val: float) -> void:
	if not entity_data:
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

func _update_hp_visual() -> void:
	if not sprite or not entity_data:
		return
		
	var hp = entity_data.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var max_hp = entity_data.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	var hp_percent = hp / max_hp if max_hp > 0.0 else 0.0
	
	if is_programmatic:
		# In 2.5D mode, preserve team color and just dim based on HP
		var current_color = sprite.modulate
		sprite.modulate = Color(current_color.r, current_color.g * hp_percent, current_color.b * hp_percent, current_color.a)
	else:
		# In 2D mode, tint red when low HP
		sprite.modulate = Color(1.0, hp_percent, hp_percent)

func _update_position_visual() -> void:
	if not entity_data:
		return
	# Position is handled by GUI's _calculate_position
	# In 2D mode we could use z_index, but Node3D doesn't have that property
	# Depth sorting is handled automatically by 3D renderer

func _update_info_label() -> void:
	if not info_label or not entity_data:
		return
		
	var hp = entity_data.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var max_hp = entity_data.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	var org = entity_data.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
	var loc = entity_data.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
	
	info_label.text = "HP: %.0f/%.0f\nORG: %.0f\nLOC: %d" % [hp, max_hp, org, loc]

#endregion

#region Change handlers with animations

func _handle_hp_change(old_val: float, new_val: float) -> void:
	print("[Display %s] HP: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_hp_visual()
	
	if info_label:
		_update_info_label()

	var change = new_val - old_val
	if damage_num_origin:
		DamageNumbersManager.DisplayDamageNumber(change, damage_num_origin.global_position)
	
	# Animate HP change - use Vector3 for 3D, Vector2 for 2D
	if not sprite:
		animation_completed.emit.call_deferred()
		return
		
	var tween = create_tween()
	if is_programmatic:
		# 3D scaling with color flash
		var original_modulate = sprite.modulate
		if change < 0:  # Damage
			tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.1)
			tween.tween_property(sprite, "modulate", original_modulate, 0.1)
		else:  # Heal
			tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 0.5), 0.1)
			tween.tween_property(sprite, "modulate", original_modulate, 0.1)
		tween.parallel().tween_property(sprite, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	else:
		# 2D scaling
		tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Emit signal when animation completes
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_sta_change(old_val: float, new_val: float) -> void:
	print("[Display %s] STA: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	if info_label:
		_update_info_label()
	# No animation, emit on next frame so await can set up listener
	animation_completed.emit.call_deferred()

func _handle_org_change(old_val: float, new_val: float) -> void:
	print("[Display %s] ORG: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	if info_label:
		_update_info_label()
	# Could show morale indicator
	animation_completed.emit.call_deferred()

func _handle_pos_change(old_val: float, new_val: float) -> void:
	print("[Display %s] POS: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	if info_label:
		_update_info_label()
	animation_completed.emit.call_deferred()

func _handle_mag_change(old_val: float, new_val: float) -> void:
	print("[Display %s] MAG: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	if info_label:
		_update_info_label()
	animation_completed.emit.call_deferred()

func _handle_loc_change(old_val: float, new_val: float) -> void:
	print("[Display %s] LOC: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_position_visual()
	if info_label:
		_update_info_label()
	
	# Note: Actual position is animated by the GUI via _animate_position_change()
	# We just update visual indicators here (z-index, etc.)
	animation_completed.emit.call_deferred()

func _handle_death() -> void:
	print("[Display %s] ☠️ DIED" % entity_data.entity_name)
	
	if not sprite:
		animation_completed.emit.call_deferred()
		return
	
	# Death animation
	var tween = create_tween()
	if is_programmatic:
		# 3D death: spin and fade
		tween.tween_property(sprite, "rotation:y", PI * 2, 0.5)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(sprite, "scale", Vector3(0.5, 0.5, 0.5), 0.5)
	else:
		# 2D death
		tween.tween_property(sprite, "rotation", PI * 2, 0.5)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.5)
	
	# Emit when death animation completes
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_capitulate() -> void:
	print("[Display %s] 🏳️ CAPITULATED" % entity_data.entity_name)
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	animation_completed.emit.call_deferred()

func _handle_clink() -> void:
	print("[Display %s] ⚔️ CLINK (blocked)" % entity_data.entity_name)
	
	if not sprite:
		animation_completed.emit.call_deferred()
		return
		
	# Flash white briefly
	var original_modulate = sprite.modulate
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", original_modulate, 0.05)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_dodge() -> void:
	print("[Display %s] 💨 DODGE" % entity_data.entity_name)
	
	# Quick dash animation
	var tween = create_tween()
	if is_programmatic:
		# 3D dodge: move along Z axis
		tween.tween_property(self, "position:z", position.z + 0.5, 0.1)
		tween.tween_property(self, "position:z", position.z, 0.1)
	else:
		# 2D dodge: move along X axis
		tween.tween_property(self, "position:x", position.x + 20, 0.1)
		tween.tween_property(self, "position:x", position.x, 0.1)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_proc() -> void:
	print("[Display %s] ✨ PROC (skill triggered)" % entity_data.entity_name)
	
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
