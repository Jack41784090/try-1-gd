extends Node2D
class_name EntityDisplay

## Visual representation of a SquadEntity
## This class handles all graphics, animations, and UI for a single entity
## It references the data but doesn't modify it - it only displays it

const Types = preload("res://src/squad_battle/types.gd")

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
func update_stat(property: Types.EntityChangeable, old_val: float, new_val: float) -> void:
	if not entity_data:
		return
	
	match property:
		Types.EntityChangeable.HP:
			_handle_hp_change(old_val, new_val)
		Types.EntityChangeable.STA:
			_handle_sta_change(old_val, new_val)
		Types.EntityChangeable.ORG:
			_handle_org_change(old_val, new_val)
		Types.EntityChangeable.POS:
			_handle_pos_change(old_val, new_val)
		Types.EntityChangeable.MAG:
			_handle_mag_change(old_val, new_val)
		Types.EntityChangeable.LOC:
			_handle_loc_change(old_val, new_val)
		Types.EntityChangeable.DIE:
			_handle_death()
		Types.EntityChangeable.CAPITULATE:
			_handle_capitulate()
		Types.EntityChangeable.CLINK:
			_handle_clink()
		Types.EntityChangeable.DODGE:
			_handle_dodge()
		Types.EntityChangeable.PROC:
			_handle_proc()

# === Private update handlers ===
# region 
func _update_hp_visual() -> void:
	var hp = entity_data.get_changeable_stat_num(Types.EntityChangeable.HP)
	var max_hp = entity_data.get_ceiling_changeable_stat(Types.EntityChangeable.HP)
	var hp_percent = hp / max_hp if max_hp > 0.0 else 0.0
	
	# Tint sprite based on HP (red when low)
	sprite.modulate = Color(1.0, hp_percent, hp_percent)

func _update_position_visual() -> void:
	var loc = entity_data.get_changeable_stat_num(Types.EntityChangeable.LOC) as int
	# Position is handled by GUI's _calculate_position
	# But we can update visual indicators here (e.g., z-index)
	z_index = -loc  # Front entities appear on top

func _update_info_label() -> void:
	var hp = entity_data.get_changeable_stat_num(Types.EntityChangeable.HP)
	var max_hp = entity_data.get_ceiling_changeable_stat(Types.EntityChangeable.HP)
	var org = entity_data.get_changeable_stat_num(Types.EntityChangeable.ORG)
	var loc = entity_data.get_changeable_stat_num(Types.EntityChangeable.LOC) as int
	
	info_label.text = "HP: %.0f/%.0f\nORG: %.0f\nLOC: %d" % [hp, max_hp, org, loc]

# endregion

# === Change handlers with animations ===
# region 

func _handle_hp_change(old_val: float, new_val: float) -> void:
	print("[Display %s] HP: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_hp_visual()
	_update_info_label()
	
	# Animate HP change
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

func _handle_sta_change(old_val: float, new_val: float) -> void:
	print("[Display %s] STA: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_info_label()

func _handle_org_change(old_val: float, new_val: float) -> void:
	print("[Display %s] ORG: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_info_label()
	# Could show morale indicator

func _handle_pos_change(old_val: float, new_val: float) -> void:
	print("[Display %s] POS: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_info_label()

func _handle_mag_change(old_val: float, new_val: float) -> void:
	print("[Display %s] MAG: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_info_label()

func _handle_loc_change(old_val: float, new_val: float) -> void:
	print("[Display %s] LOC: %.1f → %.1f" % [entity_data.entity_name, old_val, new_val])
	_update_position_visual()
	_update_info_label()
	
	# Animate position change (GUI will update actual position)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.5, 0.2)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _handle_death() -> void:
	print("[Display %s] ☠️ DIED" % entity_data.entity_name)
	
	# Death animation
	var tween = create_tween()
	tween.tween_property(sprite, "rotation", PI * 2, 0.5)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.5)

func _handle_capitulate() -> void:
	print("[Display %s] 🏳️ CAPITULATED" % entity_data.entity_name)
	sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)

func _handle_clink() -> void:
	print("[Display %s] ⚔️ CLINK (blocked)" % entity_data.entity_name)
	# Flash white briefly
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", sprite.modulate, 0.05)

func _handle_dodge() -> void:
	print("[Display %s] 💨 DODGE" % entity_data.entity_name)
	# Quick dash animation
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x + 20, 0.1)
	tween.tween_property(self, "position:x", position.x, 0.1)

func _handle_proc() -> void:
	print("[Display %s] ✨ PROC (skill triggered)" % entity_data.entity_name)
	# Sparkle effect
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

# endregion
