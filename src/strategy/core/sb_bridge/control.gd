class_name CombatController
extends RefCounted
## Controls combat flow between strategic and tactical layers
## Manages pre-combat intermission, combat execution, and post-combat resolution
## Integrates with CombatBridge for StrategyEntity↔Entity mapping

signal combat_ended()

const FLEE_BASE_CHANCE: float = 0.3
const FLEE_SURVIVAL_MODIFIER: float = 0.05
const NEGOTIATE_BASE_CHANCE: float = 0.2
const NEGOTIATE_DIPLOMACY_MODIFIER: float = 0.05
const INTERMISSION_TIMEOUT_SECONDS: float = 30.0

enum IntermissionChoice {
	FIGHT,
	FLEE,
	NEGOTIATE,
}


class CombatResult extends RefCounted:
	var victory: bool = false
	var fled: bool = false
	var negotiated: bool = false
	var player_casualties: Array[String] = []
	var enemy_casualties: Array[String] = []
	var escaped_warriors: Array[String] = []
	var morale_change: float = 0.0
	var loot: Dictionary = {}
	var equipment_loot: Dictionary = {}
	var clues_dropped: Array[Clue] = []
	var turns_elapsed: int = 0


	func _to_string() -> String:
		if victory:
			return "CombatResult[VICTORY, casualties=%d, escaped=%d, loot=%s]" % [player_casualties.size(), escaped_warriors.size(), loot]
		elif fled:
			return "CombatResult[FLED, casualties=%d]" % player_casualties.size()
		elif negotiated:
			return "CombatResult[NEGOTIATED]"
		else:
			return "CombatResult[DEFEAT, casualties=%d, escaped=%d]" % [player_casualties.size(), escaped_warriors.size()]


var combat_bridge: CombatBridge
var current_player_squad: StrategySquad
var current_enemy_squad: StrategySquad
var current_tactic: Tactic
var is_in_combat: bool = false
var combat_phase: int = 0
var all_updates: Array[EntityUpdate] = []
var rng := RandomNumberGenerator.new()
var current_engagement_type: StrategyTypes.EngagementType = StrategyTypes.EngagementType.SET_PIECE
var contact_tracker = null

var battle_viewport
var combat_overlay


func _init() -> void:
	combat_bridge = CombatBridge.new()
	rng.randomize()
	print("[CombatController] Initialized")


func inject_context(player_squad, enemy_squad, _battle_viewport, _combat_overlay, engagement_type: StrategyTypes.EngagementType = StrategyTypes.EngagementType.SET_PIECE):
	current_player_squad = player_squad
	current_enemy_squad = enemy_squad
	current_tactic = player_squad.get_tactic()
	current_engagement_type = engagement_type
	is_in_combat = true
	combat_phase = 0
	all_updates.clear()
	battle_viewport = _battle_viewport
	combat_overlay = _combat_overlay
	var player_survival = _get_squad_survival_stat(current_player_squad)
	var player_diplomacy = _get_squad_diplomacy_stat(current_player_squad)

	var flee_chance = clampf(FLEE_BASE_CHANCE + (player_survival * FLEE_SURVIVAL_MODIFIER), 0.0, 0.9)
	var negotiate_chance = clampf(NEGOTIATE_BASE_CHANCE + (player_diplomacy * NEGOTIATE_DIPLOMACY_MODIFIER), 0.0, 0.9)

	var can_flee := true
	var can_negotiate := true
	var is_player_attacker := true

	match current_engagement_type:
		StrategyTypes.EngagementType.AMBUSH:
			var player_contact: StrategyTypes.ContactState
			if not contact_tracker:
				player_contact = StrategyTypes.ContactState.LOCKED
			else:
				var contact = contact_tracker.get_contact(current_player_squad.squad_id, current_enemy_squad.squad_id)
				player_contact = contact.get_state() if contact else StrategyTypes.ContactState.NONE
			is_player_attacker = player_contact == StrategyTypes.ContactState.LOCKED
			if is_player_attacker:
				can_negotiate = false
				flee_chance = 1.0
			else:
				can_flee = false
				can_negotiate = false
		StrategyTypes.EngagementType.MEETING:
			pass

	print("[CombatController] Building intermission options (%s):" % StrategyTypes.EngagementType.keys()[current_engagement_type])
	print("[CombatController]   Player SURVIVAL stat: %.1f → Flee chance: %.1f%%" % [player_survival, flee_chance * 100])
	print("[CombatController]   Player DIPLOMACY stat: %.1f → Negotiate chance: %.1f%%" % [player_diplomacy, negotiate_chance * 100])

	return {
		"can_fight": true,
		"can_flee": can_flee,
		"flee_chance": flee_chance,
		"flee_stat": player_survival,
		"can_negotiate": can_negotiate,
		"negotiate_chance": negotiate_chance,
		"negotiate_stat": player_diplomacy,
		"timeout_seconds": INTERMISSION_TIMEOUT_SECONDS,
		"enemy_name": current_enemy_squad.squad_name,
		"enemy_count": current_enemy_squad.get_living_warriors().size(),
		"engagement_type": current_engagement_type,
		"is_player_attacker": is_player_attacker,
	}


