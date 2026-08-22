class_name MonsterSpawnSystem
extends Node

## Owns "what to spawn" for roaming monster squads — composition/identity
## only. Never touches World/SquadBeingSystem/SquadAISystem directly; those
## registration steps happen in main.gd's squad_spawned handler (the
## composition-root convention documented in AGENTS.md's Systems Layer
## section — no system may hold a reference to, preload, or call another
## system directly).
##
## Monster warriors are template-only combat entities (Character.new with
## strategy=null would be enough for combat alone), but a monster squad also
## lives in the strategic layer — travel/morale read Character.get_speed_kmh()/
## modify_morale(), both of which assert(strategy != null). So each warrior
## gets a minimal StrategyEntity (same shape main.gd._build_test_squad() uses)
## carrying only MV_SPD+MORALE, with combat_identification passed explicitly
## so combat still resolves off the feral_beast template regardless.

signal squad_spawned(squad: StrategySquad)

const MONSTER_TEMPLATE_ID := "feral_beast"

var scenario: GameScenario


func setup(_scenario: GameScenario) -> void:
	assert(_scenario != null, "MonsterSpawnSystem requires a GameScenario")
	scenario = _scenario


## Public entry point (also directly unit-testable): resolves near_location_id,
## picks a random outgoing TownConnection off it, and builds a squad seeded
## mid-edge along that connection — travel_route/travel_progress_km already
## populated, no "spawn sitting in a town" step. Returns null (no emit) if the
## location is unknown or has no outgoing connections.
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


## Thin wrapper — the slot main.gd wires to SinInheringSystem.spawn_triggered.
func _on_spawn_triggered(near_location_id: String) -> void:
	spawn_at(near_location_id)
