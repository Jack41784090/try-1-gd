extends RefCounted
class_name CombatController

## Controls combat flow between strategic and tactical layers
## Manages pre-combat intermission, combat execution, and post-combat resolution
## Integrates with CombatBridge for Warrior↔Entity mapping

signal combat_started(player_squad: StrategicSquad, enemy_squad: StrategicSquad)
signal intermission_started(options: Dictionary)
signal intermission_choice_made(choice: String, roll_result: Dictionary)
signal combat_phase_started(phase: int, tactic: Tactic)
signal combat_phase_ended(phase: int, updates: Array[EntityUpdate])
signal combat_ended(result: CombatResult)

const FLEE_BASE_CHANCE: float = 0.3
const FLEE_SURVIVAL_MODIFIER: float = 0.05
const NEGOTIATE_BASE_CHANCE: float = 0.2
const NEGOTIATE_DIPLOMACY_MODIFIER: float = 0.05
const INTERMISSION_TIMEOUT_SECONDS: float = 30.0

enum IntermissionChoice {
	FIGHT,
	FLEE,
	NEGOTIATE
}

class CombatResult extends RefCounted:
	var victory: bool = false
	var fled: bool = false
	var negotiated: bool = false
	var player_casualties: Array[String] = []
	var enemy_casualties: Array[String] = []
	var morale_change: float = 0.0
	var loot: Dictionary = {}
	var clues_dropped: Array[Clue] = []
	var turns_elapsed: int = 0
	
	func _to_string() -> String:
		if victory:
			return "CombatResult[VICTORY, casualties=%d, loot=%s]" % [player_casualties.size(), loot]
		elif fled:
			return "CombatResult[FLED, casualties=%d]" % player_casualties.size()
		elif negotiated:
			return "CombatResult[NEGOTIATED]"
		else:
			return "CombatResult[DEFEAT, casualties=%d]" % player_casualties.size()

var combat_bridge: CombatBridge
var current_player_squad: StrategicSquad
var current_enemy_squad: StrategicSquad
var current_tactic: Tactic
var is_in_combat: bool = false
var combat_phase: int = 0
var all_updates: Array[EntityUpdate] = []
var rng := RandomNumberGenerator.new()

func _init() -> void:
	combat_bridge = CombatBridge.new()
	rng.randomize()
	print("[CombatController] Initialized")

#region Combat Flow

func start_combat(player_squad: StrategicSquad, enemy_squad: StrategicSquad, context: Dictionary = {}) -> Dictionary:
	print("\n" + "=".repeat(60))
	print("[CombatController] COMBAT INITIATED")
	print("=".repeat(60))
	print("[CombatController] Player Squad: %s (%d warriors)" % [player_squad.squad_name, player_squad.get_living_warriors().size()])
	print("[CombatController] Enemy Squad: %s (%d warriors)" % [enemy_squad.squad_name, enemy_squad.get_living_warriors().size()])
	print("[CombatController] Context: %s" % context)
	
	current_player_squad = player_squad
	current_enemy_squad = enemy_squad
	current_tactic = player_squad.get_tactic()
	is_in_combat = true
	combat_phase = 0
	all_updates.clear()
	
	combat_started.emit(player_squad, enemy_squad)
	
	# Build intermission options based on squad stats
	var options = _build_intermission_options()
	print("[CombatController] Intermission options: %s" % options)
	intermission_started.emit(options)
	
	return options

func _build_intermission_options() -> Dictionary:
	var player_survival = _get_squad_survival_stat(current_player_squad)
	var player_diplomacy = _get_squad_diplomacy_stat(current_player_squad)
	
	var flee_chance = clampf(FLEE_BASE_CHANCE + (player_survival * FLEE_SURVIVAL_MODIFIER), 0.0, 0.9)
	var negotiate_chance = clampf(NEGOTIATE_BASE_CHANCE + (player_diplomacy * NEGOTIATE_DIPLOMACY_MODIFIER), 0.0, 0.9)
	
	print("[CombatController] Building intermission options:")
	print("[CombatController]   Player SURVIVAL stat: %.1f → Flee chance: %.1f%%" % [player_survival, flee_chance * 100])
	print("[CombatController]   Player DIPLOMACY stat: %.1f → Negotiate chance: %.1f%%" % [player_diplomacy, negotiate_chance * 100])
	
	return {
		"can_fight": true,
		"can_flee": true,
		"flee_chance": flee_chance,
		"flee_stat": player_survival,
		"can_negotiate": true,
		"negotiate_chance": negotiate_chance,
		"negotiate_stat": player_diplomacy,
		"timeout_seconds": INTERMISSION_TIMEOUT_SECONDS,
		"enemy_name": current_enemy_squad.squad_name,
		"enemy_count": current_enemy_squad.get_living_warriors().size()
	}

