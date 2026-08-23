class_name MonsterSpawnSystem
extends Node

## Owns "what to spawn" only — registration with World/SquadBeingSystem/SquadAISystem happens in main.gd's squad_spawned handler (composition-root convention, see AGENTS.md's Systems Layer).
## Each warrior gets a minimal StrategyEntity carrying only MV_SPD+MORALE, since travel/morale assert(strategy != null) even though monsters are template-only combat entities.

signal squad_spawned(squad: StrategySquad)

const MONSTER_TEMPLATE_ID := "feral_beast"

var scenario: GameScenario


func setup(_scenario: GameScenario) -> void:
	assert(_scenario != null, "MonsterSpawnSystem requires a GameScenario")
	scenario = _scenario


## Builds a squad seeded mid-edge on a random outgoing connection — no "spawn sitting in a town" step. Returns null if the location is unknown or has no outgoing connections.
func spawn_at(near_location_id: String) -> StrategySquad:
	var loc := scenario.world.get_location_by_id(near_location_id)
	if loc == null or loc.connections == null or loc.connections.tt.is_empty():
		return null

	var edge: TownConnection = loc.connections.tt[randi() % loc.connections.tt.size()]
	var warrior_count := randi_range(1, 3)

	var squad := SquadDataFactory.create_squad(
		"monster_%d" % int(randf() * 1000000.0),
		"Monster Pack",
		0.0,
		warrior_count * 10,
		0,
		0.0,
		edge.from_location_id,
		edge.from_location_id,
		StrategyTypes.SquadRole.MONSTER,
	)

	for i in range(warrior_count):
		var res := StrategyEntityResource.new()
		res.name = "Feral Beast"

		var speed_stat := ReactiveStat.new()
		speed_stat.stat_name = StatName.I.MV_SPD
		speed_stat.stat_value = 8.0
		var morale_stat := ReactiveStat.new()
		morale_stat.stat_name = StatName.I.MORALE
		morale_stat.stat_value = 1.0
		res.rs_array = [speed_stat, morale_stat]

		squad.add_warrior(Character.new(StrategyEntity.new(res), MONSTER_TEMPLATE_ID))

	squad.travel_route = [edge.from_location_id, edge.to_location_id]
	squad.travel_segment_index = 0
	squad.travel_progress_km = randf_range(0.0, edge.distance_km)
	squad.current_activity_type = StrategyTypes.ActivityType.TRAVEL

	LogGd.debug("[MonsterSpawnSystem] spawned %s (%d warriors) mid-edge %s -> %s" % [
		squad.squad_id, warrior_count, edge.from_location_id, edge.to_location_id,
	])
	squad_spawned.emit(squad)
	return squad


func _on_spawn_triggered(near_location_id: String) -> void:
	spawn_at(near_location_id)
