extends Node2D
class_name EntityDisplay

## Visual representation of a SquadEntity
## This class handles all graphics, animations, and UI for a single entity
## It references the data but doesn't modify it - it only displays it

## Signal emitted when an animation completes
## Used to await visual updates in async code
signal animation_completed

# const Types = preload("res://src/squad_battle/types.gd")

# Reference to the data model
var entity_data: SquadEntity

# Visual components (assigned in _ready)
@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $Name
@onready var info_label: Label = $INFO

## Initialize the display with entity data
## This is called by the GUI when spawning entities
func setup(entity: SquadEntity) -> void:
	entity_data = entity
	# Wait for nodes to be ready before refreshing
	if is_node_ready():
		refresh_display()
	else:
		await ready
		refresh_display()

## Refresh all visual elements based on current entity data
func refresh_display() -> void:
	if not entity_data:
		return
	
	# Update name
	name_label.text = entity_data.entity_name
	
	# Update visual appearance based on stats
	_update_hp_visual()
	_update_position_visual()
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
	var hp = entity_data.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var max_hp = entity_data.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	var hp_percent = hp / max_hp if max_hp > 0.0 else 0.0
	
	# Tint sprite based on HP (red when low)
	sprite.modulate = Color(1.0, hp_percent, hp_percent)

func _update_position_visual() -> void:
	var loc = entity_data.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
	# Position is handled by GUI's _calculate_position
	# But we can update visual indicators here (e.g., z-index)
	z_index = -loc  # Front entities appear on top

func _update_info_label() -> void:
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
	_update_info_label()
	
	# Animate HP change
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Emit signal when animation completes
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_sta_change(old_val: float, new_val: float) -> void:
	print("[Display %s] STA: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_info_label()
	# No animation, emit on next frame so await can set up listener
	animation_completed.emit.call_deferred()

func _handle_org_change(old_val: float, new_val: float) -> void:
	print("[Display %s] ORG: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_info_label()
	# Could show morale indicator
	animation_completed.emit.call_deferred()

func _handle_pos_change(old_val: float, new_val: float) -> void:
	print("[Display %s] POS: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_info_label()
	animation_completed.emit.call_deferred()

func _handle_mag_change(old_val: float, new_val: float) -> void:
	print("[Display %s] MAG: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_info_label()
	animation_completed.emit.call_deferred()

func _handle_loc_change(old_val: float, new_val: float) -> void:
	print("[Display %s] LOC: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_position_visual()
	_update_info_label()
	
	# Note: Actual position is animated by the GUI via _animate_position_change()
	# We just update visual indicators here (z-index, etc.)
	animation_completed.emit.call_deferred()

func _handle_death() -> void:
	print("[Display %s] ☠️ DIED" % entity_data.entity_name)
	
	# Death animation
	var tween = create_tween()
	tween.tween_property(sprite, "rotation", PI * 2, 0.5)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.5)
	
	# Emit when death animation completes
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_capitulate() -> void:
	print("[Display %s] 🏳️ CAPITULATED" % entity_data.entity_name)
	sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	animation_completed.emit.call_deferred()

func _handle_clink() -> void:
	print("[Display %s] ⚔️ CLINK (blocked)" % entity_data.entity_name)
	# Flash white briefly
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", sprite.modulate, 0.05)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_dodge() -> void:
	print("[Display %s] 💨 DODGE" % entity_data.entity_name)
	# Quick dash animation
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x + 20, 0.1)
	tween.tween_property(self, "position:x", position.x, 0.1)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_proc() -> void:
	print("[Display %s] ✨ PROC (skill triggered)" % entity_data.entity_name)
	# Sparkle effect
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

#endregion