func _get_squad_survival_stat(squad: StrategicSquad) -> float:
	var total: float = 0.0
	var count: int = 0
	for warrior in squad.get_living_warriors():
		if warrior.combat_stats:
			# Survival based on ACR (agility) + WIL
			total += warrior.combat_stats.acr + warrior.combat_stats.wil
		count += 1
	return total / max(count, 1) / 2.0  # Average of ACR+WIL

func _get_squad_diplomacy_stat(squad: StrategicSquad) -> float:
	var total: float = 0.0
	var count: int = 0
	for warrior in squad.get_living_warriors():
		if warrior.combat_stats:
			# Diplomacy based on CHA + INT
			total += warrior.combat_stats.cha + warrior.combat_stats.int_stat
		count += 1
	return total / max(count, 1) / 2.0  # Average of CHA+INT

func process_intermission_choice(choice: IntermissionChoice) -> CombatResult:
	print("\n[CombatController] Processing intermission choice: %s" % IntermissionChoice.keys()[choice])
	
	var result := CombatResult.new()
	
	match choice:
		IntermissionChoice.FIGHT:
			print("[CombatController] Player chose to FIGHT")
			result = _execute_combat()
		
		IntermissionChoice.FLEE:
			print("[CombatController] Player chose to FLEE")
			result = _attempt_flee()
		
		IntermissionChoice.NEGOTIATE:
			print("[CombatController] Player chose to NEGOTIATE")
			result = _attempt_negotiate()
	
	_end_combat(result)
	return result

func _attempt_flee() -> CombatResult:
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
		"success": roll < flee_chance
	}
	intermission_choice_made.emit("FLEE", roll_result)
	
	if roll < flee_chance:
		print("[CombatController]   SUCCESS - Squad escaped!")
		result.fled = true
		result.morale_change = -10.0  # Morale penalty for fleeing
	else:
		print("[CombatController]   FAILED - Forced to fight!")
		# Failed flee attempt - fight with penalty
		current_tactic = Tactic.create_defensive_formation()  # Forced defensive
		result = _execute_combat()
		result.morale_change -= 15.0  # Additional penalty for failed flee
	
	return result

func _attempt_negotiate() -> CombatResult:
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
		"success": roll < negotiate_chance
	}
	intermission_choice_made.emit("NEGOTIATE", roll_result)
	
	if roll < negotiate_chance:
		print("[CombatController]   SUCCESS - Conflict resolved peacefully!")
		result.negotiated = true
		result.morale_change = 5.0  # Small morale boost for diplomatic solution
	else:
		print("[CombatController]   FAILED - Negotiations broke down!")
		# Failed negotiate - fight normally
		result = _execute_combat()
		result.morale_change -= 5.0  # Small penalty for wasted time
	
	return result

