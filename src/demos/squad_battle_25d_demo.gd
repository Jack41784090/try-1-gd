extends Node3D

var battle: SquadBattle
var battlefield_controller: d25BattlefieldController
var entity_displays_dict: Dictionary = {}
var delay_between_rounds: float = 2.0
var is_running: bool = false
var last_round_capitulated: Array = []
var attacker_rows: Dictionary = {}
var defender_rows: Dictionary = {}

func _ready() -> void:
	battlefield_controller = get_node("25dBattlefield")
	if not battlefield_controller:
		push_error("Could not find 25dBattlefield node!")
		return
	
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
	# var squad1_config = {
	# 	"name": "Heroes Squad",
	# 	"team": "heroes",
	# 	"entities": [
	# 		{"player_id": 1, "name": "Sir Galahad", "stats": EntityBaseStats.new(), "team": "heroes", "starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front, "logic_type": "frontline"},
	# 		{"player_id": 2, "name": "Sir Lancelot", "stats": EntityBaseStats.new(), "team": "heroes", "starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front, "logic_type": "frontline"},
	# 		{"player_id": 3, "name": "Sir Percival", "stats": EntityBaseStats.new(), "team": "heroes", "starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Middle, "logic_type": "frontline"},
	# 		{"player_id": 4, "name": "Sir Gawain", "stats": EntityBaseStats.new(), "team": "heroes", "starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Back, "logic_type": "archer"}
	# 	]
	# }
	
	# var squad2_config = {
	# 	"name": "Goblins",
	# 	"team": "monsters",
	# 	"entities": [
	# 		{"player_id": 5, "name": "Grubnak", "stats": EntityBaseStats.new(), "team": "monsters", "starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front, "logic_type": "default"},
	# 		{"player_id": 6, "name": "Snaggletooth", "stats": EntityBaseStats.new(), "team": "monsters", "starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front, "logic_type": "default"},
	# 		{"player_id": 7, "name": "Blightfang", "stats": EntityBaseStats.new(), "team": "monsters", "starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Middle, "logic_type": "frontline"},
	# 		{"player_id": 8, "name": "Rotclaw", "stats": EntityBaseStats.new(), "team": "monsters", "starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Back, "logic_type": "archer"}
	# 	]
	# }
	
	# var battle_config = {"teams": {"heroes": [squad1_config], "monsters": [squad2_config]}}
	
	var battle_config = {
		"teams": {
			"heroes": [
				{
					"name": "Heroes",
					"team": "heroes",
					"entities": [EntityFactory.EntityClasses.Landsknecht, EntityFactory.EntityClasses.Landsknecht, EntityFactory.EntityClasses.Landsknecht, EntityFactory.EntityClasses.Healer]
				}
			],
			"monsters": [
				{
					"name": "Monsters",
					"team": "monsters",
					"entities": [EntityFactory.EntityClasses.Landsknecht, EntityFactory.EntityClasses.Landsknecht, EntityFactory.EntityClasses.Landsknecht, EntityFactory.EntityClasses.Healer]
				}
			]
		}
	}
	
	battle = SquadBattle.new(battle_config)

func spawn_all_entities() -> void:
	for row in [battlefield_controller.attacker_front, battlefield_controller.attacker_middle, battlefield_controller.attacker_back, 
				battlefield_controller.defender_front, battlefield_controller.defender_middle, battlefield_controller.defender_back]:
		battlefield_controller.clear_row(row)
	
	for team_name in battle.teams_and_squads.keys():
		var squads: Array = battle.teams_and_squads[team_name]
		var is_attacker = (team_name == "heroes")
		for squad: Squad in squads:
			for entity: SquadEntity in squad.entities:
				var location = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
				var row_map = attacker_rows if is_attacker else defender_rows
				var row_node: Node3D = row_map.get(location)
				if row_node:
					var display = battlefield_controller.add_unit_to_row(row_node, row_node.get_child_count(), entity.entity_name, entity)
					entity_displays_dict[entity.player_id] = display
					battlefield_controller.update_row_positions(row_node)
					var opposing = battlefield_controller._get_opposing_row(row_node)
					if opposing:
						battlefield_controller.update_row_positions(opposing)

func process_round() -> void:
	if battle.check_victory() or battle.round_count >= 50:
		SBLog.section("BATTLE ENDED" if battle.check_victory() else "MAX ROUNDS REACHED", 0, 2, 1)
		print_winner()
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
	await process_updates(updates)
	await battlefield_controller.animate_return_all_to_positions()
	await get_tree().create_timer(delay_between_rounds).timeout
	process_round()

func process_updates(updates: Array[EntityUpdate]) -> void:
	for update in updates:
		var display = entity_displays_dict.get(update.affected)
		if not display:
			continue
		
		display.update_stat(update.change.property, update.change.from, update.change.to)
		
		if update.change.property == SquadBattleTypes.EntityChangeable.HP and update.change.to < update.change.from:
			battlefield_controller.animate_attack_recoil(display)
			var attacker_display = entity_displays_dict.get(update.source)
			if attacker_display:
				battlefield_controller.animate_attack_lunge(attacker_display)
		
		await display.animation_completed
		
		if update.change.property == SquadBattleTypes.EntityChangeable.DIE:
			display.visible = false
			display.queue_free()
			entity_displays_dict.erase(update.affected)
		elif update.change.property == SquadBattleTypes.EntityChangeable.LOC:
			var entity = battle.get_entity_by_id(update.affected)
			if entity and display:
				var new_location = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
				var is_attacker = (entity.team == "heroes")
				var row_map = attacker_rows if is_attacker else defender_rows
				var new_row = row_map.get(new_location)
				if new_row and display.get_parent() != new_row:
					await battlefield_controller.animate_move_to_row(display, new_row)

func print_winner():
	for team_name in battle.teams_and_squads:
		var strength = battle.check_team_strength(team_name)
		if strength > 0:
			print("🏆 WINNER: Team %s with strength %.1f" % [team_name.to_upper(), strength])
