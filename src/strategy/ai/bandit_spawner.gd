class_name BanditSpawner
extends RefCounted

const SPAWN_THRESHOLD := 0.3
const SPAWN_RATE := 0.5
const MAX_BANDITS_PER_LOCATION := 2
const DISBAND_MORALE_THRESHOLD := 15.0
const BANDIT_PROFILE_PATH := "res://resources/ai/strategic/profiles/bandit-raider.tres"

var _spawn_counter: int = 0

static var _bandit_names: Array[String] = [
	"Black Wolves", "Road Reapers", "Iron Fangs", "Ash Marauders",
	"Ravenclaw Gang", "Gutter Rats", "Wretched Ones", "Bone Pickers",
	"Hollow Men", "Salt Thieves", "Rust Brotherhood", "Ditch Crawlers",
]


func calculate_pressure(location: Location) -> float:
	if location.population == null:
		return 0.0
	var people := location.population.people
	if people.is_empty():
		return 0.0

	var total_satisfaction := 0.0
	var peasant_count := 0
	for person in people:
		total_satisfaction += person.satisfaction
		if person.social_class == EconomyTypes.SocialClass.PEASANT:
			peasant_count += 1

	var avg_satisfaction := total_satisfaction / float(people.size())
	var peasant_ratio := float(peasant_count) / float(people.size())
	var population_scale := clampf(sqrt(float(people.size()) / 200.0), 0.5, 2.0)

	var pressure := (100.0 - avg_satisfaction) / 100.0 * peasant_ratio * population_scale
	return pressure


func should_spawn(pressure: float) -> bool:
	if pressure <= SPAWN_THRESHOLD:
		return false
	var spawn_chance := (pressure - SPAWN_THRESHOLD) * SPAWN_RATE
	return randf() < spawn_chance


func count_bandits_at_location(location_id: String, world: World) -> int:
	var count := 0
	for squad in world.roaming_squads:
		if squad.squad_role == StrategyTypes.SquadRole.BANDIT and squad.current_location_id == location_id:
			count += 1
	for squad in world.roaming_squads:
		if squad.squad_role == StrategyTypes.SquadRole.BANDIT:
			for conn in world.get_location_by_id(location_id).connections.tt:
				if squad.current_location_id == conn.to_location_id:
					count += 1
					break
	return count


func count_total_bandits(world: World) -> int:
	var count := 0
	for squad in world.roaming_squads:
		if squad.squad_role == StrategyTypes.SquadRole.BANDIT:
			count += 1
	return count


func get_max_bandits(world: World) -> int:
	return world.locations.size() * 2


func create_bandit_squad(location: Location, world: World) -> SquadData:
	_spawn_counter += 1
	var squad := SquadData.new()
	squad.squad_id = "bandit_%s_%d" % [location.location_id, _spawn_counter]
	squad.squad_name = _bandit_names[_spawn_counter % _bandit_names.size()]

	var spawn_location := _pick_spawn_neighbor(location, world)
	squad.starting_location_id = spawn_location.location_id
	squad.current_location_id = spawn_location.location_id
	squad.squad_role = StrategyTypes.SquadRole.BANDIT
	squad.money = randf_range(5.0, 20.0)
	squad.food = randi_range(2, 5)
	squad.karma = -80.0

	var warrior_count := randi_range(1, 4)
	var classes: Array[EntityClasses.Types] = [
		EntityClasses.Types.Landsknecht,
		EntityClasses.Types.Pikeman,
	]
	for i in range(warrior_count):
		var class_id: EntityClasses.Types = classes[i % classes.size()]
		var warrior := _create_bandit_warrior(squad.squad_id, i, class_id)
		squad.add_warrior(warrior)

	Log.info("BanditSpawner", "Spawned %s (%d warriors) near %s at %s" % [
		squad.squad_name, warrior_count, location.location_id, spawn_location.location_id])
	return squad


func check_disband(squad: SquadData) -> bool:
	if squad.squad_role != StrategyTypes.SquadRole.BANDIT:
		return false
	if squad.get_living_warriors().is_empty():
		return true
	if squad.get_morale() < DISBAND_MORALE_THRESHOLD:
		return true
	var all_injured := true
	for w in squad.get_living_warriors():
		if not w.is_injured:
			all_injured = false
			break
	return all_injured


func tick_spawning(world: World, bandit_faction: Faction, ai_fleet: AIFleetManager) -> Array[String]:
	var event_log: Array[String] = []
	var total_bandits := count_total_bandits(world)
	var max_bandits := get_max_bandits(world)

	for loc in world.locations:
		if loc.type == StrategyTypes.LocationType.FORT:
			continue
		if loc.population == null:
			continue
		if total_bandits >= max_bandits:
			break
		if count_bandits_at_location(loc.location_id, world) >= MAX_BANDITS_PER_LOCATION:
			continue

		var pressure := calculate_pressure(loc)
		if not should_spawn(pressure):
			continue

		var squad := create_bandit_squad(loc, world)
		world.add_roaming_squad(squad)
		bandit_faction.add_army(squad)
		_register_bandit_brain(squad, ai_fleet)
		total_bandits += 1
		event_log.append("BANDIT spawned %s near %s (pressure=%.2f)" % [
			squad.squad_name, loc.location_id, pressure])

	return event_log


func tick_cleanup(world: World, bandit_faction: Faction, ai_fleet: AIFleetManager) -> Array[String]:
	var event_log: Array[String] = []
	var to_remove: Array[String] = []

	for squad in world.roaming_squads:
		if squad.squad_role != StrategyTypes.SquadRole.BANDIT:
			continue
		if check_disband(squad):
			to_remove.append(squad.squad_id)

	for squad_id in to_remove:
		world.remove_roaming_squad(squad_id)
		bandit_faction.remove_army(squad_id)
		ai_fleet.unregister_squad(squad_id)
		event_log.append("BANDIT disbanded %s" % squad_id)
		Log.info("BanditSpawner", "Disbanded bandit squad: %s" % squad_id)

	return event_log


func _pick_spawn_neighbor(location: Location, _world: World) -> Location:
	if location.connections == null or location.connections.tt.is_empty():
		return location
	var neighbors: Array[Location] = []
	for conn in location.connections.tt:
		var neighbor := _world.get_location_by_id(conn.to_location_id)
		if neighbor:
			neighbors.append(neighbor)
	if neighbors.is_empty():
		return location
	return neighbors[randi() % neighbors.size()]


func _create_bandit_warrior(squad_id: String, index: int, class_id: EntityClasses.Types) -> Warrior:
	var warrior := WarriorFactory.create_warrior(
		class_id,
		"%s_w%d" % [squad_id, index],
		"Bandit",
		StrategyTypes.Religion.CATHOLIC,
		EntityBaseStats.new(),
	)
	warrior.morale = randf_range(40.0, 60.0)
	warrior.set_attribute(StrategyTypes.WarriorAttribute.PERCEPTION, randi_range(20, 40))
	warrior.set_attribute(StrategyTypes.WarriorAttribute.STEALTH, randi_range(10, 15))
	warrior.set_attribute(StrategyTypes.WarriorAttribute.SURVIVAL, randi_range(30, 50))
	return warrior


func _register_bandit_brain(squad: SquadData, ai_fleet: AIFleetManager) -> void:
	ai_fleet.register_bandit(squad, BANDIT_PROFILE_PATH)
