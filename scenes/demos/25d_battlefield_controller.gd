extends Node3D

## Controller for 2.5D Battlefield
## Manages the battlefield ground mesh and dynamic unit positioning

# Configuration
const BATTLEFIELD_WIDTH: float = 16.0
const BATTLEFIELD_DEPTH: float = 12.0
const BATTLEFIELD_HEIGHT: float = 0.5

const ROW_SPACING: float = 2.5  # Distance between front/middle/back rows
const UNIT_SPACING: float = 3  # Distance between units in same row
const UNIT_HEIGHT_OFFSET: float = 0.26  # Height above ground (half of battlefield height + small margin)

# Team colors
const ATTACKER_COLOR: Color = Color(0.3, 0.6, 1.0)  # Blue tint
const DEFENDER_COLOR: Color = Color(1.0, 0.4, 0.3)  # Red tint

# Preload placeholder sprite
const PLACEHOLDER_TEXTURE = preload("res://assets/icon.svg")

# References
@onready var battlefield_ground: MeshInstance3D = $Battlefield/BattlefieldGround
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
	_create_battlefield_ground()
	_setup_test_units()

## Creates the main battlefield ground mesh (large cube/platform)
func _create_battlefield_ground() -> void:
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(BATTLEFIELD_WIDTH, BATTLEFIELD_HEIGHT, BATTLEFIELD_DEPTH)
	battlefield_ground.mesh = box_mesh
	
	# Create material for the ground
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.25, 0.2)  # Brown-ish ground
	material.roughness = 0.8
	battlefield_ground.material_override = material
	
	# Position ground at origin
	battlefield_ground.position = Vector3(0, -BATTLEFIELD_HEIGHT / 2.0, 0)
	
	print("[Battlefield] Ground created: %.1fx%.1fx%.1f" % [BATTLEFIELD_WIDTH, BATTLEFIELD_HEIGHT, BATTLEFIELD_DEPTH])

## Add a unit sprite to a specific row
## row_node: The Node3D for the row (front/middle/back)
## unit_index: Position index in the row (0, 1, 2, ...)
## unit_name: Name for the unit
func add_unit_to_row(row_node: Node3D, unit_index: int, unit_name: String = "Unit") -> Sprite3D:
	var sprite = Sprite3D.new()
	sprite.name = "%s_%d" % [unit_name, unit_index]
	sprite.texture = PLACEHOLDER_TEXTURE
	sprite.pixel_size = 0.01  # Scale down the sprite
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.shaded = true
	
	# Apply team color tint based on which side the row belongs to
	sprite.modulate = _get_team_color_for_row(row_node)
	
	# Position calculation: center units around origin, spread horizontally
	var x_position = _calculate_unit_x_position(unit_index)
	sprite.position = Vector3(x_position, UNIT_HEIGHT_OFFSET, 0)
	
	row_node.add_child(sprite)
	print("[Battlefield] Added %s at row '%s', index %d, x=%.2f" % [unit_name, row_node.name, unit_index, x_position])
	
	return sprite

## Calculate X position for a unit based on its index in the row
## Centers units around X=0, spreading them evenly
func _calculate_unit_x_position(unit_index: int) -> float:
	# For even distribution: offset from center
	# Example: 3 units -> [-1.2, 0, 1.2]
	# Example: 4 units -> [-1.8, -0.6, 0.6, 1.8]
	return (unit_index * UNIT_SPACING) - ((unit_index / 2.0) * UNIT_SPACING)

## Determine team color based on which side the row belongs to
func _get_team_color_for_row(row_node: Node3D) -> Color:
	# Check if row is under AttackerSide or DefenderSide
	var parent = row_node.get_parent()
	if parent and parent.name == "AttackerSide":
		return ATTACKER_COLOR
	elif parent and parent.name == "DefenderSide":
		return DEFENDER_COLOR
	else:
		return Color.WHITE  # Default if no side found

## Update positions of all units in a row (call when units are added/removed)
func update_row_positions(row_node: Node3D) -> void:
	var children = row_node.get_children()
	for i in range(children.size()):
		if children[i] is Sprite3D:
			var new_x = _calculate_unit_x_position(i)
			children[i].position.x = new_x
	
	print("[Battlefield] Updated %d units in row '%s'" % [children.size(), row_node.name])

## Add multiple units to a row at once
func add_units_to_row(row_node: Node3D, count: int, base_name: String = "Unit") -> void:
	for i in range(count):
		add_unit_to_row(row_node, i, base_name)

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
	attacker_portrait.texture = PLACEHOLDER_TEXTURE
	attacker_tactic.texture = PLACEHOLDER_TEXTURE
	defender_portrait.texture = PLACEHOLDER_TEXTURE
	defender_tactic.texture = PLACEHOLDER_TEXTURE

## Clear all units from a row
func clear_row(row_node: Node3D) -> void:
	for child in row_node.get_children():
		child.queue_free()

## Example: Add a unit dynamically during gameplay
func spawn_unit_at_row(side: String, row: String, unit_name: String = "NewUnit") -> Sprite3D:
	var row_node: Node3D
	
	match [side, row]:
		["attacker", "front"]: row_node = attacker_front
		["attacker", "middle"]: row_node = attacker_middle
		["attacker", "back"]: row_node = attacker_back
		["defender", "front"]: row_node = defender_front
		["defender", "middle"]: row_node = defender_middle
		["defender", "back"]: row_node = defender_back
		_:
			push_error("Invalid side/row: %s/%s" % [side, row])
			return null
	
	var current_count = row_node.get_child_count()
	var sprite = add_unit_to_row(row_node, current_count, unit_name)
	update_row_positions(row_node)
	
	return sprite

## Example: Remove a unit from a row by index
func remove_unit_from_row(row_node: Node3D, unit_index: int) -> void:
	if unit_index < 0 or unit_index >= row_node.get_child_count():
		push_error("Invalid unit index: %d" % unit_index)
		return
	
	var unit = row_node.get_child(unit_index)
	row_node.remove_child(unit)
	unit.queue_free()
	
	update_row_positions(row_node)

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
