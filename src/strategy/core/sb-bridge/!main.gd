class_name CombatBridge
extends RefCounted

var warrior_to_entity: Dictionary = {}
var entity_to_warrior: Dictionary = {}
var current_battle: SquadBattle = null
var player_combat_squad: CombatSquad = null
var enemy_combat_squad: CombatSquad = null
var current_tactic: Tactic = null
var _next_entity_id: int = 1


func create_battle(
		player_squad: StrategySquad,
		enemy_squad: StrategySquad,
		tactic: Tactic,
) -> SquadBattle:
	# Creates a tactical SquadBattle from two strategic squads, translating Character → CombatEntity
	# e.g., player squad "Wolves" (3 warriors) vs enemy "Raiders" (4 warriors)
	#   → each warrior enters battle via Character.enter_battle(), assigns entity IDs, creates SquadBattle
	#
	# 1. Clear previous ID mappings (warrior_id ↔ entity_id)
	clear_mappings()
	current_tactic = tactic

	# 2. Convert each squad's warriors into CombatEntity instances for the tactical layer
	var player_squad_config = _build_squad_config(player_squad, SquadBattleTypes.Side.ATTACKER)
	var enemy_squad_config = _build_squad_config(enemy_squad, SquadBattleTypes.Side.DEFENDER)

	print("[CombatBridge] Creating battle with config:")
	print("[CombatBridge]   Player squad: %s (%d entities)" % [player_squad_config.name, player_squad_config.entities.size()])
	print("[CombatBridge]   Enemy squad: %s (%d entities)" % [enemy_squad_config.name, enemy_squad_config.entities.size()])
	print(
		"[CombatBridge]   Attacker Tactic: %s (actions=%d, reactions=%d)" % [
			tactic.tactic_name,
			tactic.action_count,
			tactic.reaction_count,
		],
	)

	# 3. Enemy uses balanced tactic by default (equal action/reaction counts)
	var enemy_tactic = Tactic.create_balanced()

	# 4. Construct the actual SquadBattle with both teams' configs and tactics
	current_battle = SquadBattle.new(
		{
			"teams": {
				SquadBattleTypes.Side.ATTACKER: [player_squad_config],
				SquadBattleTypes.Side.DEFENDER: [enemy_squad_config],
			},
			"attacker_tactic": tactic,
			"defender_tactic": enemy_tactic,
		},
	)

	# 5. Cache references to CombatSquad for later result retrieval
	var attacker_squads: Array = current_battle.teams_and_squads.get(SquadBattleTypes.Side.ATTACKER, [])
	if attacker_squads.size() > 0:
		player_combat_squad = attacker_squads[0]
	var defender_squads: Array = current_battle.teams_and_squads.get(SquadBattleTypes.Side.DEFENDER, [])
	if defender_squads.size() > 0:
		enemy_combat_squad = defender_squads[0]

	return current_battle


func apply_injury_penalties(strategic_squad: StrategySquad) -> void:
	assert(current_battle != null)
	for warrior in strategic_squad.get_living_warriors():
		if not warrior.is_injured:
			continue
		var entity_id = warrior_to_entity.get(warrior.id, -1)
		if entity_id == -1:
			continue
		var entity = current_battle.get_entity_by_id(entity_id)
		if entity == null:
			continue
		var max_hp = entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
		var penalty = max_hp * 0.5
		entity.mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, -penalty)
		Log.info("CombatBridge", "Injured warrior '%s' starts at %.0f/%.0f HP" % [warrior.display_name, max_hp - penalty, max_hp])


func _build_squad_config(strategic_squad: StrategySquad, side: SquadBattleTypes.Side) -> Dictionary:
	# Converts a strategic squad's warriors into pre-built CombatEntity instances
	# Maps each Character warrior → CombatEntity via Character.enter_battle()
	# Also builds the bi-directional ID mapping: warrior_id ↔ entity_id
	# e.g., Character(id="w1", name="Hans") → entity_id 1, warrior_to_entity["w1"] = 1
	var combat_entities: Array[CombatEntity] = []
	var living_warriors = strategic_squad.get_living_warriors()
	var formation = strategic_squad.formation

	for i in range(living_warriors.size()):
		var character: Character = living_warriors[i]
		var entity_id = _next_entity_id
		_next_entity_id += 1

		# Build the warrior ↔ entity ID mapping for post-combat result translation
		# e.g., warrior_to_entity["w1"] = 1, entity_to_warrior[1] = "w1"
		warrior_to_entity[character.id] = entity_id
		entity_to_warrior[entity_id] = character.id

		# Use formation-defined position if available, otherwise use warrior's default
		# e.g., formation=[Front, Middle, Back] → warrior[0] starts at Front
		var starting_loc = character.location_prebattle
		if i < formation.size():
			starting_loc = formation[i] as SquadBattleTypes.SquadEntityInSquadLocation

		combat_entities.append(character.enter_battle(side, entity_id, starting_loc))

	return {
		"entities": combat_entities,
		"name": strategic_squad.squad_name,
		"side": side,
	}


