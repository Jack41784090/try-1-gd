extends RefCounted

class_name CombatController

## Controls combat flow between strategic and tactical layers
## Manages pre-combat intermission, combat execution, and post-combat resolution
## Integrates with CombatBridge for Warrior↔Entity mapping

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
	var loot: Dictionary = { }
	var equipment_loot: Dictionary = { }
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
var current_player_squad: SquadData
var current_enemy_squad: SquadData
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
	# Sets up combat context and returns intermission options for the UI
	# Called when combat is triggered — stores both squads, resets state, builds choices
	# e.g., inject_context("Wolves", "Raiders", viewport, overlay, AMBUSH)
	#   → stores squads, clears old updates, returns {can_fight: true, can_flee: false, ...}
	current_player_squad = player_squad
	current_enemy_squad = enemy_squad
	current_tactic = player_squad.get_tactic()
	current_engagement_type = engagement_type
	is_in_combat = true
	combat_phase = 0
	all_updates.clear()
	battle_viewport = _battle_viewport
	combat_overlay = _combat_overlay
	return _build_intermission_options()


func set_tactic(tactic: Tactic) -> void:
	current_tactic = tactic
	print("[CombatController] Tactic set to: %s" % tactic.tactic_name)


func set_tactic_by_type(tactic_type: Tactic.TacticType) -> void:
	current_tactic = Tactic.create_from_type(tactic_type)
	print("[CombatController] Tactic set by type: %s → %s" % [Tactic.TacticType.keys()[tactic_type], current_tactic.tactic_name])


func process_intermission_choice(choice: IntermissionChoice) -> CombatResult:
	# Main entry point: player picks FIGHT, FLEE, or NEGOTIATE from the intermission screen
	# Routes to the appropriate handler, which may chain into _execute_combat() on failure
	# e.g., FLEE(roll=0.4, chance=0.35) → FAILED → forced to _execute_combat() with defensive tactic
	# e.g., FIGHT → directly calls _execute_combat() → returns CombatResult with victory/casualties
	print("\n[CombatController] Processing intermission choice: %s" % IntermissionChoice.keys()[choice])

	var result := CombatResult.new()

	match choice:
		IntermissionChoice.FIGHT:
			print("[CombatController] Player chose to FIGHT")
			result = await _execute_combat()
		IntermissionChoice.FLEE:
			print("[CombatController] Player chose to FLEE")
			result = await _attempt_flee()
		IntermissionChoice.NEGOTIATE:
			print("[CombatController] Player chose to NEGOTIATE")
			result = await _attempt_negotiate()

	_end_combat(result)
	return result


func _execute_combat() -> CombatResult:
	# Runs a full tactical combat: creates battle via bridge, spawns 3D scene, awaits outcome, applies results
	# Flow: bridge.create_battle() → scene spawned in SubViewport → await presenter.battle_completed → apply_results()
	# e.g., "Wolves" vs "Raiders" → 5 rounds of combat → ATTACKER_VICTORY → 2 enemy casualties, 1 player injured
	print("\n[CombatController] EXECUTING TACTICAL COMBAT")
	print("-".repeat(40))

	var result := CombatResult.new()

	# Create battle via bridge
	var battle = combat_bridge.create_battle(current_player_squad, current_enemy_squad, current_tactic)
	combat_bridge.apply_injury_penalties(current_player_squad)
	combat_bridge.apply_injury_penalties(current_enemy_squad)
	print("[CombatController] Battle created with tactic: %s" % current_tactic.tactic_name)

	var battle_scene = SquadBattleMasterFactory.create_battle_scene(battle)
	combat_overlay.add_child(battle_scene)
	combat_overlay.visible = true

	print("[CombatController] Awaiting battle completion...")
	var battle_presenter = battle_scene.get_node("SquadBattlePresenter")
	var outcome = await battle_presenter.battle_completed
	print("[CombatController] Battle outcome: %s" % SquadBattleTypes.BattleOutcome.keys()[outcome])

	# NOTE: Battle scene and overlay are kept visible for the summary display
	# The UI (_show_combat_result_overlay) will clean up after showing the summary
	print("[CombatController] Battle scene kept for summary display")

	# Collect all updates from the completed battle
	all_updates = battle_presenter.all_updates.duplicate()
	combat_phase = battle.round_count
	print("[CombatController] Battle completed after %d rounds, %d updates collected" % [combat_phase, all_updates.size()])

	print("\n[CombatController] COMBAT CONCLUDED")

	# Determine victory based on outcome enum
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

	# Calculate morale change based on outcome
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

	# generate clues for the current location
	result.clues_dropped = _generate_enemy_clues(current_enemy_squad)

	if result.victory:
		result.equipment_loot = LootCollector.collect_equipment_loot(current_enemy_squad, result.enemy_casualties)

	return result


func _attempt_flee() -> CombatResult:
	# Attempts to flee combat — rolls against FLEE_BASE_CHANCE + (squad SURVIVAL stat * modifier)
	# On success: fled=true, morale -10. On failure: forced combat with defensive tactic, morale -15 extra
	# e.g., SURVIVAL=4.0, chance=0.30+(4.0*0.05)=0.50, roll=0.4 → SUCCESS (0.4 < 0.5)
	# e.g., SURVIVAL=2.0, chance=0.30+(2.0*0.05)=0.40, roll=0.6 → FAILED → forced defensive fight
	var result := CombatResult.new()
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
	# intermission_choice_made.emit("FLEE", roll_result)

	if roll < flee_chance:
		print("[CombatController]   SUCCESS - CombatSquad escaped!")
		result.fled = true
		result.morale_change = -10.0 # Morale penalty for fleeing
	else:
		print("[CombatController]   FAILED - Forced to fight!")
		# Failed flee attempt - fight with penalty
		current_tactic = Tactic.create_defensive_formation() # Forced defensive
		result = await _execute_combat()
		result.morale_change -= 15.0 # Additional penalty for failed flee

	return result


