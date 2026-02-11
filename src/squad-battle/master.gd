extends Node3D

var config: Dictionary
var battle: SquadBattle
var battlefield_controller: SBGraphics
var entity_displays_dict: Dictionary = {}
var delay_between_rounds: float = 2.0
var is_running: bool = false
var last_round_capitulated: Array = []
var all_updates: Array[EntityUpdate] = []

signal battle_completed(outcome: SquadBattleTypes.BattleOutcome)

func _is_attacker(entity: CharacterCombatStats) -> bool:
	return entity.side == SquadBattleTypes.Side.ATTACKER

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

	SBLog.section("SquadCombatData Battle Started!", 0, 2, 1)
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
			SquadBattleTypes.Side.ATTACKER: [ {
				"side": SquadBattleTypes.Side.ATTACKER,
				"name": "Heroes",
				"team": "heroes",
				"entities": [
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Healer
				]
			}],
			SquadBattleTypes.Side.DEFENDER: [ {
				"side": SquadBattleTypes.Side.DEFENDER,
				"name": "Monsters",
				"team": "monsters",
				"entities": [
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Healer
				]
			}]
		},
		"attacker_tactic": Tactic.create_balanced(),
		"defender_tactic": Tactic.create_balanced()
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

		for squad: SquadCombatData in squads:
			for entity: CharacterCombatStats in squad.combat_characters:
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
	var outcome = battle.get_battle_outcome()
	if outcome != SquadBattleTypes.BattleOutcome.ONGOING:
		var outcome_name = SquadBattleTypes.BattleOutcome.keys()[outcome]
		SBLog.section("BATTLE ENDED: %s" % outcome_name, 0, 2, 1)
		print_outcome(outcome)
		is_running = false
		battle_completed.emit(outcome)
		return

	SBLog.section("Round %d / %d" % [battle.round_count + 1, battle.max_rounds], 1, 1, 1)
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
			await _handle_location_change(update.affected, targets_display, int(update.change.to))
	
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
	if current_index < 3: # Attacker side
		opposing_index = 5 - current_index # Front-Back, Middle-Middle, Back-Front
	else: # Defender side
		opposing_index = 2 - (current_index - 3) # Same logic

	if opposing_index >= 0 and opposing_index < all_rows.size():
		battlefield_controller.update_row_positions(all_rows[opposing_index])

func _handle_location_change(entity_id: int, display: Node3D, new_location: int) -> void:
	var entity = battle.get_entity_by_id(entity_id)
	if not entity or not display:
		print("[LOC] Entity or display is null for ID %d" % entity_id)
		return

	var is_attacker = _is_attacker(entity)
	print("[LOC_DEBUG] Entity %d (%s) side=%d is_attacker=%s LOC=%d" % [
		entity_id, entity.entity_name, entity.side, is_attacker, new_location
	])
	
	var row_map = get_meta("attacker_rows" if is_attacker else "defender_rows")
	var new_row = row_map.get(new_location)
	
	if new_row:
		var new_row_parent = new_row.get_parent()
		print("[LOC_DEBUG] Selected row: %s/%s (from %s)" % [
			new_row_parent.name if new_row_parent else "null",
			new_row.name,
			"attacker_rows" if is_attacker else "defender_rows"
		])

	if new_row and display.get_parent() != new_row:
		await battlefield_controller.animate_move_to_row(display, new_row)
	else:
		print("[LOC] No move needed (already in correct row or invalid row)")

func print_outcome(outcome: SquadBattleTypes.BattleOutcome) -> void:
	match outcome:
		SquadBattleTypes.BattleOutcome.ATTACKER_VICTORY:
			var strength = battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
			print("🏆 ATTACKER VICTORY with remaining strength %.1f" % strength)
		SquadBattleTypes.BattleOutcome.DEFENDER_VICTORY:
			var strength = battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
			print("🏆 DEFENDER VICTORY with remaining strength %.1f" % strength)
		SquadBattleTypes.BattleOutcome.DRAW:
			var atk_str = battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
			var def_str = battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
			print("🤝 DRAW after %d rounds. Attacker: %.1f, Defender: %.1f" % [
				battle.round_count, atk_str, def_str
			])