func set_tactic(tactic: Tactic) -> void:
	current_tactic = tactic
	print("[CombatController] Tactic set to: %s" % tactic.tactic_name)


func set_tactic_by_type(tactic_type: Tactic.TacticType) -> void:
	current_tactic = Tactic.create_from_type(tactic_type)
	print("[CombatController] Tactic set by type: %s → %s" % [Tactic.TacticType.keys()[tactic_type], current_tactic.tactic_name])


func process_intermission_choice(choice: IntermissionChoice) -> CombatResult:
	print("\n[CombatController] Processing intermission choice: %s" % IntermissionChoice.keys()[choice])

	var result := CombatResult.new()

	match choice:
		IntermissionChoice.FIGHT:
			print("[CombatController] Player chose to FIGHT")
			result = await _execute_combat()
		IntermissionChoice.FLEE:
			print("[CombatController] Player chose to FLEE")
			result = CombatResult.new()
			var flee_chance = clampf(FLEE_BASE_CHANCE + (_get_squad_survival_stat(current_player_squad) * FLEE_SURVIVAL_MODIFIER), 0.0, 0.9)
			var roll = rng.randf()
			print("[CombatController] FLEE ATTEMPT:")
			print("[CombatController]   Required: %.1f%%" % (flee_chance * 100))
			print("[CombatController]   Rolled: %.1f%%" % (roll * 100))
			var roll_result = {
				"stat": "SURVIVAL",
				"stat_value": _get_squad_survival_stat(current_player_squad),
				"required": flee_chance,
				"rolled": roll,
				"success": roll < flee_chance,
			}
			if roll < flee_chance:
				print("[CombatController]   SUCCESS - CombatSquad escaped!")
				result.fled = true
				result.morale_change = -10.0
			else:
				print("[CombatController]   FAILED - Forced to fight!")
				current_tactic = Tactic.create_defensive_formation()
				result = await _execute_combat()
				result.morale_change -= 15.0
		IntermissionChoice.NEGOTIATE:
			print("[CombatController] Player chose to NEGOTIATE")
			result = CombatResult.new()
			var negotiate_chance = clampf(NEGOTIATE_BASE_CHANCE + (_get_squad_diplomacy_stat(current_player_squad) * NEGOTIATE_DIPLOMACY_MODIFIER), 0.0, 0.9)
			var roll = rng.randf()
			print("[CombatController] NEGOTIATE ATTEMPT:")
			print("[CombatController]   Required: %.1f%%" % (negotiate_chance * 100))
			print("[CombatController]   Rolled: %.1f%%" % (roll * 100))
			var roll_result = {
				"stat": "DIPLOMACY",
				"stat_value": _get_squad_diplomacy_stat(current_player_squad),
				"required": negotiate_chance,
				"rolled": roll,
				"success": roll < negotiate_chance,
			}
			if roll < negotiate_chance:
				print("[CombatController]   SUCCESS - Conflict resolved peacefully!")
				result.negotiated = true
				result.morale_change = 5.0
			else:
				print("[CombatController]   FAILED - Negotiations broke down!")
				result = await _execute_combat()
				result.morale_change -= 5.0

	print("\n[CombatController] COMBAT ENDED")
	print("[CombatController] Result: %s" % result)
	print("=".repeat(60) + "\n")
	is_in_combat = false
	combat_ended.emit()
	combat_bridge.clear_mappings()
	return result


