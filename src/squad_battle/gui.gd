extends Node2D
class_name SquadBattleGraphics

const Types = preload("res://src/squad_battle/types.gd")
const EntityDisplayScene = preload("res://scenes/entity.tscn")
const EntityDisplay = preload("res://src/squad_battle/entity_display.gd")

var battle: SquadBattle

# Maps player_id -> EntityDisplay node
# This allows quick lookup when routing updates
var entity_displays: Dictionary = {}

# Layout configuration
const TEAM_SPACING = 600.0  # Horizontal space between teams
const SQUAD_SPACING = 300.0  # Vertical space between squads
const LOCATION_SPACING = 100.0  # Depth spacing (front/middle/back)
const ENTITY_SPACING = 80.0  # Space between entities in same position

func _init(_battle: SquadBattle) -> void:
	battle = _battle

## Called after this node is added to the scene tree
## Spawns all entity displays
func _ready() -> void:
	_spawn_all_entities()

## Spawn visual representations for all entities in the battle
func _spawn_all_entities() -> void:
	var team_index = 0
	
	for team_name in battle.teams_and_squads.keys():
		var squads: Array = battle.teams_and_squads[team_name]
		var squad_index = 0
		
		for squad: Squad in squads:
			for entity: SquadEntity in squad.entities:
				_spawn_entity_display(entity, team_name, team_index, squad_index)
			squad_index += 1
		
		team_index += 1

## Instantiate and position a single entity display
func _spawn_entity_display(entity: SquadEntity, _team_name: String, team_index: int, squad_index: int) -> void:
	var display: EntityDisplay = EntityDisplayScene.instantiate()
	
	# Calculate position based on team, squad, and location
	display.position = _calculate_position(entity, team_index, squad_index)
	
	# Add to scene first (so nodes are ready)
	add_child(display)
	
	# Then setup with data
	display.setup(entity)
	
	# Store reference for later updates
	entity_displays[entity.player_id] = display
	
	print("Spawned display for entity: ", entity.entity_name, " at ", display.position)

## Calculate screen position for an entity based on its team, squad, and location
func _calculate_position(entity: SquadEntity, team_index: int, squad_index: int) -> Vector2:
	var pos = Vector2()
	
	# Team determines horizontal side (left vs right)
	# Team 0 on left, Team 1 on right
	pos.x = 200.0 + (team_index * TEAM_SPACING)
	
	# Squad determines vertical row
	pos.y = 200.0 + (squad_index * SQUAD_SPACING)
	
	# Location within squad (Front/Middle/Back) affects depth
	var location = entity.get_changeable_stat_num(Types.EntityChangeable.LOC) as int
	pos.x += (location - 1) * LOCATION_SPACING  # Front is closer to center
	
	# Add some offset based on entity index to prevent overlap
	# (In a real game, you'd track how many entities are at this position)
	pos.y += (entity.player_id % 3) * ENTITY_SPACING
	
	return pos

## Route a stat change to the appropriate entity display
func _handle_hp_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " HP changed from ", change.from, " to ", change.to)
	
	# Route to visual display
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.HP, change.from, change.to)

func _handle_sta_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " STA changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.STA, change.from, change.to)

func _handle_org_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " ORG changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.ORG, change.from, change.to)

func _handle_pos_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " POS changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.POS, change.from, change.to)

func _handle_mag_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " MAG changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.MAG, change.from, change.to)

func _handle_loc_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " LOC changed from ", change.from, " to ", change.to)
	
	# Update visual position when location changes
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.LOC, change.from, change.to)
		# TODO: Could update display.position here for visual movement

func _handle_die_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " DIE changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.DIE, change.from, change.to)

func _handle_capitulate_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " CAPITULATE changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.CAPITULATE, change.from, change.to)

func _handle_clink_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " CLINK changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.CLINK, change.from, change.to)

func _handle_dodge_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " DODGE changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.DODGE, change.from, change.to)

func _handle_proc_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " PROC changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.PROC, change.from, change.to)

func process_updates(updates: Array[Types.EntityUpdate]) -> void:
	for update in updates:
		var change: Types.EntityChange = update.change
		match change.property:
			Types.EntityChangeable.HP:
				_handle_hp_change(update)
			Types.EntityChangeable.STA:
				_handle_sta_change(update)
			Types.EntityChangeable.ORG:
				_handle_org_change(update)
			Types.EntityChangeable.POS:
				_handle_pos_change(update)
			Types.EntityChangeable.MAG:
				_handle_mag_change(update)
			Types.EntityChangeable.LOC:
				_handle_loc_change(update)
			Types.EntityChangeable.DIE:
				_handle_die_change(update)
			Types.EntityChangeable.CAPITULATE:
				_handle_capitulate_change(update)
			Types.EntityChangeable.CLINK:
				_handle_clink_change(update)
			Types.EntityChangeable.DODGE:
				_handle_dodge_change(update)
			Types.EntityChangeable.PROC:
				_handle_proc_change(update)
			_:
				assert(false, "Unhandled EntityChangeable type in GUI: " % change.property)

			
			
