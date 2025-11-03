extends Node3D

var battle: SquadBattle
var battlefield_controller: d25BattlefieldController
var entity_displays_dict: Dictionary = {} # Maps entity player_id to EntityDisplay
var delay_between_rounds: float = 2.0
var current_round_timer: float = 0.0
var is_running: bool = false
var last_round_capitulated: Array = []

var attacker_rows: Dictionary = {}
var defender_rows: Dictionary = {}

func _ready() -> void:
	# Get battlefield controller reference
	battlefield_controller = get_node("25dBattlefield")
	if not battlefield_controller:
		push_error("Could not find 25dBattlefield node!")
		return
	
	# Map rows
	attacker_rows = {
		SquadBattleTypes.SquadEntityInSquadLocation.Front: battlefield_controller.attacker_front,
		SquadBattleTypes.SquadEntityInSquadLocation.Middle: battlefield_controller.attacker_middle,
		SquadBattleTypes.SquadEntityInSquadLocation.Back: battlefield_controller.attacker_back
	}
	
	defender_rows = {
		SquadBattleTypes.SquadEntityInSquadLocation.Front: battlefield_controller.defender_front,
		SquadBattleTypes.SquadEntityInSquadLocation.Middle: battlefield_controller.defender_middle,
		SquadBattleTypes.SquadEntityInSquadLocation.Back: battlefield_controller.defender_back
	}
	
	setup_battle()
	spawn_all_entities()
	is_running = true
	
	SBLog.section("Squad Battle Started!", 0, 2, 1)
	await get_tree().create_timer(1.0).timeout
	process_round()

func setup_battle():
	var entity_stats1 = EntityBaseStats.new()
	var entity_stats2 = EntityBaseStats.new()
	var entity_stats3 = EntityBaseStats.new()
	var entity_stats4 = EntityBaseStats.new()
	
	var entity_stats5 = EntityBaseStats.new()
	var entity_stats6 = EntityBaseStats.new()
	var entity_stats7 = EntityBaseStats.new()
	var entity_stats8 = EntityBaseStats.new()
	
	var squad1_config = {
		"name": "Heroes Squad",
		"team": "heroes",
		"entities": [
			{
				"player_id": 1,
				"name": "Sir Galahad",
				"stats": entity_stats1,
				"team": "heroes",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front,
				"logic_type": "frontline"
			},
			{
				"player_id": 2,
				"name": "Sir Lancelot",
				"stats": entity_stats2,
				"team": "heroes",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front,
				"logic_type": "frontline"
			},
			{
				"player_id": 3,
				"name": "Sir Percival",
				"stats": entity_stats3,
				"team": "heroes",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Middle,
				"logic_type": "frontline"
			},
			{
				"player_id": 4,
				"name": "Sir Gawain",
				"stats": entity_stats4,
				"team": "heroes",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Back,
				"logic_type": "archer"
			}
		]
	}
	
	var squad2_config = {
		"name": "Goblins",
		"team": "monsters",
		"entities": [
			{
				"player_id": 5,
				"name": "Grubnak",
				"stats": entity_stats5,
				"team": "monsters",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front,
				"logic_type": "default"
			},
			{
				"player_id": 6,
				"name": "Snaggletooth",
				"stats": entity_stats6,
				"team": "monsters",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front,
				"logic_type": "default"
			},
			{
				"player_id": 7,
				"name": "Blightfang",
				"stats": entity_stats7,
				"team": "monsters",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Middle,
				"logic_type": "frontline"
			},
			{
				"player_id": 8,
				"name": "Rotclaw",
				"stats": entity_stats8,
				"team": "monsters",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Back,
				"logic_type": "archer"
			}
		]
	}
	
	var battle_config = {
		"teams": {
			"heroes": [squad1_config],
			"monsters": [squad2_config]
		}
	}
	
	battle = SquadBattle.new(battle_config)
	SBLog.line(0, "Battle initialized with %d teams" % battle.team_names.size(), SBLog.prefix("25D Demo"))

func spawn_all_entities() -> void:
	SBLog.line(1, "Spawning all entities to battlefield...", SBLog.prefix("25D Demo"))
	
	# Clear test units first
	battlefield_controller.clear_row(battlefield_controller.attacker_front)
	battlefield_controller.clear_row(battlefield_controller.attacker_middle)
	battlefield_controller.clear_row(battlefield_controller.attacker_back)
	battlefield_controller.clear_row(battlefield_controller.defender_front)
	battlefield_controller.clear_row(battlefield_controller.defender_middle)
	battlefield_controller.clear_row(battlefield_controller.defender_back)
	
	for team_name in battle.teams_and_squads.keys():
		var squads: Array = battle.teams_and_squads[team_name]
		var is_attacker = (team_name == "heroes") # Heroes are attackers (left side)
		
		for squad: Squad in squads:
			for entity: SquadEntity in squad.entities:
				spawn_entity(entity, is_attacker)
	
	
	SBLog.line(1, "All entities spawned: %d total" % entity_displays_dict.size(), SBLog.prefix("25D Demo"))

