extends Node
@onready var level_root: Node2D = $World/LevelRoot
@onready var entity_root: Node2D = $World/EntityRoot
@onready var effects_root: Node2D = $World/EffectsRoot
@onready var pause_root: Control = $PauseLayer/Root
@onready var trans_root: Control = $TransitionLayer/Root
@onready var debug_root: Control = $DebugLayer/Root
@onready var systems: SystemsRoot = $Systems
@onready var hud_layer: HudLayerRoot = $HudLayer

var scenario: GameScenario


func _ready() -> void:
	systems.setup()
	hud_layer.setup()
	systems.debug_command_system.command_dispatched.connect(_on_debug_command_dispatched)
	#_run_prototype_tests()
	load_prototype_scenario()


func load_scenario(scenario_to_load: GameScenario, squads: Array[StrategySquad]) -> void:
	scenario = scenario_to_load

	#region 1. System Setup
	systems.travel_system.setup(scenario)
	systems.battle_system.setup(scenario.world.contact_tracker if scenario.world else null)
	systems.activity_run_system.setup(scenario)
	systems.squad_ai_system.setup(scenario)
	systems.monster_spawn_system.setup(scenario)
	systems.sin_inhering_system.setup(scenario)
	systems.location_eco_system.setup(scenario.world)
	systems.population_system.setup(scenario.world)
	systems.caravan_eco_system.setup(scenario.world.locations.size())
	#endregion
	
	#region 2. Location Register
	for loc in scenario.world.locations:
		systems.location_eco_system.register_location(loc, _build_crafting_guilds(loc), loc.consumer_demand)
	#endregion

	systems.clock_system.hour_changed.connect(systems.caravan_eco_system._on_hour_changed)
	systems.caravan_eco_system.location_arrived.connect(systems.location_eco_system._on_location_arrived)
	systems.clock_system.hour_changed.connect(systems.trade_system._on_hour_changed)
	systems.clock_system.hour_changed.connect(systems.population_system._on_hour_changed)
	systems.clock_system.hour_changed.connect(systems.location_eco_system._on_hour_changed)
	systems.location_eco_system.trade_offer.connect(systems.caravan_eco_system._on_trade_offer)
	systems.location_eco_system.trade_offer.connect(systems.trade_system._on_trade_offer)
	systems.location_eco_system.trade_offer.connect(systems.population_system._on_trade_offer)
	systems.trade_system.buy_requested.connect(
		func(squad: StrategySquad, thing: Thing, qty: float):
			var loc := scenario.world.get_location_by_id(squad.current_location_id)
			if loc: systems.trade_system.queue_trade(Trade.create(squad, loc, thing, qty, true)))
	systems.trade_system.sell_requested.connect(
		func(squad: StrategySquad, thing: Thing, qty: float):
			var loc := scenario.world.get_location_by_id(squad.current_location_id)
			if loc: systems.trade_system.queue_trade(Trade.create(squad, loc, thing, qty, false)))

	for squad in squads:
		systems.squad_being_system.register_squad(squad)

	systems.squad_being_system.squad_turn.connect(systems.squad_ai_system._on_squad_turn)
	systems.squad_being_system.squad_turn.connect(systems.activity_run_system._on_squad_turn)
	systems.squad_ai_system.ai_travel_requested.connect(systems.travel_system.begin_travel)
	systems.activity_run_system.request_travel.connect(systems.travel_system.on_request_travel)
	systems.activity_run_system.request_combat.connect(
		func(squad: StrategySquad, activity_result: ActivityResult) -> void:
			var defender := systems.squad_being_system.get_squad(activity_result.combat_target_squad_id)
			if defender: await systems.battle_system.resolve_combat(squad, defender, activity_result.engagement_type)
	)
	systems.clock_system.hour_changed.connect(systems.squad_being_system.on_hour_pass)

	systems.sin_inhering_system.spawn_triggered.connect(systems.monster_spawn_system._on_spawn_triggered)
	systems.monster_spawn_system.squad_spawned.connect(_on_monster_squad_spawned)
	systems.clock_system.hour_changed.connect(systems.sin_inhering_system.on_hour_pass)
	systems.debug_command_system.setup(_load_default_commands(), {
		&"squad": func(token: String) -> StrategySquad: return systems.squad_being_system.get_squad(token),
		&"location": func(token: String) -> Location: return scenario.world.get_location_by_id(token),
		&"location_id": func(token: String) -> Variant:
			var loc := scenario.world.get_location_by_id(token)
			return loc.location_id if loc else null,
		&"thing": func(token: String) -> Variant:
			for loc in scenario.world.locations:
				for thing: Thing in loc.inventory.stocks:
					if thing.thing_id == token:
						return thing
			return null,
		&"qty": func(token: String) -> Variant: return float(token) if token.is_valid_float() else null,
		&"raw": func(token: String) -> String: return token,
	})
	
	
	#region Hud Signals
	systems.clock_system.hour_changed.connect(hud_layer.time_label.set_time)

	hud_layer.command_bar_hud.command_submitted.connect(systems.debug_command_system.interpret)
	#endregion
	
	LogGd.info("load done")

