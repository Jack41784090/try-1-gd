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


func load_scenario(scenario_to_load: GameScenario, squads: Array[StrategySquad]) -> void:
	scenario = scenario_to_load
	systems.travel_system.setup(scenario)
	systems.battle_system.setup(scenario.world.contact_tracker if scenario.world else null)
	systems.activity_run_system.setup(scenario)
	systems.squad_ai_system.setup(scenario)
	systems.monster_spawn_system.setup(scenario)
	systems.sin_inhering_system.setup(scenario)

	if scenario.world:
		systems.location_eco_system.setup(scenario.world)
		systems.population_system.setup(scenario.world)
		systems.caravan_eco_system.setup(scenario.world.locations.size())
		for loc in scenario.world.locations:
			systems.location_eco_system.register_location(loc, _build_crafting_guilds(loc), loc.consumer_demand)

		# Connection order matters here too — see both systems' doc-comments.
		systems.clock_system.hour_changed.connect(systems.caravan_eco_system._on_hour_changed)
		systems.caravan_eco_system.location_arrived.connect(systems.location_eco_system._on_location_arrived)
		systems.clock_system.hour_changed.connect(systems.trade_system._on_hour_changed)
		# PopulationSystem must recompute wants (and update satisfaction from
		# last hour's cached unmet) BEFORE LocationEconomySystem's own
		# hour_changed handler runs this same tick, since
		# LocationEconomySystem._generate_intents() pull-reads
		# loc.population.get_total_demand() as THIS hour's consumer demand.
		# Reversing this order would make LocationEconomySystem read last
		# hour's stale wants instead of this hour's — do not reorder.
		systems.clock_system.hour_changed.connect(systems.population_system._on_hour_changed)
		systems.clock_system.hour_changed.connect(systems.location_eco_system._on_hour_changed)
		systems.location_eco_system.trade_offer.connect(systems.caravan_eco_system._on_trade_offer)
		systems.location_eco_system.trade_offer.connect(systems.trade_system._on_trade_offer)
		# PopulationSystem caches last hour's unmet the same way
		# TradeSystem/CaravanEconomySystem cache trade_offer — connected AFTER
		# trade_offer emits, so satisfaction updates next hour use this hour's
		# real settlement outcome.
		systems.location_eco_system.trade_offer.connect(systems.population_system._on_trade_offer)

		# TradeSystem owns Trades, never World — the composition root resolves
		# the squad's Location and builds the Trade (same bridging rule as the
		# request_combat handler below).
		systems.trade_system.buy_requested.connect(func(squad: StrategySquad, thing: Thing, qty: float): _queue_player_trade(squad, thing, qty, true))
		systems.trade_system.sell_requested.connect(func(squad: StrategySquad, thing: Thing, qty: float): _queue_player_trade(squad, thing, qty, false))

	for squad in squads:
		systems.squad_being_system.register_squad(squad)

	# AI decision must land before ActivityRunSystem reads current_activity_type
	# for the same squad_turn emission — Godot fires signal listeners in
	# connection order, so squad_ai_system's connect() MUST stay first. Do not
	# reorder these two lines.
	systems.squad_being_system.squad_turn.connect(systems.squad_ai_system._on_squad_turn)
	systems.squad_being_system.squad_turn.connect(systems.activity_run_system._on_squad_turn)
	systems.squad_ai_system.ai_travel_requested.connect(systems.travel_system.begin_travel)
	systems.activity_run_system.request_travel.connect(systems.travel_system.on_request_travel)
	# _on_request_combat: resolves combat_target_squad_id via SquadBeingSystem, neither side may know about
	systems.activity_run_system.request_combat.connect(
		func(squad: StrategySquad, activity_result: ActivityResult) -> void:
			var defender := systems.squad_being_system.get_squad(activity_result.combat_target_squad_id)
			if defender == null:
				LogGd.warn("[Main] combat requested but enemy squad '%s' not found" % activity_result.combat_target_squad_id)
				return
			await systems.battle_system.resolve_combat(squad, defender, activity_result.engagement_type)
	)
	systems.clock_system.hour_changed.connect(systems.squad_being_system.on_hour_pass)

	# Monster spawning: SinInheringSystem ("why") triggers MonsterSpawnSystem
	# ("what"), whose squad_spawned lands here — the one place all three
	# registration steps (World, SquadBeingSystem, SquadAISystem) run
	# together, since no system may call another directly. Connected AFTER
	# squad_being_system.on_hour_pass so a squad spawned this hour doesn't
	# also receive a squad_turn the same hour.
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
	hud_layer.command_bar_hud.command_submitted.connect(systems.debug_command_system.interpret)


