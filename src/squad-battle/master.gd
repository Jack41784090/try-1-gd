extends Node3D

var config: Dictionary
var battle: SquadBattle
var battlefield_controller: SBGraphics
var entity_displays_dict: Dictionary = {}
var delay_between_rounds: float = 2.0
var max_rounds: int = 50
var is_running: bool = false
var last_round_capitulated: Array = []
var all_updates: Array[EntityUpdate] = []

signal battle_completed

func _ready() -> void:
	battlefield_controller = get_node("25dBattlefield")

	setup_row_mappings()
	if battle == null:
		if config == null:
			setup_mock_battle()
		else:
			battle = SquadBattle.new(config)
	spawn_all_entities()
	is_running = true

	SBLog.section("Squad Battle Started!", 0, 2, 1)
	await get_tree().create_timer(1.0).timeout
	process_round()

func setup_row_mappings() -> void:
	var attacker_rows = {
		SquadBattleTypes.SquadEntityInSquadLocation.Front: battlefield_controller.attacker_front,
		SquadBattleTypes.SquadEntityInSquadLocation.Middle: battlefield_controller.attacker_middle,
		SquadBattleTypes.SquadEntityInSquadLocation.Back: battlefield_controller.attacker_back
	}

	var defender_rows = {
		SquadBattleTypes.SquadEntityInSquadLocation.Front: battlefield_controller.defender_front,
		SquadBattleTypes.SquadEntityInSquadLocation.Middle: battlefield_controller.defender_middle,
		SquadBattleTypes.SquadEntityInSquadLocation.Back: battlefield_controller.defender_back
	}

	# Store as instance variables for use in other methods
	set_meta("attacker_rows", attacker_rows)
	set_meta("defender_rows", defender_rows)

func setup_mock_battle() -> void:
	var battle_config = {
		"teams": {
			SquadBattleTypes.Side.ATTACKER: [{
				"side": SquadBattleTypes.Side.ATTACKER,
				"name": "Heroes",
				"team": "heroes",
				"entities": [
					EntityFactory.EntityClasses.Landsknecht,
					EntityFactory.EntityClasses.Landsknecht,
					EntityFactory.EntityClasses.Landsknecht,
					EntityFactory.EntityClasses.Healer
				]
			}],
			SquadBattleTypes.Side.DEFENDER: [{
				"side": SquadBattleTypes.Side.DEFENDER,
				"name": "Monsters",
				"team": "monsters",
				"entities": [
					EntityFactory.EntityClasses.Landsknecht,
					EntityFactory.EntityClasses.Landsknecht,
					EntityFactory.EntityClasses.Landsknecht,
					EntityFactory.EntityClasses.Healer
				]
			}]
		}
	}

	battle = SquadBattle.new(battle_config)

func spawn_all_entities() -> void:
	var all_rows = [
		battlefield_controller.attacker_front,
		battlefield_controller.attacker_middle,
		battlefield_controller.attacker_back,
		battlefield_controller.defender_front,
		battlefield_controller.defender_middle,
		battlefield_controller.defender_back
	]

	for row in all_rows:
		battlefield_controller.clear_row(row)

	for team_name in battle.teams_and_squads.keys():
		var squads: Array = battle.teams_and_squads[team_name]
		var is_attacker = (team_name == SquadBattleTypes.Side.ATTACKER)
		var row_map = get_meta("attacker_rows" if is_attacker else "defender_rows")

		for squad: Squad in squads:
			for entity: SquadEntity in squad.entities:
				var location = entity.get_changeable_stat_num(
					SquadBattleTypes.EntityChangeable.LOC
				) as int
				var row_node: Node3D = row_map.get(location)
				if not row_node:
					continue

				var display = battlefield_controller.add_unit_to_row(
					row_node, row_node.get_child_count(),
					entity.entity_name, entity
				)
				entity_displays_dict[entity.player_id] = display
				_update_row_positions(row_node)

