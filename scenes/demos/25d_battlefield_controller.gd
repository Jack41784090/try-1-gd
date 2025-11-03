extends Node3D
## Controller for 2.5D Battlefield
## Manages the battlefield ground mesh and dynamic unit positioning

# Configuration - Battlefield fills screen
const BATTLEFIELD_WIDTH: float = 20.0 # Horizontal span (left-right)
const BATTLEFIELD_DEPTH: float = 14.0 # Vertical span (front-back in Z)
const BATTLEFIELD_HEIGHT: float = 0.5

const ROW_SPACING: float = 2.5 # Distance between front/middle/back rows (now X-axis)
const BASE_UNIT_SPACING: float = 1.75 # Base spacing between units
const UNIT_HEIGHT_OFFSET: float = 1 # Height above ground
const UNIT_PIXEL_SIZE: float = 0.0125 # Sprite scale - smaller number = BIGGER sprites

# Team colors
const ATTACKER_COLOR: Color = Color(0.3, 0.6, 1.0) # Blue tint
const DEFENDER_COLOR: Color = Color(1.0, 0.4, 0.3) # Red tint

# Preload placeholder sprite
const PLACEHOLDER_TEXTURE = preload("res://assets/icon.svg")

# References
@onready var battlefield_ground: MeshInstance3D = $Battlefield/BattlefieldGround
@onready var background_3d: Sprite3D = $Background3D
@onready var attacker_front: Node3D = $Battlefield/AttackerSide/FrontRow
@onready var attacker_middle: Node3D = $Battlefield/AttackerSide/MiddleRow
@onready var attacker_back: Node3D = $Battlefield/AttackerSide/BackRow
@onready var defender_front: Node3D = $Battlefield/DefenderSide/FrontRow
@onready var defender_middle: Node3D = $Battlefield/DefenderSide/MiddleRow
@onready var defender_back: Node3D = $Battlefield/DefenderSide/BackRow

# UI References
@onready var attacker_portrait: TextureRect = $UILayer/TopBar/AttackerPanel/AttackerPortrait
@onready var attacker_tactic: TextureRect = $UILayer/TopBar/AttackerPanel/AttackerTactic
@onready var defender_portrait: TextureRect = $UILayer/TopBar/DefenderPanel/DefenderPortrait
@onready var defender_tactic: TextureRect = $UILayer/TopBar/DefenderPanel/DefenderTactic


func _ready() -> void:
	# Don't setup test units by default - let the demo script handle it
	# Uncomment to see test units in editor:
	# _setup_test_units()
	pass

## Add a unit sprite to a specific row
## row_node: The Node3D for the row (front/middle/back)
## unit_index: Position index in the row (0, 1, 2, ...)
## unit_name: Name for the unit
## entity: Optional SquadEntity data for full EntityDisplay setup
func add_unit_to_row(row_node: Node3D, unit_index: int, unit_name: String = "Unit", entity: SquadEntity = null) -> Node3D:
	if entity:
		# Use EntityDisplay for full animation support
		var display = EntityDisplay.new()
		display.name = "%s_%d" % [unit_name, unit_index]
		
		var team_color = _get_team_color_for_row(row_node)
		display.setup_programmatic(entity, PLACEHOLDER_TEXTURE, team_color, UNIT_PIXEL_SIZE)
		display.position = Vector3(0, UNIT_HEIGHT_OFFSET, 0)
		
		row_node.add_child(display)
		print("[Battlefield] Added EntityDisplay %s at row '%s', index %d" % [unit_name, row_node.name, unit_index])
		
		return display
	else:
		# Fallback: Create simple Sprite3D (for test units without entity data)
		var sprite = Sprite3D.new()
		sprite.name = "%s_%d" % [unit_name, unit_index]
		sprite.texture = PLACEHOLDER_TEXTURE
		sprite.pixel_size = UNIT_PIXEL_SIZE # Scale based on battlefield size
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = true
		sprite.scale = Vector3(1,1,1) # Uniform scale

		# Apply team color tint based on which side the row belongs to
		sprite.modulate = _get_team_color_for_row(row_node)

		# Position will be set by update_row_positions
		sprite.position = Vector3(0, UNIT_HEIGHT_OFFSET, 0)

		row_node.add_child(sprite)
		print("[Battlefield] Added simple Sprite3D %s at row '%s', index %d" % [unit_name, row_node.name, unit_index])

		return sprite

