class_name BanditSpawner extends Spawner

const SPAWN_THRESHOLD := 0.3
const SPAWN_RATE := 0.5
const MAX_BANDITS_PER_LOCATION := 2
const BANDIT_PROFILE_PATH := "res://resources/ai/strategic/profiles/bandit-raider.tres"


static var _bandit_names: Array[String] = [
	"Black Wolves", "Road Reapers", "Iron Fangs", "Ash Marauders",
	"Ravenclaw Gang", "Gutter Rats", "Wretched Ones", "Bone Pickers",
	"Hollow Men", "Salt Thieves", "Rust Brotherhood", "Ditch Crawlers",
]


func calculate_pressure(location: Location, world: World = null) -> float:
	assert(world != null, "Bandit pressure calculation requires world context")
	assert(world.economy_engine != null, "Bandit pressure calculation requires initialized economy engine")
	var pressure_cs := world.economy_engine.get_bandit_pressure(location.location_id)
	if pressure_cs > 0.0:
		return pressure_cs

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


static func count_bandits_at_location(location_id: String, world: World) -> int:
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

func _check_bandit_disband(squad: SquadData) -> bool:
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

func _create_warrior(squad_id: String, index: int, background_id: StringName) -> Warrior:
	var warrior = super._create_warrior(squad_id, index, background_id)
	warrior.morale = randf_range(20.0, 30.0)
	warrior.set_attribute(StrategyTypes.WarriorAttribute.PERCEPTION, randi_range(20, 40))
	warrior.set_attribute(StrategyTypes.WarriorAttribute.STEALTH, randi_range(10, 15))
	warrior.set_attribute(StrategyTypes.WarriorAttribute.SURVIVAL, randi_range(30, 50))
	return warrior