func load_prototype_scenario() -> Array[StrategySquad]:
	var squads: Array[StrategySquad] = [
		_build_test_squad("wanderer", "Wanderer Squad", "alpha"),
		_build_test_squad("forager", "Forager Squad", "alpha"),
		_build_test_squad("commander", "Commander Squad", "alpha"),
		ResourceLoader.load("res://resources/strategy/squads-presets/test-player-squad-full.tres"),
		ResourceLoader.load("res://resources/strategy/squads-presets/test-squad-bandits.tres"),
	]
	load_scenario(_build_test_scenario(), squads)
	# Provisions a multi-day trading session so food never interrupts (3 warriors eat 15/hour).
	squads[3].food = 1500
	# Preset squads carry no current_location_id (only the factory-built ones do).
	squads[3].current_location_id = "alpha"
	# Free auto-caravans would arbitrage every price gap within hours, leaving the player-merchant no margin.
	systems.location_eco_system.trade_offer.disconnect(systems.caravan_eco_system._on_trade_offer)
	# systems.clock_system.pause()
	return squads


func _build_crafting_guilds(loc: Location) -> Array[CraftingGuild]:
	var guilds: Array[CraftingGuild] = []
	for cfg: GuildConfig in loc.guild_configs:
		for spec: GuildSpecialization in cfg.specializations:
			var guild_id := "%s::%s" % [loc.location_id, spec.thing.thing_id]
			guilds.append(CraftingGuild.create(guild_id, spec.thing, float(spec.max_workers), 5.0))
	return guilds


func _load_default_commands() -> Array[CommandResource]:
	var commands: Array[CommandResource] = []
	commands.append(load("res://resources/strategy/debug-commands/travel.tres"))
	commands.append(load("res://resources/strategy/debug-commands/buy.tres"))
	commands.append(load("res://resources/strategy/debug-commands/sell.tres"))
	commands.append(load("res://resources/strategy/debug-commands/spawn-monster.tres"))
	return commands


func _on_debug_command_dispatched(target_system_name: StringName, target_signal_name: StringName, args: Array) -> void:
	var target := systems.get_node_or_null(NodePath(String(target_system_name)))
	if target == null:
		LogGd.warn("[Main] debug command target system '%s' not found under Systems" % target_system_name)
		return

	if target.has_signal(target_signal_name):
		target.callv("emit_signal", [target_signal_name] + args)
	elif target.has_method(target_signal_name):
		target.callv(target_signal_name, args)
	else:
		LogGd.warn("[Main] debug command target '%s' has no signal or method '%s'" % [target_system_name, target_signal_name])


func _on_monster_squad_spawned(squad: StrategySquad) -> void:
	scenario.world.add_roaming_squad(squad)
	systems.squad_being_system.register_squad(squad)
	systems.squad_ai_system.register_squad(squad, "res://resources/ai/strategic/profiles/monster-roamer.tres")




