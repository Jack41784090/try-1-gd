extends Node2D


var gui: SquadBattleGraphicsNode
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
		"name": "Heroes Front",
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
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front,
				"logic_type": "frontline"
			},
			{
				"player_id": 4,
				"name": "Sir Gawain",
				"stats": entity_stats4,
				"team": "heroes",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front,
				"logic_type": "frontline"
			}
		]
	}
	
	var squad3_config = {
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
				"team": "heroes",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front,
				"logic_type": "frontline"
			},
			{
				"player_id": 8,
				"name": "Snaggletooth2",
				"stats": entity_stats8,
				"team": "heroes",
				"starting_location": SquadBattleTypes.SquadEntityInSquadLocation.Front,
				"logic_type": "frontline"
			}
		]
	}
	
	var battle_config = {
		"teams": {
			"heroes": [squad1_config],
			"monsters": [squad3_config]
		}
	}
	
	battle = SquadBattle.new(battle_config)
	gui = SquadBattleGraphicsNode.new(battle)
	add_child(gui)

# func _process(delta: float) -> void:
# 	if not is_running:
# 		return
	
# 	current_round_timer += delta
	
# 	if current_round_timer >= delay_between_rounds:
# 		current_round_timer = 0.0
# 		await process_round()
# 		update_display()

func process_round() -> void:
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
		if update.change.property == SquadBattleTypes.EntityChangeable.CAPITULATE:
			var entity = battle.get_entity_by_id(update.affected)
			if entity:
				last_round_capitulated.append(entity)
	
	battle.squad_recoveries()

	# Wait for all animations to complete before continuing
	await gui.process_updates(updates)
	process_round()
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
				var hp = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
				var max_hp = entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
				var org = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
				var loc = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC)
				info += "    - %s: HP %.0f/%.0f, ORG %.0f, LOC %d\n" % [entity.entity_name, hp, max_hp, org, loc]
		
		info += "\n"
	
	if not is_running:
		info += "\n=== BATTLE ENDED ===\n"
		print_winner()
	
	label.text = info
