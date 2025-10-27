extends Node2D

const Types = preload("res://src/squad_battle/types.gd")

var gui: SquadBattleGraphics
var battle: SquadBattle
var delay_between_rounds: float = 2.0
var current_round_timer: float = 0.0
var is_running: bool = false
var last_round_capitulated: Array = []

@onready var label: Label = $UILayer/InfoLabel

func _ready() -> void:
	setup_battle()
	is_running = true
	print("Squad Battle Demo Started!")

func setup_battle():
	var entity_stats1 = Types.EntityBaseStats.new("warrior1", 15, 12, 10, 10, 12, 8, 8, 10, 9, 8, 12, 14)
	var entity_stats2 = Types.EntityBaseStats.new("warrior2", 14, 11, 9, 11, 11, 9, 7, 9, 8, 9, 11, 13)
	var entity_stats3 = Types.EntityBaseStats.new("mage1", 8, 10, 8, 9, 9, 16, 14, 12, 10, 11, 13, 10)
	
	var entity_stats4 = Types.EntityBaseStats.new("goblin1", 12, 10, 11, 12, 10, 6, 6, 7, 6, 7, 9, 11)
	var entity_stats5 = Types.EntityBaseStats.new("goblin2", 11, 9, 10, 11, 9, 6, 5, 6, 7, 6, 8, 10)
	
	var squad1_config = {
		"name": "Heroes Front",
		"team": "heroes",
		"entities": [
			{
				"player_id": 1,
				"name": "Sir Galahad",
				"stats": entity_stats1,
				"team": "heroes",
				"starting_location": Types.SquadEntityInSquadLocation.Front,
				"logic_type": "frontline"
			},
			{
				"player_id": 2,
				"name": "Sir Lancelot",
				"stats": entity_stats2,
				"team": "heroes",
				"starting_location": Types.SquadEntityInSquadLocation.Front,
				"logic_type": "frontline"
			}
		]
	}
	
	var squad2_config = {
		"name": "Heroes Back",
		"team": "heroes",
		"entities": [
			{
				"player_id": 3,
				"name": "Merlin",
				"stats": entity_stats3,
				"team": "heroes",
				"starting_location": Types.SquadEntityInSquadLocation.Back,
				"logic_type": "archer"
			}
		]
	}
	
	var squad3_config = {
		"name": "Goblins",
		"team": "monsters",
		"entities": [
			{
				"player_id": 4,
				"name": "Grubnak",
				"stats": entity_stats4,
				"team": "monsters",
				"starting_location": Types.SquadEntityInSquadLocation.Front,
				"logic_type": "default"
			},
			{
				"player_id": 5,
				"name": "Snaggletooth",
				"stats": entity_stats5,
				"team": "monsters",
				"starting_location": Types.SquadEntityInSquadLocation.Front,
				"logic_type": "default"
			}
		]
	}
	
	var battle_config = {
		"teams": {
			"heroes": [squad1_config, squad2_config],
			"monsters": [squad3_config]
		}
	}
	
	battle = SquadBattle.new(battle_config)
	gui = SquadBattleGraphics.new(battle)
	# Important: Add GUI to scene tree so it can spawn visual entities
	add_child(gui)

func _process(delta: float) -> void:
	if not is_running:
		return
	
	current_round_timer += delta
	
	if current_round_timer >= delay_between_rounds:
		current_round_timer = 0.0
		process_round()
		update_display()

func process_round():
	if battle.check_victory():
		print("=== BATTLE ENDED ===")
		print_winner()
		is_running = false
		return
	
	if battle.round_count >= 99:
		print("=== MAX ROUNDS REACHED ===")
		is_running = false
		return
	
	print("\n--- Round ", battle.round_count + 1, " ---")
	battle.round_count += 1
	
	battle.remove_dead_entities()
	battle.remove_capitulated_entities(last_round_capitulated)
	last_round_capitulated.clear()
	
	var updates = battle.squad_actions()
	
	for update in updates:
		if update.change.property == Types.EntityChangeable.CAPITULATE:
			var entity = battle.get_entity_by_id(update.affected)
			if entity:
				last_round_capitulated.append(entity)
	
	battle.squad_recoveries()

	gui.process_updates(updates)
	
	print("")

func print_winner():
	for team_name in battle.teams_and_squads:
		var strength = battle.check_team_strength(team_name)
		if strength > 0:
			print("WINNER: Team ", team_name.to_upper(), " with strength ", strength)

func update_display():
	if not label:
		return
	
	var info = "=== SQUAD BATTLE ===\n"
	info += "Round: %d\n\n" % battle.round_count
	
	for team_name in battle.teams_and_squads:
		info += "Team: %s (Strength: %.1f)\n" % [team_name.to_upper(), battle.check_team_strength(team_name)]
		
		for squad in battle.teams_and_squads[team_name]:
			info += "  Squad: %s (%d entities)\n" % [squad.squad_name, squad.entities.size()]
			
			for entity in squad.entities:
				var hp = entity.get_changeable_stat_num(Types.EntityChangeable.HP)
				var max_hp = entity.get_ceiling_changeable_stat(Types.EntityChangeable.HP)
				var org = entity.get_changeable_stat_num(Types.EntityChangeable.ORG)
				var loc = entity.get_changeable_stat_num(Types.EntityChangeable.LOC)
				info += "    - %s: HP %.0f/%.0f, ORG %.0f, LOC %d\n" % [entity.entity_name, hp, max_hp, org, loc]
		
		info += "\n"
	
	if not is_running:
		info += "\n=== BATTLE ENDED ===\n"
		print_winner()
	
	label.text = info