## Builds and loads the prototype alpha/beta world + its five squads, then
## pauses the clock so time only advances via ClockSystem.force_tick() (the
## interactive driver's `tick` command, or _run_prototype_tests()). Returns
## the registered squads in build order: wanderer, forager, commander,
## attacker (player preset), bandits.
func load_prototype_scenario() -> Array[StrategySquad]:
	var squads: Array[StrategySquad] = [
		_build_test_squad("wanderer", "Wanderer Squad", "alpha"),
		_build_test_squad("forager", "Forager Squad", "alpha"),
		_build_test_squad("commander", "Commander Squad", "alpha"),
		ResourceLoader.load("res://resources/strategy/squads-presets/test-player-squad-full.tres"),
		ResourceLoader.load("res://resources/strategy/squads-presets/test-squad-bandits.tres"),
	]
	load_scenario(_build_test_scenario(), squads)
	# Merchant sandbox: the player squad eats 15 food/hour (3 warriors) —
	# provision it for a multi-day trading session so food never interrupts.
	squads[3].food = 1500
	# Preset squads carry no current_location_id (only the factory-built ones do).
	squads[3].current_location_id = "alpha"
	# Free auto-caravans would arbitrage every price gap within hours (ship
	# min(surplus, unmet) per hour, 1h delivery, zero cost), leaving the
	# player-merchant no margin — the sandbox plays with caravans parked.
	systems.location_eco_system.trade_offer.disconnect(systems.caravan_eco_system._on_trade_offer)
	systems.clock_system.pause()
	return squads


## max_capacity assumes full staffing — no worker roster modeled here yet.
func _build_crafting_guilds(loc: Location) -> Array[CraftingGuild]:
	var guilds: Array[CraftingGuild] = []
	for cfg: GuildConfig in loc.guild_configs:
		for spec: GuildSpecialization in cfg.specializations:
			var guild_id := "%s::%s" % [loc.location_id, spec.thing.thing_id]
			guilds.append(CraftingGuild.create(guild_id, spec.thing, float(spec.max_workers), 5.0))
	return guilds


## Every CommandResource DebugCommandSystem knows about. New commands are
## new .tres files added here — not new code/wiring in main.gd.
func _load_default_commands() -> Array[CommandResource]:
	var commands: Array[CommandResource] = []
	commands.append(load("res://resources/strategy/debug-commands/travel.tres"))
	commands.append(load("res://resources/strategy/debug-commands/buy.tres"))
	commands.append(load("res://resources/strategy/debug-commands/sell.tres"))
	commands.append(load("res://resources/strategy/debug-commands/spawn-monster.tres"))
	return commands


## The one place that turns a resolved (target_system_name, target_signal_name,
## args) triple into an actual call — DebugCommandSystem only names the
## target by StringName, since it never holds sibling-System refs itself.
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


## The one place all three monster-squad registration steps run together —
## World, SquadBeingSystem, SquadAISystem — since no system may call another
## directly.
func _on_monster_squad_spawned(squad: StrategySquad) -> void:
	scenario.world.add_roaming_squad(squad)
	systems.squad_being_system.register_squad(squad)
	systems.squad_ai_system.register_squad(squad, "res://resources/ai/strategic/profiles/monster-roamer.tres")


