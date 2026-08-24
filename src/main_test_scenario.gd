## Prototype alpha/beta sandbox (2 villages, a merchant lane, 5 starter squads). Source data for
## tools/bake_debug_scenario.gd, which bakes it into resources/strategy/scenarios/debug/
## prototype-sandbox.tres — the DebugScenario main.tscn's DEBUG export loads by default. Kept
## isolated from main.gd's production load_scenario() path — nothing here is reachable at
## runtime outside that bake step.
class_name MainTestScenario
extends RefCounted


static func build_squads() -> Array[StrategySquad]:
	# .duplicate(true): ResourceLoader.load() returns the shared cached instance for that path —
	# mutating it in place would corrupt that cache and, when baked, would save only an
	# ext_resource reference back to the pristine file (silently dropping these overrides).
	var player_squad: StrategySquad = ResourceLoader.load("res://resources/strategy/squads-presets/test-player-squad-full.tres").duplicate(true)
	var bandit_squad: StrategySquad = ResourceLoader.load("res://resources/strategy/squads-presets/test-squad-bandits.tres").duplicate(true)
	# Provisions a multi-day trading session so food never interrupts (3 warriors eat 15/hour).
	player_squad.food = 1500
	# Preset squads carry no current_location_id (only the factory-built ones do); DebugScenario's
	# location_overrides re-applies "alpha" after this gets baked and reloaded.
	player_squad.current_location_id = "alpha"

	var squads: Array[StrategySquad] = [
		build_squad("wanderer", "Wanderer Squad", "alpha"),
		build_squad("forager", "Forager Squad", "alpha"),
		build_squad("commander", "Commander Squad", "alpha"),
		player_squad,
		bandit_squad,
	]
	return squads


## Bypasses GameScenario._setup(), which has a pre-existing bug calling .set_location() on the typed-as-Resource starting_player_squad; unneeded here since squads are owned by SquadActingSystem instead.
static func build_scenario() -> GameScenario:
	var scenario := GameScenario.new()
	scenario.world = build_world()
	scenario.starting_location_id = "alpha"
	scenario.triggerable_manager = TriggerableManager.new()
	## ACTIVITY_REGISTRY.load_all_blocking() hits stale UIDs here (pre-existing YARD headless bug); loading the two needed resources directly by path sidesteps it.
	scenario.triggerable_manager.register(load("res://resources/strategy/generic-activities/travelling/travel.tres"))
	scenario.triggerable_manager.register(load("res://resources/strategy/generic-activities/forage/forage.tres"))
	return scenario


static func build_world() -> World:
	var world := World.new()
	world.current_hour = 0

	# Merchant-sandbox economy: Alpha is a farming village (grain surplus, tools-starved), Beta a craft city (the reverse) — price gaps emerge from the hourly supply/demand formula.
	var grain := Thing.create("grain", "Grain", EconomyTypes.ThingType.FOOD, 2.0)
	var tools := Thing.create("tools", "Tools", EconomyTypes.ThingType.TOOLS, 10.0)
	world.goods = [grain, tools]

	var alpha := Location.new()
	alpha.location_id = "alpha"
	alpha.location_name = "Alpha"
	alpha.type = StrategyTypes.LocationType.VILLAGE
	alpha.development = 30
	alpha.stability = 60.0
	alpha.inventory = LocationInventory.new() ## LocationEconomySystem reads loc.inventory each hour
	alpha.natural_resources = [
		NaturalResource.create(grain, 13.0),
		NaturalResource.create_craft(tools, 1.0),
	]
	alpha.consumer_demand = {
		grain: {"qty": 12.0, "priority": 8.0},
		tools: {"qty": 5.0, "priority": 8.0},
	}
	alpha.inventory.init_thing(grain, 40.0)
	alpha.inventory.init_thing(tools, 0.0)
	alpha.add_connection("beta", 20.0)
	# PopulationSystem drives consumer demand from real individuals — mostly peasants with a couple of landlords, matching Alpha's farming-village type.
	alpha.population_config = PopulationConfig.new()
	alpha.population_config.groups = [
		PopulationGroup.create(10, EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 2.0),
		PopulationGroup.create(2, EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 20.0),
	]
	alpha.population = alpha.population_config.build_population(alpha.location_id)

	var beta := Location.new()
	beta.location_id = "beta"
	beta.location_name = "Beta"
	beta.type = StrategyTypes.LocationType.CITY
	beta.development = 50
	beta.stability = 80.0
	beta.inventory = LocationInventory.new()
	beta.natural_resources = [
		NaturalResource.create_craft(tools, 5.0),
		NaturalResource.create(grain, 2.0),
	]
	beta.consumer_demand = {
		grain: {"qty": 10.0, "priority": 8.0},
		tools: {"qty": 3.0, "priority": 8.0},
	}
	beta.inventory.init_thing(tools, 12.0)
	beta.inventory.init_thing(grain, 0.0)
	beta.add_connection("alpha", 20.0)
	# Bourgeois-heavy population, matching Beta's craft-city type — should show up hungrier and more elastic on Tools than Alpha's.
	beta.population_config = PopulationConfig.new()
	beta.population_config.groups = [
		PopulationGroup.create(8, EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.CRAFTSMAN, 10.0),
		PopulationGroup.create(3, EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 1.0),
		PopulationGroup.create(1, EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 30.0),
	]
	beta.population = beta.population_config.build_population(beta.location_id)

	world.add_location(alpha)
	world.add_location(beta)
	world.build_travel_graph()
	return world


static func build_squad(squad_id: String, squad_name: String, location_id: String) -> StrategySquad:
	var res := StrategyEntityResource.new()
	res.name = "%s Warrior" % squad_name
	res.social_class = StrategyTypes.SocialClass.SOLDIER

	var speed_stat := ReactiveStat.new()
	speed_stat.stat_name = StatName.I.MV_SPD
	speed_stat.stat_value = 10.0
	var morale_stat := ReactiveStat.new()
	morale_stat.stat_name = StatName.I.MORALE
	morale_stat.stat_value = 1.0
	res.rs_array = [speed_stat, morale_stat]

	var warrior := Character.new(StrategyEntity.new(res))

	var squad := SquadDataFactory.create_squad(squad_id, squad_name, 100.0, 10, 5, 0.0, location_id, location_id)
	squad.add_warrior(warrior)
	return squad