## Calculate Z position for a unit to center against opposing force
## This algorithm centers units based on the opposing row's unit count
func _calculate_unit_positions_for_row(row_node: Node3D, opposing_row: Node3D) -> Array[float]:
	var our_count = row_node.get_child_count()
	var their_count = opposing_row.get_child_count() if opposing_row else our_count

	if our_count == 0:
		return []

	# Calculate the span each side should cover
	# Use the maximum count to determine spread, so sides align
	var max_count = max(our_count, their_count)
	var total_spread = (max_count - 1) * BASE_UNIT_SPACING

	# Center our units within this spread
	var positions: Array[float] = []
	for i in range(our_count):
		# Distribute evenly within the available space
		var normalized_pos = float(i) / max(1, our_count - 1) if our_count > 1 else 0.5
		var z_pos = (normalized_pos * total_spread) - (total_spread / 2.0)
		positions.append(z_pos)

	return positions


## Determine team color based on which side the row belongs to
func _get_team_color_for_row(row_node: Node3D) -> Color:
	# Check if row is under AttackerSide or DefenderSide
	var parent = row_node.get_parent()
	if parent and parent.name == "AttackerSide":
		return ATTACKER_COLOR
	elif parent and parent.name == "DefenderSide":
		return DEFENDER_COLOR
	else:
		return Color.WHITE # Default if no side found


## Update positions of all units in a row (call when units are added/removed)
## Now centers units against the opposing row
func update_row_positions(row_node: Node3D) -> void:
	# Find the opposing row
	var opposing_row = _get_opposing_row(row_node)

	var positions = _calculate_unit_positions_for_row(row_node, opposing_row)
	var children = row_node.get_children()

	for i in range(children.size()):
		var child = children[i]
		if (child is Sprite3D or child is EntityDisplay) and i < positions.size():
			child.position.z = positions[i]

	print(
		"[Battlefield] Updated %d units in row '%s' (centered against %d opposing)" %
		[children.size(), row_node.name, opposing_row.get_child_count() if opposing_row else 0],
	)


## Get the opposing row for a given row (for centering algorithm)
func _get_opposing_row(row_node: Node3D) -> Node3D:
	var parent = row_node.get_parent()
	if not parent:
		return null

	var row_name = row_node.name

	# Map attacker rows to defender rows and vice versa
	if parent.name == "AttackerSide":
		match row_name:
			"FrontRow":
				return defender_front
			"MiddleRow":
				return defender_middle
			"BackRow":
				return defender_back
	elif parent.name == "DefenderSide":
		match row_name:
			"FrontRow":
				return attacker_front
			"MiddleRow":
				return attacker_middle
			"BackRow":
				return attacker_back

	return null


## Add multiple units to a row at once
func add_units_to_row(row_node: Node3D, count: int, base_name: String = "Unit") -> void:
	for i in range(count):
		add_unit_to_row(row_node, i, base_name)
	# Update positions after adding all units
	update_row_positions(row_node)
	# Also update opposing row to re-center
	var opposing = _get_opposing_row(row_node)
	if opposing:
		update_row_positions(opposing)


