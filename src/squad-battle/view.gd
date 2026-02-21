class_name SquadBattleView extends Node3D

var battle: SquadBattle
var config: Dictionary

var battlefield_controller: SBGraphics
var entity_displays_dict: Dictionary = {}

@onready var presenter: SquadBattlePresenter = $SquadBattlePresenter

func _ready() -> void:
	battlefield_controller = get_node("25dBattlefield")
	_setup_row_mappings()
	presenter.bind_view(self)
	presenter.start(battle, config)

func _setup_row_mappings() -> void:
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

	set_meta("attacker_rows", attacker_rows)
	set_meta("defender_rows", defender_rows)

func spawn_all_entities(p_battle: SquadBattle) -> void:
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

	for team_name in p_battle.teams_and_squads.keys():
		var squads: Array = p_battle.teams_and_squads[team_name]
		var is_attacker = (team_name == SquadBattleTypes.Side.ATTACKER)
		var row_map = get_meta("attacker_rows" if is_attacker else "defender_rows")

		for squad: SquadCombatData in squads:
			for entity: CharacterCombatStats in squad.entities:
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

func process_updates(updates: Array[EntityUpdate], p_battle: SquadBattle) -> void:
	for update in updates:
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

		var animation_task = targets_display.animation_completed
		targets_display.update_stat(update.change.property, update.change.from, update.change.to)
		await animation_task

		attackers_display.switch_sprite("idle")
		targets_display.switch_sprite("idle")

		if change_type == SquadBattleTypes.EntityChangeable.DIE:
			targets_display.visible = false
			targets_display.queue_free()
			entity_displays_dict.erase(update.affected)
		elif change_type == SquadBattleTypes.EntityChangeable.LOC:
			await _handle_location_change(update.affected, targets_display, int(update.change.to), p_battle)

func animate_return_all() -> void:
	await battlefield_controller.animate_return_all_to_positions()

func wait_delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func show_outcome(outcome: SquadBattleTypes.BattleOutcome, p_battle: SquadBattle) -> void:
	var outcome_name = SquadBattleTypes.BattleOutcome.keys()[outcome]
	SBLog.section("BATTLE ENDED: %s" % outcome_name, 0, 2, 1)
	match outcome:
		SquadBattleTypes.BattleOutcome.ATTACKER_VICTORY:
			var strength = p_battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
			print("ATTACKER VICTORY with remaining strength %.1f" % strength)
		SquadBattleTypes.BattleOutcome.DEFENDER_VICTORY:
			var strength = p_battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
			print("DEFENDER VICTORY with remaining strength %.1f" % strength)
		SquadBattleTypes.BattleOutcome.DRAW:
			var atk_str = p_battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
			var def_str = p_battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
			print("DRAW after %d rounds. Attacker: %.1f, Defender: %.1f" % [
				p_battle.round_count, atk_str, def_str
			])

func _update_row_positions(row_node: Node3D) -> void:
	battlefield_controller.update_row_positions(row_node)
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

	var opposing_index = -1
	if current_index < 3:
		opposing_index = 5 - current_index
	else:
		opposing_index = 2 - (current_index - 3)

	if opposing_index >= 0 and opposing_index < all_rows.size():
		battlefield_controller.update_row_positions(all_rows[opposing_index])

func _handle_location_change(entity_id: int, display: Node3D, new_location: int, p_battle: SquadBattle) -> void:
	var entity = p_battle.get_entity_by_id(entity_id)
	if not entity or not display:
		return

	var is_attacker = entity.side == SquadBattleTypes.Side.ATTACKER
	var row_map = get_meta("attacker_rows" if is_attacker else "defender_rows")
	var new_row = row_map.get(new_location)

	if new_row and display.get_parent() != new_row:
		await battlefield_controller.animate_move_to_row(display, new_row)
