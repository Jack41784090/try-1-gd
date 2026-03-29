extends RefCounted

class_name CombatBridge

# signal combat_requested(player_squad: SquadData, enemy_squad: SquadData, context: Dictionary)
# signal combat_phase_completed(updates: Array[EntityUpdate])
# signal combat_ended(result: Dictionary)

var warrior_to_entity: Dictionary = { }
var entity_to_warrior: Dictionary = { }
var current_battle: SquadBattle = null
var player_combat_squad: CombatSquad = null
var enemy_combat_squad: CombatSquad = null
var current_tactic: Tactic = null
var _next_entity_id: int = 1


func create_battle(
		player_squad: SquadData,
		enemy_squad: SquadData,
		tactic: Tactic,
) -> SquadBattle:
	# Creates a tactical SquadBattle from two strategic squads, translating Warrior → CombatEntity entities
	# e.g., player squad "Wolves" (3 warriors) vs enemy "Raiders" (4 warriors)
	#   → builds entity configs for each warrior, assigns entity IDs, creates SquadBattle
	#
	# 1. Clear previous ID mappings (warrior_id ↔ entity_id)
	clear_mappings()
	current_tactic = tactic

	# 2. Convert each squad's warriors into entity configs for the tactical layer
	# e.g., player_squad: [Warrior(id="w1", str=8, agi=6)] → [{entity_id: 1, team: "player", stats: {FOR: 8, ACR: 6, ...}}]
	var player_squad_config = _build_squad_config(player_squad, "player", SquadBattleTypes.Side.ATTACKER)
	var enemy_squad_config = _build_squad_config(enemy_squad, "enemy", SquadBattleTypes.Side.DEFENDER)

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
	# The SquadBattle._init() will create CombatSquad + CombatEntity entities from these configs
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
	if current_battle.teams_and_squads.has("player") and current_battle.teams_and_squads["player"].size() > 0:
		player_combat_squad = current_battle.teams_and_squads["player"][0]
	if current_battle.teams_and_squads.has("enemy") and current_battle.teams_and_squads["enemy"].size() > 0:
		enemy_combat_squad = current_battle.teams_and_squads["enemy"][0]

	return current_battle


func apply_injury_penalties(strategic_squad: SquadData) -> void:
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
		Log.info("CombatBridge", "Injured warrior '%s' starts at %.0f/%.0f HP" % [warrior.name, max_hp - penalty, max_hp])


func _build_squad_config(strategic_squad: SquadData, team: String, side: SquadBattleTypes.Side) -> Dictionary:
	# Converts a strategic squad's warriors into tactical entity configs
	# Maps each Warrior warrior → entity config dict with combat stats
	# Also builds the bi-directional ID mapping: warrior_id ↔ entity_id
	# e.g., Warrior(id="w1", name="Hans", str=8) → {entity_id: 1, team: "player", base_stats: {FOR: 8, ...}}
	var entity_configs: Array = []
	var living_warriors = strategic_squad.get_living_warriors()
	var formation = strategic_squad.formation

	for i in range(living_warriors.size()):
		var warrior: Warrior = living_warriors[i]
		var entity_id = _next_entity_id
		_next_entity_id += 1

		# Build the warrior ↔ entity ID mapping for post-combat result translation
		# e.g., warrior_to_entity["w1"] = 1, entity_to_warrior[1] = "w1"
		warrior_to_entity[warrior.id] = entity_id
		entity_to_warrior[entity_id] = warrior.id

		# Use formation-defined position if available, otherwise use warrior's default
		# e.g., formation=[Front, Middle, Back] → warrior[0] starts at Front
		var starting_loc = warrior.location_prebattle
		if i < formation.size():
			starting_loc = formation[i] as SquadBattleTypes.SquadEntityInSquadLocation

		# Convert the Warrior warrior into a tactical entity config dict
		# This uses warrior.convert_to_entity() which maps social stats → combat stats
		var entity_config = warrior.convert_to_entity(entity_id, team, starting_loc)
		entity_configs.append(entity_config)

	var squad_config = {
		"entities": entity_configs,
		"name": strategic_squad.squad_name,
		"team": team,
		"side": side,
	}

	return squad_config


func apply_results(strategic_squad: SquadData, updates: Array[EntityUpdate]) -> Dictionary:
	# Translates tactical combat outcomes (EntityUpdate[]) back into strategic warrior state changes
	# Maps entity_id back to warrior_id using the bridge's ID mapping
	# e.g., EntityUpdate(entity=1, HP: 100→30) → warrior "w1" becomes injured, morale drops by 14.0
	# e.g., EntityUpdate(entity=2, HP: 50→0) → warrior "w2" marked dead, added to deaths list
	var result = {
		"deaths": [],
		"injuries": [],
		"escaped": [],
		"morale_changes": { },
	}

	for update in updates:
		# 1. Translate entity_id back to warrior_id
		# e.g., entity_id=1 → warrior_id="w1" (via entity_to_warrior mapping)
		var warrior_id = get_warrior_for_entity(update.affected)
		if warrior_id.is_empty():
			continue

		var warrior = strategic_squad.get_warrior_by_id(warrior_id)
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
					warrior.morale = 0.0
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
				warrior.morale = 0.0
				if not result.deaths.has(warrior_id):
					result.deaths.append(warrior_id)
			SquadBattleTypes.EntityChangeable.CAPITULATE:
				warrior.is_injured = true
				if not result.escaped.has(warrior_id):
					result.escaped.append(warrior_id)

	# 3. Clean up the strategic squad — recalculate average morale and remove corpses
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
		return { }

	return {
		"player_strength": current_battle.check_team_strength("player"),
		"enemy_strength": current_battle.check_team_strength("enemy"),
		"round_count": current_battle.round_count,
		"tactic": current_tactic.tactic_name if current_tactic else "None",
	}
