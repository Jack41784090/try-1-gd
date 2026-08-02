class_name SquadBattleNode
extends Control

signal update_fired(update: EntityUpdate)

@onready var battlefield_controller := $BattlefieldView2D
var battle: SquadBattle

var entity_displays_dict: Dictionary = {}
var is_running: bool = false
var delay_between_rounds: float = 2.0
var all_updates: Array[EntityUpdate] = []

const PACING_DEFAULT: float = 0.35
const PACING_DEATH: float = 0.55


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

	if battle == null:
		var teams: Dictionary[SquadBattleTypes.Side, Array] = {
			SquadBattleTypes.Side.ATTACKER: [
				["Heroes", SquadBattleTypes.Side.ATTACKER, ["landsknecht", "landsknecht", "landsknecht", "healer"]],
			],
			SquadBattleTypes.Side.DEFENDER: [
				["Monsters", SquadBattleTypes.Side.DEFENDER, ["landsknecht", "landsknecht", "landsknecht", "healer"]],
			],
		}
		battle = SquadBattle.new(teams, Tactic.create_balanced(), Tactic.create_balanced())

	battlefield_controller.clear_all_rownodes()

	for team_name in battle.side_squads_dict:
		var squads = battle.side_squads_dict.get(team_name) as Array[CombatSquad]
		var is_attacker = (team_name == SquadBattleTypes.Side.ATTACKER)
		var row_map = get_meta("attacker_rows" if is_attacker else "defender_rows")

		for squad: CombatSquad in squads:
			for entity: CombatEntity in squad.entities:
				var location := int(entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC))
				var row_node: Node2D = row_map.get(location)

				var display = battlefield_controller.add_unit_to_row(
					row_node, row_node.get_child_count(),
					entity.display_name, entity
				)
				entity_displays_dict.set(entity.player_id, display)
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
				if current_index != -1:
					var opposing_index = -1
					if current_index < 3:
						opposing_index = 5 - current_index
					else:
						opposing_index = 2 - (current_index - 3)
					if opposing_index >= 0 and opposing_index < all_rows.size():
						battlefield_controller.update_row_positions(all_rows[opposing_index])

	for display in entity_displays_dict.values():
		update_fired.connect(display._on_update_fired)

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
		var outcome_name = SquadBattleTypes.BattleOutcome.keys()[outcome]
		SBLog.section("BATTLE ENDED: %s" % outcome_name, 0, 2, 1)
		match outcome:
			SquadBattleTypes.BattleOutcome.ATTACKER_VICTORY:
				var strength = battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
				print("ATTACKER VICTORY with remaining strength %.1f" % strength)
			SquadBattleTypes.BattleOutcome.DEFENDER_VICTORY:
				var strength = battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
				print("DEFENDER VICTORY with remaining strength %.1f" % strength)
			SquadBattleTypes.BattleOutcome.DRAW:
				var atk_str = battle.check_team_strength(SquadBattleTypes.Side.ATTACKER)
				var def_str = battle.check_team_strength(SquadBattleTypes.Side.DEFENDER)
				print("DRAW after %d rounds. Attacker: %.1f, Defender: %.1f" % [
					battle.round_count, atk_str, def_str
				])
		is_running = false
		return

	SBLog.section("Round %d / %d" % [battle.round_count + 1, battle.max_rounds], 1, 1, 1)

	var updates := battle.advance_round()
	all_updates.append_array(updates)

	var depth_groups: Dictionary = {}
	for update in updates:
		var depth: int = update.change.metadata.get("depth", 0) if update.change.metadata.size() > 0 else 0
		if not depth_groups.has(depth):
			depth_groups[depth] = []
		depth_groups[depth].append(update)

	var depths = depth_groups.keys()
	depths.sort()

	for depth in depths:
		if depth > 0:
			await wait_delay(0.12)
		for update in depth_groups[depth]:
			update_fired.emit(update)

			var pacing := PACING_DEATH if update.change.property == SquadBattleTypes.EntityChangeable.DIE else PACING_DEFAULT
			await wait_delay(pacing)

			var source_display: BattleEntityDisplay = entity_displays_dict.get(update.source)
			var target_display: BattleEntityDisplay = entity_displays_dict.get(update.affected)

			if source_display:
				source_display.play_behavior(AnimTypes.Behavior.IDLE)
			if target_display:
				target_display.play_behavior(AnimTypes.Behavior.IDLE)

			if update.change.property == SquadBattleTypes.EntityChangeable.DIE:
				if target_display:
					target_display.visible = false
					target_display.queue_free()
					entity_displays_dict.erase(update.affected)
					update_fired.disconnect(target_display._on_update_fired)
			elif update.change.property == SquadBattleTypes.EntityChangeable.LOC:
				if target_display:
					var loc_entity = battle.get_entity_by_id(update.affected)
					if loc_entity and target_display:
						var loc_is_attacker = loc_entity.side == SquadBattleTypes.Side.ATTACKER
						var loc_row_map = get_meta("attacker_rows" if loc_is_attacker else "defender_rows")
						var new_row = loc_row_map.get(int(update.change.to))
						if new_row and target_display.get_parent() != new_row:
							await battlefield_controller.animate_move_to_row(target_display, new_row)

	await battlefield_controller.animate_return_all_to_positions()
	await wait_delay(delay_between_rounds)
	_loop_round()


func wait_delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
