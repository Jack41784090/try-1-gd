## Trade-network stress test: 30 locations in a long-haul ring + long-range chords, 7 goods, and
## deliberately lopsided natural-resource specialties (every location exports ~2 goods, imports
## the other 5) so almost every location runs an hourly deficit on most goods. Meant to push
## CaravanEconomySystem/SquadActingSystem/SquadTravelSystem to real scale — dozens of concurrent
## multi-hour convoys — not to cap anything. Source data for tools/bake_stress_test_scenario.gd,
## which bakes it into resources/strategy/scenarios/debug/stress-test-trade.tres — swap that in
## for main.gd's DEBUG-only `debug_scenario` export to run it instead of the small prototype
## sandbox. Kept isolated from main.gd's production load_scenario() path, same as MainTestScenario.
class_name StressTestScenario
extends RefCounted

const LOCATION_COUNT := 100
const RING_HOP_KM := 120.0   # base_speed 8km/h -> ~15h per ring hop, halved to 4km/h for a caravan (see StrategySquad.get_speed_kmh) -> ~30h
const CHORD_KM := 380.0      # long-range shortcut: ~95h at caravan speed — the "long distances" case
const CHORD_STRIDE := 6      # every 6th location also gets one chord straight across the ring


static func build_squads() -> Array[StrategySquad]:
	# .duplicate(true): ResourceLoader.load() returns the shared cached instance for that path —
	# mutating it in place would corrupt the cache and, when baked, would save only an
	# ext_resource reference back to the pristine file (silently dropping these overrides).
	var player_squad: StrategySquad = ResourceLoader.load("res://resources/strategy/squads-presets/test-player-squad-full.tres").duplicate(true)
	player_squad.food = 1500
	player_squad.current_location_id = "loc00"
	var squads: Array[StrategySquad] = [player_squad]
	return squads


static func build_scenario() -> GameScenario:
	var scenario := GameScenario.new()
	scenario.world = build_world()
	scenario.starting_location_id = "loc00"
	scenario.triggerable_manager = TriggerableManager.new()
	scenario.triggerable_manager.register(load("res://resources/strategy/generic-activities/travelling/travel.tres"))
	scenario.triggerable_manager.register(load("res://resources/strategy/generic-activities/rest/rest.tres"))
	scenario.triggerable_manager.register(load("res://resources/strategy/generic-activities/forage/forage.tres"))
	return scenario


static func build_goods() -> Array[Thing]:
	return [
		Thing.create("grain", "Grain", EconomyTypes.ThingType.FOOD, 2.0),
		Thing.create("fish", "Salted Fish", EconomyTypes.ThingType.FOOD, 3.0),
		Thing.create("cloth", "Cloth", EconomyTypes.ThingType.CLOTH, 6.0),
		Thing.create("tools", "Tools", EconomyTypes.ThingType.TOOLS, 10.0),
		Thing.create("ore", "Iron Ore", EconomyTypes.ThingType.TOOLS, 8.0),
		Thing.create("weapons", "Weapons", EconomyTypes.ThingType.WEAPONS, 25.0),
		Thing.create("wine", "Wine", EconomyTypes.ThingType.LUXURY, 15.0),
	]


static func build_world() -> World:
	var world := World.new()
	world.current_hour = 0
	var goods := build_goods()
	world.goods = goods

	var locations: Array[Location] = []
	for i in range(LOCATION_COUNT):
		locations.append(_build_location(i, goods))

	# Ring keeps the whole network connected with short-ish hops; chords add a handful of
	# long-range shortcuts so pathfinding has more than one topology shape to route through.
	for i in range(LOCATION_COUNT):
		var loc := locations[i]
		var next := locations[(i + 1) % LOCATION_COUNT]
		loc.add_connection(next.location_id, RING_HOP_KM)
		next.add_connection(loc.location_id, RING_HOP_KM)
		if i % CHORD_STRIDE == 0:
			var far := locations[(i + LOCATION_COUNT / 2) % LOCATION_COUNT]
			loc.add_connection(far.location_id, CHORD_KM)
			far.add_connection(loc.location_id, CHORD_KM)

	for loc in locations:
		world.add_location(loc)
	world.build_travel_graph()
	return world


static func _build_location(index: int, goods: Array[Thing]) -> Location:
	var loc := Location.new()
	loc.location_id = "loc%02d" % index
	loc.location_name = "Trade Post %02d" % index
	loc.type = [StrategyTypes.LocationType.VILLAGE, StrategyTypes.LocationType.TOWN, StrategyTypes.LocationType.CITY][index % 3]
	loc.development = 20 + (index % 5) * 10
	loc.stability = 50.0 + (index % 7) * 6.0
	loc.inventory = LocationInventory.new()
	for thing in goods:
		loc.inventory.init_thing(thing, 0.0)

	# Every location exports its primary + secondary specialty and imports the other 5 goods —
	# guarantees a deficit/surplus gradient everywhere so the caravan matcher always has work.
	var primary: Thing = goods[index % goods.size()]
	var secondary: Thing = goods[(index + 1) % goods.size()]
	loc.natural_resources = [
		NaturalResource.create(primary, 18.0),
		NaturalResource.create(secondary, 6.0),
	]
	loc.inventory.init_thing(primary, 10.0)
	loc.inventory.init_thing(secondary, 4.0)

	loc.population_config = PopulationConfig.new()
	var pop_scale := 1 + (index % 4)
	loc.population_config.groups = [
		PopulationGroup.create(8 * pop_scale, EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 2.0),
		PopulationGroup.create(3 * pop_scale, EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.CRAFTSMAN, 10.0),
		PopulationGroup.create(1, EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 25.0),
	]
	loc.population = loc.population_config.build_population(loc.location_id)

	return loc
