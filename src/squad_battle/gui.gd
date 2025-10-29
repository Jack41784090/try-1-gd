class_name SquadBattleGraphicsNode extends Node2D

const Types = preload("res://src/squad_battle/types.gd")
const EntityDisplayScene = preload("res://scenes/entity.tscn")

var battle: SquadBattle

var entity_displays: Dictionary = {}

const TEAM_SPACING = 600.0
const SQUAD_SPACING = 300.0
const LOCATION_SPACING = 100.0
const ENTITY_SPACING = 80.0

const WAIT_SEC_BETWEEN_ANIMATION: float = .1

func _init(_battle: SquadBattle) -> void:
	battle = _battle
	print("[GUI] Initialized with battle. Teams: ", battle.teams_and_squads.keys())

func _ready() -> void:
	print("[GUI] _ready() called - starting entity spawn")
	_spawn_all_entities()
	print("[GUI] Entity spawn complete. Total displays: ", entity_displays.size())

func _spawn_all_entities() -> void:
	print("[GUI] Spawning entities from battle data...")
	var team_index = 0
	
	for team_name in battle.teams_and_squads.keys():
		var squads: Array = battle.teams_and_squads[team_name]
		print("[GUI]   Team '%s' (index %d): %d squads" % [team_name, team_index, squads.size()])
		var squad_index = 0
		
		for squad: Squad in squads:
			print("[GUI]     Squad '%s' (index %d): %d entities" % [squad.squad_name, squad_index, squad.entities.size()])
			for entity: SquadEntity in squad.entities:
				_spawn_entity_display(entity, team_name, team_index, squad_index)
			squad_index += 1
		
		team_index += 1

func _spawn_entity_display(entity: SquadEntity, _team_name: String, team_index: int, squad_index: int) -> void:
	print("[GUI]       Spawning '%s' (ID:%d) at team_idx=%d, squad_idx=%d" % [entity.entity_name, entity.player_id, team_index, squad_index])
	var display: EntityDisplay = EntityDisplayScene.instantiate()
	
	display.position = _calculate_position(entity, team_index, squad_index)
	print("[GUI]       Position calculated: ", display.position)
	
	add_child(display)
	
	display.setup(entity)
	entity_displays[entity.player_id] = display
	
	print("[GUI]       ✓ Display added to tree and setup complete")

func _calculate_position(entity: SquadEntity, team_index: int, squad_index: int) -> Vector2:
	var pos = Vector2()
	pos.x = 200.0 + (team_index * TEAM_SPACING)
	pos.y = 200.0 + (squad_index * SQUAD_SPACING)
	var location = entity.get_changeable_stat_num(Types.EntityChangeable.LOC) as int
	pos.x += (location - 1) * LOCATION_SPACING
	pos.y += (entity.player_id % 3) * ENTITY_SPACING
	return pos

## Update an entity's position when their LOC changes
## Finds the entity in the battle data and recalculates position
func _update_entity_position(player_id: int) -> void:
	print("[GUI] Updating position for entity ID %d" % player_id)
	var display = entity_displays.get(player_id)
	if not display:
		print("[GUI]   ⚠️ Display not found in entity_displays!")
		return
	
	# Find the entity's team and squad indices
	var team_index = 0
	for team_name in battle.teams_and_squads.keys():
		var squads: Array = battle.teams_and_squads[team_name]
		var squad_index = 0
		
		for squad: Squad in squads:
			for entity: SquadEntity in squad.entities:
				if entity.player_id == player_id:
					# Found it! Calculate new position and animate
					var old_pos = display.position
					var new_pos = _calculate_position(entity, team_index, squad_index)
					print("[GUI]   Moving from %s to %s" % [old_pos, new_pos])
					_animate_position_change(display, new_pos)
					return
			squad_index += 1
		team_index += 1
	
	print("[GUI]   ⚠️ Entity ID %d not found in battle data!" % player_id)

## Smoothly animate an entity display to a new position
func _animate_position_change(display: EntityDisplay, new_position: Vector2) -> void:
	print("[GUI]   Animating position change over " % str(WAIT_SEC_BETWEEN_ANIMATION) % " seconds")
	var tween = create_tween()
	tween.tween_property(display, "position", new_position, WAIT_SEC_BETWEEN_ANIMATION).set_ease(Tween.EASE_IN_OUT)

# region _handle helpers (deprecated)
func _handle_hp_change(update: Types.EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " HP changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.HP, change.from, change.to)

func _handle_sta_change(update: EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " STA changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.STA, change.from, change.to)

func _handle_org_change(update: EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " ORG changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.ORG, change.from, change.to)

func _handle_pos_change(update: EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " POS changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.POS, change.from, change.to)

func _handle_mag_change(update: EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " MAG changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.MAG, change.from, change.to)

func _handle_loc_change(update: EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " LOC changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.LOC, change.from, change.to)
		_update_entity_position(update.affected)

func _handle_die_change(update: EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " DIE changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.DIE, change.from, change.to)

func _handle_capitulate_change(update: EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " CAPITULATE changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.CAPITULATE, change.from, change.to)

func _handle_clink_change(update: EntityUpdate) -> void:
	var change: Types.EntityChange = update.change
	print("Entity ", update.affected, " CLINK changed from ", change.from, " to ", change.to)
	
	var display = entity_displays.get(update.affected)
	if display:
		display.update_stat(Types.EntityChangeable.CLINK, change.from, change.to)

func _handle_dodge_change(update: EntityUpdate) -> void:
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
# endregion

func process_updates(updates: Array[Types.EntityUpdate]) -> void:
	if updates.size() > 0:
		print("[GUI] Processing %d updates..." % updates.size())
	
	for update in updates:
		var display = entity_displays.get(update.affected)
		if display: display.update_stat(update.change.property, update.change.from, update.change.to)
		if update.change.property == Types.EntityChangeable.LOC: _update_entity_position(update.affected)
		await get_tree().create_timer(WAIT_SEC_BETWEEN_ANIMATION).timeout