func _attempt_negotiate() -> CombatResult:
	# Attempts diplomatic resolution — rolls against NEGOTIATE_BASE_CHANCE + (squad DIPLOMACY stat * modifier)
	# On success: negotiated=true, morale +5. On failure: forced normal combat, morale -5
	# e.g., DIPLOMACY=6.0, chance=0.20+(6.0*0.05)=0.50, roll=0.3 → SUCCESS (peace)
	# e.g., DIPLOMACY=2.0, chance=0.20+(2.0*0.05)=0.30, roll=0.5 → FAILED → fight
	var result := CombatResult.new()
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
	# intermission_choice_made.emit("NEGOTIATE", roll_result)

	if roll < negotiate_chance:
		print("[CombatController]   SUCCESS - Conflict resolved peacefully!")
		result.negotiated = true
		result.morale_change = 5.0 # Small morale boost for diplomatic solution
	else:
		print("[CombatController]   FAILED - Negotiations broke down!")
		# Failed negotiate - fight normally
		result = await _execute_combat()
		result.morale_change -= 5.0 # Small penalty for wasted time

	return result

#region Combat Flow

func _build_intermission_options() -> Dictionary:
	# Builds the pre-combat choice screen data: calculates flee/negotiate chances from squad stats
	# Adapts options based on engagement type (AMBUSH disables some choices)
	# e.g., SET_PIECE: can_fight=true, can_flee=true(45%), can_negotiate=true(35%)
	# e.g., AMBUSH (we are ambushed): can_flee=false, can_negotiate=false (forced fight)
	# e.g., AMBUSH (we ambush them): can_negotiate=false, flee_chance=100% (easy escape)
	var player_survival = _get_squad_survival_stat(current_player_squad)
	var player_diplomacy = _get_squad_diplomacy_stat(current_player_squad)

	var flee_chance = clampf(FLEE_BASE_CHANCE + (player_survival * FLEE_SURVIVAL_MODIFIER), 0.0, 0.9)
	var negotiate_chance = clampf(NEGOTIATE_BASE_CHANCE + (player_diplomacy * NEGOTIATE_DIPLOMACY_MODIFIER), 0.0, 0.9)

	var can_flee := true
	var can_negotiate := true
	var is_player_attacker := true

	match current_engagement_type:
		StrategyTypes.EngagementType.AMBUSH:
			var player_contact = _get_player_contact_state()
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


func _get_player_contact_state() -> StrategyTypes.ContactState:
	if not contact_tracker:
		return StrategyTypes.ContactState.LOCKED
	var contact = contact_tracker.get_contact(current_player_squad.squad_id, current_enemy_squad.squad_id)
	return contact.get_state() if contact else StrategyTypes.ContactState.NONE


func set_contact_tracker(tracker) -> void:
	contact_tracker = tracker


func _get_squad_survival_stat(squad: SquadData) -> float:
	var total: float = 0.0
	var count: int = 0
	for warrior in squad.get_living_warriors():
		if warrior.combat_stats:
			# Survival based on ACR (agility) + WIL
			total += warrior.combat_stats.acr + warrior.combat_stats.wil
		count += 1
	return total / max(count, 1) / 2.0 # Average of ACR+WIL


func _get_squad_diplomacy_stat(squad: SquadData) -> float:
	var total: float = 0.0
	var count: int = 0
	for warrior in squad.get_living_warriors():
		if warrior.combat_stats:
			# Diplomacy based on CHA + INT
			total += warrior.combat_stats.cha + warrior.combat_stats.int_stat
		count += 1
	return total / max(count, 1) / 2.0 # Average of CHA+INT


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
			return entity.entity_name
	return "Entity#%d" % entity_id


func _generate_loot(enemy_squad: SquadData) -> Dictionary:
	var loot = {
		"money": rng.randi_range(10, 50) * enemy_squad.get_living_warriors().size(),
		"food": rng.randi_range(1, 5),
	}
	print("[CombatController] Generated loot from %s: %s" % [enemy_squad.squad_name, loot])
	return loot


var _CHANCE = 1


func _generate_enemy_clues(enemy_squad: SquadData, current_hour: int = 0) -> Array[Clue]:
	# Generates intelligence clues from the enemy squad after combat
	# Each clue reveals enemy movements (their current_location_id as destination)
	# e.g., "Raiders" at "linz" with 2 warriors → creates 2 clues pointing to "linz"
	var clues: Array[Clue] = []
	# 30% chance to drop a clue about enemy movements

	if rng.randf() < _CHANCE and enemy_squad.get_living_warriors().size() > 0:
		for warrior in enemy_squad.get_living_warriors():
			var clue = Clue.create_clue(
				Clue.get_random_clue_name(warrior.religion),
				enemy_squad.squad_id,
				warrior.id,
				current_hour,
				3, # stealth_failure_margin (detail level)
				enemy_squad.current_location_id, # destination
			)
			clues.append(clue)
			print("[CombatController] Enemy dropped clue: %s" % clue.clue_name)
	return clues


func _end_combat(result: CombatResult) -> void:
	print("\n[CombatController] COMBAT ENDED")
	print("[CombatController] Result: %s" % result)
	print("=".repeat(60) + "\n")

	is_in_combat = false
	combat_ended.emit()
	combat_bridge.clear_mappings()

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