#region Prototype tests (no demo files/scenes — run inline against main.tscn)

var _test_failures: Array[String] = []


func _run_prototype_tests() -> void:
	LogGd.info("=== Systems prototype test (HourPassSystem -> SquadBeingSystem -> ActivityRunSystem -> {SquadTravelSystem, BattleResolutionSystem}) ===")

	var squads := load_prototype_scenario()
	var wanderer := squads[0]
	var forager := squads[1]
	var commander := squads[2]
	var attacker := squads[3]
	var bandits := squads[4]

	systems.travel_system.location_changed.connect(
		func(squad_id, from_id, to_id): LogGd.info("[Test] location_changed: %s %s -> %s" % [squad_id, from_id, to_id])
	)
	systems.activity_run_system.activity_resolved.connect(
		func(squad, activity, results): LogGd.info("[Test] activity_resolved: %s ran %s -> %d result(s)" % [
			squad.squad_name, StrategyTypes.ActivityType.keys()[activity.activity_type], results.size(),
		])
	)
	systems.battle_system.battle_resolved.connect(
		func(a, d, result): LogGd.info("[Test] battle_resolved: %s vs %s -> %s" % [a.squad_name, d.squad_name, result])
	)
	wanderer.current_activity_type = StrategyTypes.ActivityType.TRAVEL
	systems.travel_system.begin_travel(wanderer, "beta")

	forager.current_activity_type = StrategyTypes.ActivityType.FORAGE
	var food_before := forager.food

	# Same journey as `wanderer`, but driven through the HUD -> DebugCommandSystem pipeline to prove the command bar's full round trip.
	LogGd.info("[Test] issuing debug command: /travel commander beta")
	hud_layer.command_bar_hud.command_submitted.emit("/travel commander beta")

	# Tick 1 only registers the journey; arrival lands on hour 3 (10km/h, 20km apart, after two advance_travel calls).
	for i in range(3):
		systems.clock_system.force_tick()
		await get_tree().process_frame

	_check("wanderer arrived at beta", wanderer.current_location_id == "beta")
	_check("forager gained food while foraging at a VILLAGE", forager.food > food_before)
	_check("commander arrived at beta via /travel debug command", commander.current_location_id == "beta")

	LogGd.info("[Test] resolving direct battle: %s vs %s" % [attacker.squad_name, bandits.squad_name])
	var result: CombatController.CombatResult = await systems.battle_system.resolve_combat(attacker, bandits)
	_check("battle produced a CombatResult", result != null)
	_check("battle ran at least one turn or ended in flee/negotiate", result.turns_elapsed > 0 or result.fled or result.negotiated)

	if _test_failures.is_empty():
		LogGd.info("[Test] ALL PASSED")
	else:
		LogGd.error("[Test] %d FAILURE(S): %s" % [_test_failures.size(), _test_failures])

	if OS.has_feature("headless"):
		get_tree().quit(0 if _test_failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		LogGd.info("[Test]   ok: %s" % label)
	else:
		_test_failures.append(label)
		LogGd.error("[Test]   FAIL: %s" % label)


## Bypasses GameScenario._setup(), which has a pre-existing bug calling .set_location() on the typed-as-Resource starting_player_squad; unneeded here since squads are owned by SquadBeingSystem instead.
func _build_test_scenario() -> GameScenario:
	var scenario := GameScenario.new()
	scenario.world = _build_test_world()
	scenario.starting_location_id = "alpha"
	scenario.triggerable_manager = TriggerableManager.new()
	## ACTIVITY_REGISTRY.load_all_blocking() hits stale UIDs here (pre-existing YARD headless bug); loading the two needed resources directly by path sidesteps it.
	scenario.triggerable_manager.register(load("res://resources/strategy/generic-activities/travelling/travel.tres"))
	scenario.triggerable_manager.register(load("res://resources/strategy/generic-activities/forage/forage.tres"))
	return scenario


func _build_test_world() -> World:
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


func _build_test_squad(squad_id: String, squad_name: String, location_id: String) -> StrategySquad:
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

#endregion