## Setup test units for demonstration
func _setup_test_units() -> void:
	print("[Battlefield] Setting up test units...")

	# Attacker side
	add_units_to_row(attacker_front, 5, "AttackerFront")
	add_units_to_row(attacker_middle, 4, "AttackerMid")
	add_units_to_row(attacker_back, 3, "AttackerBack")

	# Defender side
	add_units_to_row(defender_front, 4, "DefenderFront")
	add_units_to_row(defender_middle, 5, "DefenderMid")
	add_units_to_row(defender_back, 2, "DefenderBack")

	# Setup UI placeholders
	# attacker_portrait.texture = PLACEHOLDER_TEXTURE
	# attacker_tactic.texture = PLACEHOLDER_TEXTURE
	# defender_portrait.texture = PLACEHOLDER_TEXTURE
	# defender_tactic.texture = PLACEHOLDER_TEXTURE

## NOTE: Background and battlefield ground are now configured directly in the scene file
## for preview purposes. No runtime generation needed.


## Clear all units from a row
func clear_row(row_node: Node3D) -> void:
	for child in row_node.get_children():
		child.queue_free()


## Example: Add a unit dynamically during gameplay
func spawn_unit_at_row(side: String, row: String, unit_name: String = "NewUnit", entity: SquadEntity = null) -> Node3D:
	var row_node: Node3D

	match [side, row]:
		["attacker", "front"]:
			row_node = attacker_front
		["attacker", "middle"]:
			row_node = attacker_middle
		["attacker", "back"]:
			row_node = attacker_back
		["defender", "front"]:
			row_node = defender_front
		["defender", "middle"]:
			row_node = defender_middle
		["defender", "back"]:
			row_node = defender_back
		_:
			push_error("Invalid side/row: %s/%s" % [side, row])
			return null

	var current_count = row_node.get_child_count()
	var unit = add_unit_to_row(row_node, current_count, unit_name, entity)
	update_row_positions(row_node)

	# Update opposing row to re-center
	var opposing = _get_opposing_row(row_node)
	if opposing:
		update_row_positions(opposing)

	return unit


## Example: Remove a unit from a row by index
func remove_unit_from_row(row_node: Node3D, unit_index: int) -> void:
	if unit_index < 0 or unit_index >= row_node.get_child_count():
		push_error("Invalid unit index: %d" % unit_index)
		return

	var unit = row_node.get_child(unit_index)
	row_node.remove_child(unit)
	unit.queue_free()

	update_row_positions(row_node)

	# Update opposing row to re-center
	var opposing = _get_opposing_row(row_node)
	if opposing:
		update_row_positions(opposing)


## Set general portraits and tactics
func set_general_info(side: String, general_texture: Texture2D, tactic_texture: Texture2D, general_name: String = "", tactic_name: String = "") -> void:
	if side == "attacker":
		attacker_portrait.texture = general_texture
		attacker_tactic.texture = tactic_texture
		if general_name != "":
			$UILayer/TopBar/AttackerPanel/AttackerInfo/GeneralName.text = general_name
		if tactic_name != "":
			$UILayer/TopBar/AttackerPanel/AttackerInfo/TacticName.text = "Tactic: " + tactic_name
	elif side == "defender":
		defender_portrait.texture = general_texture
		defender_tactic.texture = tactic_texture
		if general_name != "":
			$UILayer/TopBar/DefenderPanel/DefenderInfo/GeneralName.text = general_name
		if tactic_name != "":
			$UILayer/TopBar/DefenderPanel/DefenderInfo/TacticName.text = "Tactic: " + tactic_name


## Input handler for testing dynamic unit addition
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				spawn_unit_at_row("attacker", "front")
			KEY_2:
				spawn_unit_at_row("attacker", "middle")
			KEY_3:
				spawn_unit_at_row("attacker", "back")
			KEY_4:
				spawn_unit_at_row("defender", "front")
			KEY_5:
				spawn_unit_at_row("defender", "middle")
			KEY_6:
				spawn_unit_at_row("defender", "back")
			KEY_C:
				clear_row(attacker_front)
				clear_row(attacker_middle)
				clear_row(attacker_back)
				clear_row(defender_front)
				clear_row(defender_middle)
				clear_row(defender_back)
				print("[Battlefield] All rows cleared")
