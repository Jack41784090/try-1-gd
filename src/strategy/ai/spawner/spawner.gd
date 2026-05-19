class_name Spawner extends RefCounted

var DISBAND_MORALE_THRESHOLD := 0.0
var _spawn_counter: int = 0

#region DISBANDING
func _disband_if_all_dead(squad: SquadData):
	return squad.get_living_warriors().is_empty()

func _disband_if_morale_crumbles(squad: SquadData):
	return squad.get_morale() <= self.DISBAND_MORALE_THRESHOLD

func _disband_if_all_injured(squad: SquadData):
	var all_injured := true
	for w in squad.get_living_warriors():
		if not w.is_injured:
			all_injured = false
			break
	return all_injured

func check_disband(squad: SquadData) -> bool:
	return \
		_disband_if_all_dead(squad) or \
		_disband_if_morale_crumbles(squad) or \
		_disband_if_all_injured(squad)

func tick_cleanup(world: World, faction: Faction, ai_fleet: AISquadManager) -> Array[String]:
	var event_log: Array[String] = []
	var to_remove: Array[String] = []

	for squad in world.roaming_squads:
		if check_disband(squad):
			to_remove.append(squad.squad_id)

	for squad_id in to_remove:
		world.remove_roaming_squad(squad_id)
		faction.remove_army(squad_id)
		ai_fleet.unregister_squad(squad_id)
		event_log.append("disbanded %s" % squad_id)
		Log.info("BanditSpawner", "Disbanded bandit squad: %s" % squad_id)

	return event_log
#endregion

#region SPAWNING

func _create_warrior(squad_id: String, index: int, background_id: StringName) -> Warrior:
	var warrior := WarriorFactory.create_warrior(
		background_id,
		"%s_w%d" % [squad_id, index],
		"Warrior",
		StrategyTypes.Religion.CATHOLIC,
	)
	warrior.morale = randf_range(40.0, 60.0)
	return warrior

func _create_squad(location: Location, world: World) -> SquadData:
	_spawn_counter += 1
	var spawn_location := location
	var squad: SquadData = SquadDataFactory.create_squad(
		"squad_%d" % int(randf() * 1000000.0),
		"Squad %d" % _spawn_counter,
		randf_range(5.0, 20.0),
		randi_range(2, 5),
		5,
		-80.0,
		spawn_location.location_id,
		spawn_location.location_id,
		StrategyTypes.SquadRole.BANDIT,
	)

	var warrior_count := randi_range(1, 4)
	var backgrounds: Array[StringName] = [&"landsknecht", &"pikeman"]
	for i in range(warrior_count):
		var background_id: StringName = backgrounds[i % backgrounds.size()]
		var warrior := _create_warrior(squad.squad_id, i, background_id)
		squad.add_warrior(warrior)

	Log.info("BanditSpawner", "Spawned %s (%d warriors) near %s at %s" % [
		squad.squad_name, warrior_count, location.location_id, spawn_location.location_id])
	return squad

func tick_spawning(_world: World, _faction: Faction, _ai_fleet: AISquadManager) -> Array[String]:
	var event_log: Array[String] = []
	return event_log


func spawning(world: World, locs: Array[Location], faction: Faction, ai_fleet: AISquadManager) -> Array[String]:
	var event_log: Array[String] = []
	# var total_bandits := count_total_bandits(world)

	for loc in locs:
		var squad := _create_squad(loc, world)
		
		world.add_roaming_squad(squad)
		faction.add_army(squad)
		# ai_fleet.register_bandit(squad)
		# total_bandits += 1
		
		event_log.append("BANDIT spawned %s near %s" % [
			squad.squad_name, loc.location_id])

	return event_log
#endregion