func _execute_combat() -> CombatResult:
	print("\n[CombatController] EXECUTING TACTICAL COMBAT")
	print("-".repeat(40))

	var result := CombatResult.new()

	var battle = combat_bridge.create_battle(current_player_squad, current_enemy_squad, current_tactic)
	combat_bridge.apply_injury_penalties(current_player_squad)
	combat_bridge.apply_injury_penalties(current_enemy_squad)
	print("[CombatController] Battle created with tactic: %s" % current_tactic.tactic_name)

	var battle_scene = SquadBattleMasterFactory.create_battle_scene(battle)
	combat_overlay.add_child(battle_scene)
	combat_overlay.visible = true

	print("[CombatController] Awaiting battle completion...")
	var outcome = await battle.battle_completed
	print("[CombatController] Battle outcome: %s" % SquadBattleTypes.BattleOutcome.keys()[outcome])

	print("[CombatController] Battle scene kept for summary display")

	all_updates = battle_scene.all_updates.duplicate()
	combat_phase = battle.round_count
	print("[CombatController] Battle completed after %d rounds, %d updates collected" % [combat_phase, all_updates.size()])

	print("\n[CombatController] COMBAT CONCLUDED")

	result.victory = (outcome == SquadBattleTypes.BattleOutcome.ATTACKER_VICTORY)
	result.turns_elapsed = combat_phase

	var player_apply_result = combat_bridge.apply_results(current_player_squad, all_updates)
	print("[CombatController] Applied results to player squad:")
	print("[CombatController]   Deaths: %s" % [player_apply_result.deaths])
	print("[CombatController]   Injuries: %s" % [player_apply_result.injuries])
	print("[CombatController]   Escaped: %s" % [player_apply_result.escaped])

	var enemy_apply_result = combat_bridge.apply_results(current_enemy_squad, all_updates)
	print("[CombatController] Applied results to enemy squad:")
	print("[CombatController]   Deaths: %s" % [enemy_apply_result.deaths])
	print("[CombatController]   Injuries: %s" % [enemy_apply_result.injuries])
	print("[CombatController]   Escaped: %s" % [enemy_apply_result.escaped])

	for death_id in player_apply_result.deaths:
		result.player_casualties.append(death_id)

	for escaped_id in player_apply_result.escaped:
		result.escaped_warriors.append(escaped_id)

	for death_id in enemy_apply_result.deaths:
		result.enemy_casualties.append(death_id)

	match outcome:
		SquadBattleTypes.BattleOutcome.ATTACKER_VICTORY:
			result.morale_change = 15.0 - (result.player_casualties.size() * 5.0)
			print("[CombatController] VICTORY! Morale change: %.1f" % result.morale_change)
		SquadBattleTypes.BattleOutcome.DEFENDER_VICTORY:
			result.morale_change = -20.0 - (result.player_casualties.size() * 5.0)
			print("[CombatController] DEFEAT! Morale change: %.1f" % result.morale_change)
		SquadBattleTypes.BattleOutcome.DRAW:
			result.morale_change = -5.0 - (result.player_casualties.size() * 2.0)
			print("[CombatController] DRAW! Morale change: %.1f" % result.morale_change)

	var clues: Array[Clue] = []
	if rng.randf() < _CHANCE and current_enemy_squad.get_living_warriors().size() > 0:
		for warrior in current_enemy_squad.get_living_warriors():
			var clue = Clue.create_clue(
				Clue.get_random_clue_name(warrior.religion),
				current_enemy_squad.squad_id,
				warrior.id,
				0,
				3,
				current_enemy_squad.current_location_id,
			)
			clues.append(clue)
			print("[CombatController] Enemy dropped clue: %s" % clue.clue_name)
	result.clues_dropped = clues

	if result.victory:
		result.equipment_loot = LootCollector.collect_equipment_loot(current_enemy_squad, result.enemy_casualties)

	return result


#region Combat Flow

func set_contact_tracker(tracker) -> void:
	contact_tracker = tracker


func _get_squad_survival_stat(squad: StrategySquad) -> float:
	var total: float = 0.0
	var count: int = 0
	for warrior in squad.get_living_warriors():
		## Survival based on ACR (agility) + WIL — tier-2/tier-1 cascade via Character
		total += warrior.get_constant_stat_value(StatName.I.ACR) + warrior.get_constant_stat_value(StatName.I.WIL)
		count += 1
	return total / max(count, 1) / 2.0


func _get_squad_diplomacy_stat(squad: StrategySquad) -> float:
	var total: float = 0.0
	var count: int = 0
	for warrior in squad.get_living_warriors():
		## Diplomacy based on CHA + INT — tier-2/tier-1 cascade via Character
		total += warrior.get_constant_stat_value(StatName.I.CHA) + warrior.get_constant_stat_value(StatName.I.INT_STAT)
		count += 1
	return total / max(count, 1) / 2.0


func _log_entity_update(update: EntityUpdate) -> void:
	var source_name = _get_entity_name(update.source)
	var target_name = _get_entity_name(update.affected)
	var property_name = SquadBattleTypes.EntityChangeable.keys()[update.change.property]

	print(
		"[CombatController]   %s → %s: %s %.1f → %.1f (Δ%.1f)" % [
			source_name,
			target_name,
			property_name,
			update.change.from,
			update.change.to,
			update.change.to - update.change.from,
		],
	)


func _get_entity_name(entity_id: int) -> String:
	if combat_bridge.current_battle:
		var entity = combat_bridge.current_battle.get_entity_by_id(entity_id)
		if entity:
			return entity.display_name
	return "Entity#%d" % entity_id


func _generate_loot(enemy_squad: StrategySquad) -> Dictionary:
	var loot = {
		"money": rng.randi_range(10, 50) * enemy_squad.get_living_warriors().size(),
		"food": rng.randi_range(1, 5),
	}
	print("[CombatController] Generated loot from %s: %s" % [enemy_squad.squad_name, loot])
	return loot


var _CHANCE = 1

#endregion

#region Query Methods

func get_current_battle() -> SquadBattle:
	return combat_bridge.current_battle


func get_all_updates() -> Array[EntityUpdate]:
	return all_updates


func is_combat_active() -> bool:
	return is_in_combat


func get_combat_phase() -> int:
	return combat_phase

#endregion