func apply_results(strategic_squad: StrategySquad, updates: Array[EntityUpdate]) -> Dictionary:
	# Translates tactical combat outcomes (EntityUpdate[]) back into strategic warrior state changes
	# Maps entity_id back to warrior_id using the bridge's ID mapping
	# e.g., EntityUpdate(entity=1, HP: 100→30) → warrior "w1" becomes injured, morale drops by 14.0
	# e.g., EntityUpdate(entity=2, HP: 50→0) → warrior "w2" marked dead, added to deaths list
	var result = {
		"deaths": [],
		"injuries": [],
		"escaped": [],
		"morale_changes": {},
	}

	for update in updates:
		# 1. Translate entity_id back to warrior_id
		# e.g., entity_id=1 → warrior_id="w1" (via entity_to_warrior mapping)
		var warrior_id = get_warrior_for_entity(update.affected)
		if warrior_id.is_empty():
			continue

		var warrior := strategic_squad.get_warrior_by_id(warrior_id)
		if warrior == null:
			continue

		# 2. Apply the change based on which stat was modified
		match update.change.property:
			SquadBattleTypes.EntityChangeable.HP:
				# HP damage → check for death or injury
				# e.g., from_hp=100, to_hp=0 → warrior dies
				# e.g., from_hp=100, to_hp=30 → warrior injured, morale loss = (70/100) * 20 = 14.0
				var from_hp = update.change.from
				var to_hp = update.change.to

				if to_hp <= 0:
					warrior.is_dead = true
					warrior.get_stat(StatName.I.MORALE).stat_value = 0.0
					result.deaths.append(warrior_id)
				elif to_hp < from_hp:
					warrior.is_injured = true
					var damage_ratio = (from_hp - to_hp) / from_hp if from_hp > 0 else 0.0
					var morale_loss = damage_ratio * 20.0
					warrior.modify_morale(-morale_loss)
					result.injuries.append(warrior_id)
					result.morale_changes[warrior_id] = -morale_loss
			SquadBattleTypes.EntityChangeable.ORG:
				# Organization change → morale effect at 0.5x rate
				# e.g., ORG from 50 to 30 (drop of 20) → morale change = -10
				var org_change = update.change.to - update.change.from
				var morale_change = org_change * 0.5
				warrior.modify_morale(morale_change)
				if result.morale_changes.has(warrior_id):
					result.morale_changes[warrior_id] += morale_change
				else:
					result.morale_changes[warrior_id] = morale_change
			SquadBattleTypes.EntityChangeable.DIE:
				# Explicit death flag (from skills like Execute)
				warrior.is_dead = true
				warrior.get_stat(StatName.I.MORALE).stat_value = 0.0
				if not result.deaths.has(warrior_id):
					result.deaths.append(warrior_id)
			SquadBattleTypes.EntityChangeable.CAPITULATE:
				warrior.is_injured = true
				if not result.escaped.has(warrior_id):
					result.escaped.append(warrior_id)

	# 3. Release the ephemeral tier-3 CombatEntity for everyone who fought — the battle is over
	for warrior in strategic_squad.warriors:
		if warrior.combat != null:
			warrior.exit_battle()

	# 4. Clean up the strategic squad — recalculate average morale and remove corpses
	strategic_squad.update_aggregate_morale()
	strategic_squad.remove_dead_warriors()

	return result


func get_warrior_for_entity(entity_id: int) -> String:
	if entity_to_warrior.has(entity_id):
		return entity_to_warrior[entity_id]
	return ""


func get_entity_for_warrior(warrior_id: String) -> int:
	return warrior_to_entity.get(warrior_id, -1)


func clear_mappings() -> void:
	warrior_to_entity.clear()
	entity_to_warrior.clear()
	current_battle = null
	player_combat_squad = null
	enemy_combat_squad = null
	current_tactic = null
	_next_entity_id = 1


func get_battle_summary() -> Dictionary:
	if not current_battle:
		return {}

	return {
		"player_strength": current_battle.check_team_strength(SquadBattleTypes.Side.ATTACKER),
		"enemy_strength": current_battle.check_team_strength(SquadBattleTypes.Side.DEFENDER),
		"round_count": current_battle.round_count,
		"tactic": current_tactic.tactic_name if current_tactic else "None",
	}