func spawn_entity(entity: SquadEntity, is_attacker: bool) -> void:
	var location = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
	var row_map = attacker_rows if is_attacker else defender_rows
	var row_node: Node3D = row_map.get(location)
	
	if not row_node:
		push_error("[25D Demo] Invalid location %d for entity %s" % [location, entity.entity_name])
		return
	
	var sprite_index = row_node.get_child_count()
	var display = battlefield_controller.add_unit_to_row(row_node, sprite_index, entity.entity_name, entity)
	
	entity_displays_dict[entity.player_id] = display
	
	# Update all row positions after adding
	battlefield_controller.update_row_positions(row_node)
	var opposing = battlefield_controller._get_opposing_row(row_node)
	if opposing:
		battlefield_controller.update_row_positions(opposing)
	
	# const SBLog = preload("res://src/utils/SBLog.gd")
	SBLog.line(2, "Spawned %s (ID:%d) at %s" % [entity.entity_name, entity.player_id, row_node.name], SBLog.prefix("25D Demo"))

func process_round() -> void:
	if battle.check_victory():
		
		SBLog.section("BATTLE ENDED", 0, 2, 1)
		print_winner()
		is_running = false
		return
	
	if battle.round_count >= 50:
		
		SBLog.section("MAX ROUNDS REACHED", 0, 2, 1)
		is_running = false
		return
	
	SBLog.section("Round %d" % (battle.round_count + 1), 1, 1, 1)
	battle.round_count += 1
	
	battle.remove_dead_entities()
	battle.remove_capitulated_entities(last_round_capitulated)
	last_round_capitulated.clear()
	
	var updates = battle.squad_actions()
	
	for update in updates:
		if update.change.property == SquadBattleTypes.EntityChangeable.CAPITULATE:
			var entity = battle.get_entity_by_id(update.affected)
			if entity:
				last_round_capitulated.append(entity)
	
	battle.squad_recoveries()
	
	# Process updates with visual feedback
	await process_updates(updates)
	
	# Wait before next round
	await get_tree().create_timer(delay_between_rounds).timeout
	
	process_round()

func process_updates(updates: Array[EntityUpdate]) -> void:
	if updates.size() > 0:
		
		SBLog.line(2, "Processing %d updates..." % updates.size(), SBLog.prefix("25D Demo"))
	
	for update in updates:
		var display = entity_displays_dict.get(update.affected)
		if not display:
			push_warning("[25D Demo] No display found for entity ID %d" % update.affected)
			continue
		
		# Use EntityDisplay's update_stat method for animations
		display.update_stat(update.change.property, update.change.from, update.change.to)
		await display.animation_completed
		
		# Clean up dead entities after animation completes
		if update.change.property == SquadBattleTypes.EntityChangeable.DIE:
			display.queue_free()
			entity_displays_dict.erase(update.affected)
		
		# Handle position changes (LOC changes) - EntityDisplay handles visual update
		# but we need to move it to the correct row if location changed
		if update.change.property == SquadBattleTypes.EntityChangeable.LOC:
			update_entity_position(update.affected)

func update_entity_position(entity_id: int) -> void:
	var entity = battle.get_entity_by_id(entity_id)
	if not entity:
		return
	
	var display = entity_displays_dict.get(entity_id)
	if not display:
		return
	
	var new_location = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
	
	# Determine which side this entity is on
	var is_attacker = (entity.team == "heroes")
	var row_map = attacker_rows if is_attacker else defender_rows
	var new_row = row_map.get(new_location)
	
	if not new_row:
		push_error("[25D Demo] Invalid new location %d for entity %s" % [new_location, entity.entity_name])
		return
	
	var current_parent = display.get_parent()
	if current_parent != new_row:
		# Move display to new row
		current_parent.remove_child(display)
		new_row.add_child(display)
		
		# Update positions in both rows
		battlefield_controller.update_row_positions(current_parent)
		battlefield_controller.update_row_positions(new_row)
		
		
		SBLog.line(2, "Moved entity %d from %s to %s" % [entity_id, current_parent.name, new_row.name], SBLog.prefix("25D Demo"))

func print_winner():
	for team_name in battle.teams_and_squads:
		var strength = battle.check_team_strength(team_name)
		if strength > 0:
			print("🏆 WINNER: Team %s with strength %.1f" % [team_name.to_upper(), strength])
