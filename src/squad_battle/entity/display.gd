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
@onready var sprite: Sprite3D = $Sprite3D
@onready var name_label: Label3D = $InfoLayer/Name
@onready var info_label: Label3D = $InfoLayer/Info
@onready var damage_num_origin: Node3D = $DamageOrigin

var is_programmatic: bool = false


var _debug_id: String = ""

## Initialize the display with entity data (scene-based mode for old 2D system)
## This is called by the GUI when spawning entities from entity.tscn
func setup(entity: SquadEntity) -> void:
	entity_data = entity
	_debug_id = "[Display:%s[%d]]" % [entity.entity_name, entity.player_id]

## Assign references to child nodes (scene-based mode only)
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
	pass

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
	print("%s HP: %.1f → %.1f" % [_debug_id, old_val, new_val])
	_update_hp_visual()
	
	if info_label:
		_update_info_label()

	var change = new_val - old_val
	if damage_num_origin:
		DamageNumbersManager.DisplayDamageNumber(change, damage_num_origin.global_position)
	
	if not sprite:
		animation_completed.emit.call_deferred()
		return
		
	var tween = create_tween()
	var original_modulate = sprite.modulate
	
	if change < 0:
		tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		tween.tween_property(sprite, "modulate", original_modulate, 0.1)
	else:
		tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 0.5), 0.1)
		tween.tween_property(sprite, "modulate", original_modulate, 0.1)
	
	if sprite is Sprite3D:
		tween.parallel().tween_property(sprite, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	else:
		tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_sta_change(old_val: float, new_val: float) -> void:
	print("%s STA: %.1f → %.1f" % [_debug_id, old_val, new_val])
	if info_label:
		_update_info_label()
	# No animation, emit on next frame so await can set up listener
	animation_completed.emit.call_deferred()

func _handle_org_change(old_val: float, new_val: float) -> void:
	print("%s ORG: %.1f → %.1f" % [_debug_id, old_val, new_val])
	if info_label:
		_update_info_label()
	# Could show morale indicator
	animation_completed.emit.call_deferred()

func _handle_pos_change(old_val: float, new_val: float) -> void:
	print("%s POS: %.1f → %.1f" % [_debug_id, old_val, new_val])
	if info_label:
		_update_info_label()
	animation_completed.emit.call_deferred()

func _handle_mag_change(old_val: float, new_val: float) -> void:
	print("%s MAG: %.1f → %.1f" % [_debug_id, old_val, new_val])
	if info_label:
		_update_info_label()
	animation_completed.emit.call_deferred()

func _handle_loc_change(old_val: float, new_val: float) -> void:
	print("%s LOC: %.1f → %.1f" % [_debug_id, old_val, new_val])
	_update_position_visual()
	if info_label:
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
	
	if sprite is Sprite3D:
		tween.tween_property(sprite, "rotation:y", PI * 2, 0.5)
		tween.parallel().tween_property(sprite, "scale", Vector3(0.5, 0.5, 0.5), 0.5)
	else:
		tween.tween_property(sprite, "rotation", PI * 2, 0.5)
		tween.parallel().tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.5)
	
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
	var original_modulate = sprite.modulate
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", original_modulate, 0.05)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

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