func _execute_combat() -> CombatResult:
	print("\n[CombatController] EXECUTING TACTICAL COMBAT")
	print("-".repeat(40))
	
	var result := CombatResult.new()
	
	# Create battle via bridge
	var battle = combat_bridge.create_battle(current_player_squad, current_enemy_squad, current_tactic)
	print("[CombatController] Battle created with tactic: %s" % current_tactic.tactic_name)
	print("[CombatController]   Action count: %d, Reaction count: %d" % [current_tactic.action_count, current_tactic.reaction_count])
	print("[CombatController]   Attack modifier: %.2f, Defense modifier: %.2f" % [current_tactic.attack_modifier, current_tactic.defense_modifier])
	
	# Run combat rounds until victory or max rounds
	var max_rounds = 20
	while not battle.check_victory() and combat_phase < max_rounds:
		combat_phase += 1
		battle.round_count = combat_phase
		
		print("\n[CombatController] === COMBAT ROUND %d ===" % combat_phase)
		combat_phase_started.emit(combat_phase, current_tactic)
		
		# Execute squad actions
		var round_updates = battle.squad_actions()
		print("[CombatController] Round %d produced %d updates" % [combat_phase, round_updates.size()])
		
		for update in round_updates:
			all_updates.append(update)
			_log_entity_update(update)
		
		# Recovery phase
		battle.squad_recoveries()
		battle.remove_dead_entities()
		
		combat_phase_ended.emit(combat_phase, round_updates)
		result.turns_elapsed = combat_phase
	
	# Determine outcome
	var player_strength = battle.check_team_strength("player")
	var enemy_strength = battle.check_team_strength("enemy")
	
	print("\n[CombatController] COMBAT CONCLUDED")
	print("[CombatController] Final strengths - Player: %.1f, Enemy: %.1f" % [player_strength, enemy_strength])
	
	result.victory = player_strength > 0 and enemy_strength <= 0
	
	# Apply results to strategic squads
	var player_apply_result = combat_bridge.apply_results(current_player_squad, all_updates)
	print("[CombatController] Applied results to player squad:")
	print("[CombatController]   Deaths: %s" % [player_apply_result.deaths])
	print("[CombatController]   Injuries: %s" % [player_apply_result.injuries])
	
	for death_id in player_apply_result.deaths:
		result.player_casualties.append(death_id)
	
	# Calculate morale change based on outcome
	if result.victory:
		result.morale_change = 15.0 - (result.player_casualties.size() * 5.0)
		print("[CombatController] VICTORY! Morale change: %.1f" % result.morale_change)
		
		# Generate loot from enemy
		result.loot = _generate_loot(current_enemy_squad)
		print("[CombatController] Loot generated: %s" % [result.loot])
		
		# Drop clues from defeated enemy (pass current turn from battle)
		result.clues_dropped = _generate_enemy_clues(current_enemy_squad, combat_phase)
		print("[CombatController] Clues dropped: %d" % result.clues_dropped.size())
	else:
		result.morale_change = -20.0 - (result.player_casualties.size() * 5.0)
		print("[CombatController] DEFEAT! Morale change: %.1f" % result.morale_change)
	
	return result

func _log_entity_update(update: EntityUpdate) -> void:
	var source_name = _get_entity_name(update.source)
	var target_name = _get_entity_name(update.affected)
	var property_name = SquadBattleTypes.EntityChangeable.keys()[update.change.property]
	
	print("[CombatController]   %s → %s: %s %.1f → %.1f (Δ%.1f)" % [
		source_name, target_name, property_name,
		update.change.from, update.change.to,
		update.change.to - update.change.from
	])

func _get_entity_name(entity_id: int) -> String:
	if combat_bridge.current_battle:
		var entity = combat_bridge.current_battle.get_entity_by_id(entity_id)
		if entity:
			return entity.entity_name
	return "Entity#%d" % entity_id

func _generate_loot(enemy_squad: StrategicSquad) -> Dictionary:
	var loot = {
		"money": rng.randi_range(10, 50) * enemy_squad.get_living_warriors().size(),
		"food": rng.randi_range(1, 5)
	}
	print("[CombatController] Generated loot from %s: %s" % [enemy_squad.squad_name, loot])
	return loot

func _generate_enemy_clues(enemy_squad: StrategicSquad, current_turn: int = 0) -> Array[Clue]:
	var clues: Array[Clue] = []
	# 30% chance to drop a clue about enemy movements
	if rng.randf() < 0.3 and enemy_squad.get_living_warriors().size() > 0:
		var warrior = enemy_squad.get_living_warriors()[0]
		var clue = Clue.create_clue(
			Clue.get_random_clue_name(StrategyTypes.Religion.PAGAN),
			enemy_squad.squad_id,
			warrior.warrior_id,
			current_turn,
			3,  # stealth_failure_margin (detail level)
			enemy_squad.current_location_id  # destination
		)
		clues.append(clue)
		print("[CombatController] Enemy dropped clue: %s" % clue.clue_name)
	return clues

func _end_combat(result: CombatResult) -> void:
	print("\n[CombatController] COMBAT ENDED")
	print("[CombatController] Result: %s" % result)
	print("=".repeat(60) + "\n")
	
	is_in_combat = false
	combat_ended.emit(result)
	combat_bridge.clear_mappings()

#endregion

#region Tactic Management

func set_tactic(tactic: Tactic) -> void:
	current_tactic = tactic
	print("[CombatController] Tactic set to: %s" % tactic.tactic_name)

func set_tactic_by_type(tactic_type: Tactic.TacticType) -> void:
	current_tactic = Tactic.create_from_type(tactic_type)
	print("[CombatController] Tactic set by type: %s → %s" % [Tactic.TacticType.keys()[tactic_type], current_tactic.tactic_name])

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
