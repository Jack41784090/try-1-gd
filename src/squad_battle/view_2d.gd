class_name SquadBattleNode
extends Control

@onready var battlefield_controller := $BattlefieldView2D
var battle: SquadBattle

var entity_displays_dict: Dictionary = {}
var is_running: bool = false
var delay_between_rounds: float = 2.0
var last_round_capitulated: Array[CombatEntity] = []
var all_updates: Array[EntityUpdate] = []


func _ready() -> void:
	var sbt_Location = SquadBattleTypes.SquadEntityInSquadLocation
	var attacker_rows = {
		sbt_Location.Front: battlefield_controller.attacker_front,
		sbt_Location.Middle: battlefield_controller.attacker_middle,
		sbt_Location.Back: battlefield_controller.attacker_back
	}

	var defender_rows = {
		sbt_Location.Front: battlefield_controller.defender_front,
		sbt_Location.Middle: battlefield_controller.defender_middle,
		sbt_Location.Back: battlefield_controller.defender_back
	}

	set_meta("attacker_rows", attacker_rows)
	set_meta("defender_rows", defender_rows)

	# Build battle
	if battle == null:
		battle = _create_mock_battle()

	# just in case clear out any exsiting displays
	battlefield_controller.clear_all_rownodes()

	# setting new displays in each row
	for team_name in battle.side_squads_dict:
		var squads = battle.side_squads_dict.get(team_name) as Array[CombatSquad]
		var is_attacker = (team_name == SquadBattleTypes.Side.ATTACKER)
		var row_map = get_meta("attacker_rows" if is_attacker else "defender_rows")

		for squad: CombatSquad in squads:
			for entity: CombatEntity in squad.entities:
				var location := entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC)
				var row_node: Node2D = row_map.get(location)

				var display = battlefield_controller.add_unit_to_row(
					row_node, row_node.get_child_count(),
					entity.display_name, entity
				)
				entity_displays_dict.set(entity.player_id, display)
				_update_row_positions(row_node)

	is_running = true

	SBLog.section("CombatSquad Battle Started!", 0, 2, 1)
	await get_tree().create_timer(1.0).timeout
	_loop_round()


func request_retreat(team: SquadBattleTypes.Side) -> void:
	if battle:
		battle.order_retreat(team)


func _loop_round() -> void:
	var outcome = battle.evaluate_outcome()
	if outcome != SquadBattleTypes.BattleOutcome.ONGOING:
		show_outcome(outcome, battle)
		is_running = false
		return

	SBLog.section("Round %d / %d" % [battle.round_count + 1, battle.max_rounds], 1, 1, 1)
	battle.round_count += 1

	battle.remove_dead_entities()
	battle.remove_capitulated_entities(last_round_capitulated)
	last_round_capitulated.clear()

	var updates := battle.squad_actions()
	for update in updates:
		all_updates.append(update)
		if update.change.property == SquadBattleTypes.EntityChangeable.CAPITULATE:
			var entity = battle.get_entity_by_id(update.affected)
			if entity:
				last_round_capitulated.append(entity)

	battle.squad_recoveries()
	await _animate_updates(updates, battle)
	await animate_return_all()
	await wait_delay(delay_between_rounds)
	_loop_round()


func _create_mock_battle() -> SquadBattle:
	var teams: Dictionary[SquadBattleTypes.Side, Array] = {
		SquadBattleTypes.Side.ATTACKER: [
			["Heroes", SquadBattleTypes.Side.ATTACKER, ["landsknecht", "landsknecht", "landsknecht", "healer"]],
		],
		SquadBattleTypes.Side.DEFENDER: [
			["Monsters", SquadBattleTypes.Side.DEFENDER, ["landsknecht", "landsknecht", "landsknecht", "healer"]],
		],
	}

	return SquadBattle.new(teams, Tactic.create_balanced(), Tactic.create_balanced())

func _animate_updates(updates: Array[EntityUpdate], p_battle: SquadBattle) -> void:
	for update in updates:
		var attackers_display = entity_displays_dict.get(update.source)
		var targets_display = entity_displays_dict.get(update.affected)
		var attacker_entity = p_battle.get_entity_by_id(update.source)

		if not targets_display:
			push_warning("No display found for entity %d" % update.affected)
			continue

		var change_type = update.change.property
		var hp_changed = change_type == SquadBattleTypes.EntityChangeable.HP
		var took_damage = update.change.to < update.change.from

		if hp_changed:
			if attacker_entity:
				_play_attack_sfx(attacker_entity.weapon.resource.weapon_class)
			if attackers_display:
				attackers_display.play_behavior(AnimTypes.Behavior.ATTACKING)
				await battlefield_controller.animate_attack_lunge(attackers_display)
			if took_damage:
				targets_display.play_behavior(AnimTypes.Behavior.DEFENDING)
				battlefield_controller.animate_attack_recoil(targets_display)
				if attackers_display:
					battlefield_controller.animate_attack_recoil(attackers_display)
		elif change_type == SquadBattleTypes.EntityChangeable.CLINK:
			_play_combat_sfx("play_combat_clink")
			if attackers_display:
				attackers_display.play_behavior(AnimTypes.Behavior.ATTACKING)
				await battlefield_controller.animate_attack_lunge(attackers_display)
			targets_display.play_behavior(AnimTypes.Behavior.DEFENDING)
			battlefield_controller.animate_clink(targets_display)

		var animation_task = targets_display.animation_completed
		targets_display.update_stat(update.change.property, update.change.from, update.change.to)
		await animation_task

		if attackers_display:
			attackers_display.play_behavior(AnimTypes.Behavior.IDLE)
		targets_display.play_behavior(AnimTypes.Behavior.IDLE)

		if change_type == SquadBattleTypes.EntityChangeable.DIE:
			_play_combat_sfx("play_death")
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
			_play_combat_sfx("play_player_victory")
			var strength = p_battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
			print("ATTACKER VICTORY with remaining strength %.1f" % strength)
		SquadBattleTypes.BattleOutcome.DEFENDER_VICTORY:
			_play_combat_sfx("play_player_defeat")
			var strength = p_battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
			print("DEFENDER VICTORY with remaining strength %.1f" % strength)
		SquadBattleTypes.BattleOutcome.DRAW:
			_play_combat_sfx("play_player_defeat")
			var atk_str = p_battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
			var def_str = p_battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
			print("DRAW after %d rounds. Attacker: %.1f, Defender: %.1f" % [
				p_battle.round_count, atk_str, def_str
			])


func _play_attack_sfx(weapon_class: int) -> void:
	var sfx = _get_sfx_node()
	if sfx and sfx.has_method("play_attack_for_weapon"):
		sfx.call("play_attack_for_weapon", weapon_class)


func _play_combat_sfx(method_name: String) -> void:
	var sfx = _get_sfx_node()
	if sfx and sfx.has_method(method_name):
		sfx.call(method_name)


func _get_sfx_node() -> Node:
	var tree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("SFX")


func _update_row_positions(row_node: Node2D) -> void:
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


func _handle_location_change(entity_id: int, display: Node2D, new_location: int, p_battle: SquadBattle) -> void:
	var entity = p_battle.get_entity_by_id(entity_id)
	if not entity or not display:
		return

	var is_attacker = entity.side == SquadBattleTypes.Side.ATTACKER
	var row_map = get_meta("attacker_rows" if is_attacker else "defender_rows")
	var new_row = row_map.get(new_location)

	if new_row and display.get_parent() != new_row:
		await battlefield_controller.animate_move_to_row(display, new_row)