func process_round() -> void:
	if battle.check_victory() or battle.round_count >= max_rounds:
		var end_message = "BATTLE ENDED" if battle.check_victory() else "MAX ROUNDS REACHED (DRAW)"
		SBLog.section(end_message, 0, 2, 1)
		print_winner()
		is_running = false
		battle_completed.emit()
		return

	SBLog.section("Round %d" % (battle.round_count + 1), 1, 1, 1)
	battle.round_count += 1

	battle.remove_dead_entities()
	battle.remove_capitulated_entities(last_round_capitulated)
	last_round_capitulated.clear()

	var updates = battle.squad_actions()
	for update in updates:
		all_updates.append(update)
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
	print("[process_updates] Starting to process %d updates" % updates.size())
	for update in updates:
		print("[process_updates] Processing update: source=%d affected=%d property=%s" % [
			update.source, update.affected, update.change.property
		])
		var attackers_display = entity_displays_dict.get(update.source) as EntityDisplay
		var targets_display = entity_displays_dict.get(update.affected) as EntityDisplay

		if not targets_display:
			push_warning("No display found for entity %d" % update.affected)
			continue

		var change_type = update.change.property
		var hp_changed = change_type == SquadBattleTypes.EntityChangeable.HP
		var took_damage = update.change.to < update.change.from

		if hp_changed:
			attackers_display.switch_sprite("attack")
			await battlefield_controller.animate_attack_lunge(attackers_display)
			if took_damage:
				targets_display.switch_sprite("defend")
				battlefield_controller.animate_attack_recoil(targets_display)
				battlefield_controller.animate_attack_recoil(attackers_display)
		elif change_type == SquadBattleTypes.EntityChangeable.CLINK:
			attackers_display.switch_sprite("attack")
			targets_display.switch_sprite("defend")
			await battlefield_controller.animate_attack_lunge(attackers_display)
			battlefield_controller.animate_clink(targets_display)

		print("[process_updates] Setting up await for entity %d" % update.affected)
		var animation_task = targets_display.animation_completed
		targets_display.update_stat(update.change.property, update.change.from, update.change.to)

		print("[process_updates] Awaiting animation_completed for entity %d" % update.affected)
		await animation_task
		print("[process_updates] Animation completed for entity %d" % update.affected)


		attackers_display.switch_sprite("idle")
		targets_display.switch_sprite("idle")

		if change_type == SquadBattleTypes.EntityChangeable.DIE:
			targets_display.visible = false
			targets_display.queue_free()
			entity_displays_dict.erase(update.affected)
		elif change_type == SquadBattleTypes.EntityChangeable.LOC:
			await _handle_location_change(update.affected, targets_display)
	
	print("[process_updates] All updates processed!")

func _update_row_positions(row_node: Node3D) -> void:
	battlefield_controller.update_row_positions(row_node)
	# Update opposing row positions to maintain proper spacing
	var all_rows = [
		battlefield_controller.attacker_front,
		battlefield_controller.attacker_middle,
		battlefield_controller.attacker_back,
		battlefield_controller.defender_front,
		battlefield_controller.defender_middle,
		battlefield_controller.defender_back
	]

	var current_index = all_rows.find(row_node)
	if current_index == -1:
		return

	# Find opposing row (attacker rows oppose defender rows in reverse order)
	var opposing_index = -1
	if current_index < 3:  # Attacker side
		opposing_index = 5 - current_index  # Front-Back, Middle-Middle, Back-Front
	else:  # Defender side
		opposing_index = 2 - (current_index - 3)  # Same logic

	if opposing_index >= 0 and opposing_index < all_rows.size():
		battlefield_controller.update_row_positions(all_rows[opposing_index])

func _handle_location_change(entity_id: int, display: Node3D) -> void:
	var entity = battle.get_entity_by_id(entity_id)
	if not entity or not display:
		print("[LOC] Entity or display is null for ID %d" % entity_id)
		return

	var new_location = entity.get_changeable_stat_num(
		SquadBattleTypes.EntityChangeable.LOC
	) as int

	print("[LOC] Entity %d moving to location %d" % [entity_id, new_location])

	var is_attacker = (entity.team == "heroes")
	var row_map = get_meta("attacker_rows" if is_attacker else "defender_rows")
	var new_row = row_map.get(new_location)

	if new_row and display.get_parent() != new_row:
		print("[LOC] Animating move to new row")
		await battlefield_controller.animate_move_to_row(display, new_row)
		print("[LOC] Move animation completed")
	else:
		print("[LOC] No move needed (already in correct row or invalid row)")

func print_winner() -> void:
	for team_name in battle.teams_and_squads:
		var strength = battle.check_team_strength(team_name)
		if strength > 0:
			print("🏆 WINNER: Team %s with strength %.1f" % [team_name.to_upper(), strength])
