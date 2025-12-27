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
# @onready var mesh: MeshInstance3D = $Mesh

var is_programmatic: bool = false


var _debug_id: String = ""

## Initialize the display with entity data (scene-based mode for old 2D system)
## This is called by the GUI when spawning entities from entity.tscn
func setup(entity: SquadEntity) -> void:
	squad_entity = entity
	_debug_id = "[Display:%s[%d]]" % [entity.entity_name, entity.player_id]
	
	var unique_material = sprite.material_override.duplicate() as ShaderMaterial
	unique_material.set_shader_parameter("albedo_texture", entity.icon)
	sprite.material_override = unique_material
	# sprite.pixel_size = 0.0525

## Assign references to child nodes (scene-based mode only)
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

func _jump():
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
	# _update_info_label()

	var change = new_val - old_val
	DamageNumbersManager.DisplayDamageNumber(change, damage_num_origin.global_position)

	if not sprite:
		print("%s [HP] No sprite, emitting completion" % _debug_id)
		animation_completed.emit.call_deferred()
		return

	
	if change < 0:
		_flash_colour(Color(1.5,.5,.5))
	else:
		_flash_colour(Color(.5,1.5,.5))

	var tween = _jump()
	tween.finished.connect(func(): animation_completed.emit(), CONNECT_ONE_SHOT)

func _handle_sta_change(old_val: float, new_val: float) -> void:
	print("%s STA: %.1f → %.1f" % [_debug_id, old_val, new_val])
	_update_info_label()
	# No animation, emit on next frame so await can set up listener
	animation_completed.emit.call_deferred()

func _handle_org_change(old_val: float, new_val: float) -> void:
	print("%s ORG: %.1f → %.1f" % [_debug_id, old_val, new_val])
	_update_info_label()
	# Could show morale indicator
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