## TradeSystem owns Trades, never World — resolve the squad's Location here
## and hand the built Trade over (the composition-root bridging rule).
func _queue_player_trade(squad: StrategySquad, thing: Thing, qty: float, is_buy: bool) -> void:
	var loc := scenario.world.get_location_by_id(squad.current_location_id)
	if loc == null:
		LogGd.warn("[Main] %s cannot trade — location '%s' unresolved" % [squad.squad_name, squad.current_location_id])
		return
	systems.trade_system.queue_trade(Trade.create(squad, loc, thing, qty, is_buy))


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
	## StrategyEventBus.squad_resource_changed.connect(
		#func(resource_name, new_amount): LogGd.info("[Test] (HUD-relevant) squad_resource_changed: %s = %s" % [resource_name, new_amount])
	#)

	wanderer.current_activity_type = StrategyTypes.ActivityType.TRAVEL
	systems.travel_system.begin_travel(wanderer, "beta")

	forager.current_activity_type = StrategyTypes.ActivityType.FORAGE
	var food_before := forager.food

	# Same journey as `wanderer`, but driven through the HUD -> DebugCommandSystem
	# pipeline instead of calling SquadTravelSystem directly, to prove the
	# command bar's full round trip: text -> CommandResource match -> arg
	# resolution ("commander" -> StrategySquad, "beta" -> location_id) ->
	# command_dispatched -> main.gd's get_node()+callv onto SquadTravelSystem.
	LogGd.info("[Test] issuing debug command: /travel commander beta")
	hud_layer.command_bar_hud.command_submitted.emit("/travel commander beta")

	# Speed 10 km/h, alpha<->beta is 20km. Tick 1 only registers the journey
	# (SquadTravelSystem.begin_travel doesn't move the squad yet), so
	# arrival lands on hour 3 (10km + 10km after two advance_travel calls).
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


## Bypasses GameScenario._setup() — it currently asserts starting_player_squad
## is a real StrategySquad but is typed StrategySquadResource and calls
## .set_location() on it, which StrategySquadResource doesn't have. Pre-
## existing, unrelated bug; see the scenes-main-tscn plan's "Prototype
## status" section. Since squads here are owned by SquadBeingSystem, not
## scenario.starting_player_squad, this scenario never needs that field.
func _build_test_scenario() -> GameScenario:
	var scenario := GameScenario.new()
	scenario.world = _build_test_world()
	scenario.starting_location_id = "alpha"
	scenario.triggerable_manager = TriggerableManager.new()
	## GameScenario.ACTIVITY_REGISTRY.load_all_blocking() hits stale UIDs in
	## this environment (the YARD headless UID-cache staleness class of bug,
	## pre-existing/unrelated — see the plan's "Prototype status" section).
	## Loading the two Activity resources this test actually needs directly
	## by path sidesteps it.
	scenario.triggerable_manager.register(load("res://resources/strategy/generic-activities/travelling/travel.tres"))
	scenario.triggerable_manager.register(load("res://resources/strategy/generic-activities/forage/forage.tres"))
	return scenario


func _build_test_world() -> World:
	var world := World.new()
	world.current_hour = 0

	# Merchant-sandbox economy: Alpha is a farming village (grain surplus,
	# starved of tools), Beta a craft city (tools surplus, starved of grain).
	# Price gaps emerge from the hourly supply/demand imbalance formula in
	# LocationEconomySystem._price_update — buy low at the source, sell high
	# at the hungry market.
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
	# PopulationSystem drives consumer demand from real individuals — Alpha
	# is a farming village, so mostly peasants with a couple of landlords.
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
	# Beta is a craft city — bourgeois-heavy, grain-starved, so its population
	# should show up hungrier and more elastic on Tools than Alpha's.
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
