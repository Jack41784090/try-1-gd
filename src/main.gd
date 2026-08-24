@tool
extends Node
@onready var level_root: Node2D = $World/LevelRoot
@onready var entity_root: Node2D = $World/EntityRoot
@onready var map_view: SquadMapView = $World/EntityRoot/Map
@onready var effects_root: Node2D = $World/EffectsRoot
@onready var pause_root: Control = $PauseLayer/Root
@onready var trans_root: Control = $TransitionLayer/Root
@onready var debug_root: Control = $DebugLayer/Root
@onready var systems: SystemsRoot = $Systems
@onready var hud_layer: HudLayerRoot = $HudLayer

## Boots main.tscn straight into debug_scenario's data on _ready(). Off by default so
## main.tscn stays inert until a production caller drives load_scenario() with real data.
@export var DEBUG: bool = false:
	set(value):
		DEBUG = value
		notify_property_list_changed()

## Which scenario to load when DEBUG is on. Swap for a different DebugScenario Resource to
## boot a different debug setup — e.g. prototype-sandbox.tres (small 2-location sandbox) instead
## of this 100-location trade-network stress test. Only shown in the Inspector while DEBUG is on
## — see _validate_property().
@export var debug_scenario: DebugScenario = preload("res://resources/strategy/scenarios/debug/stress-test-trade.tres")

var scenario: GameScenario


func _validate_property(property: Dictionary) -> void:
	if property.name == "debug_scenario" and not DEBUG:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	systems.setup()
	hud_layer.setup()
	systems.debug_command_system.command_dispatched.connect(_on_debug_command_dispatched)
	if DEBUG:
		load_debug_scenario()


func load_scenario(scenario_to_load: GameScenario, squads: Array[StrategySquad]) -> void:
	scenario = scenario_to_load

	#region 1. System Setup
	systems.travel_system.setup(scenario)
	systems.battle_system.setup(scenario.world.contact_tracker if scenario.world else null)
	systems.activity_run_system.setup(scenario)
	systems.squad_acting_system.setup(scenario)
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

	#region trivial connections
	systems.clock_system.speed_changed.connect(func(_new_hps: float):
		map_view.tween_speed = 1 / _new_hps
		pass)
	#endregion
	systems.clock_system.hour_changed.connect(systems.caravan_eco_system._on_hour_changed)
	systems.caravan_eco_system.location_arrived.connect(systems.location_eco_system._on_location_arrived)
	# The composition root is the only place allowed to know both sides: the
	# economy system builds the convoy squad, the acting system registers it.
	systems.caravan_eco_system.shipment_dispatched.connect(
		func(move: EconomyMove) -> void:
			scenario.world.add_roaming_squad(move.squad)
			systems.squad_acting_system.register_squad(move.squad)
	)
	systems.travel_system.location_changed.connect(systems.caravan_eco_system._on_squad_moved)
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
		systems.squad_acting_system.register_squad(squad)

	# SquadActingSystem decides each AI squad's activity internally before
	# broadcasting squad_turn, so listeners always read this hour's fresh
	# current_activity_type — no connection-order constraint here.
	systems.squad_acting_system.squad_turn.connect(systems.activity_run_system._on_squad_turn)
	systems.squad_acting_system.ai_travel_requested.connect(systems.travel_system.begin_travel)
	systems.activity_run_system.request_travel.connect(systems.travel_system.on_request_travel)
	systems.activity_run_system.request_combat.connect(
		func(squad: StrategySquad, activity_result: ActivityResult) -> void:
			var defender := systems.squad_acting_system.get_squad(activity_result.combat_target_squad_id)
			if defender: await systems.battle_system.resolve_combat(squad, defender, activity_result.engagement_type)
	)
	systems.clock_system.hour_changed.connect(systems.squad_acting_system.on_hour_pass)

	#region Map view
	map_view.squad_resolver = systems.squad_acting_system.get_squad
	map_view.distance_resolver = systems.travel_system.get_distance
	systems.squad_acting_system.squad_registered.connect(map_view._on_squad_registered)
	systems.squad_acting_system.squad_unregistered.connect(map_view._on_squad_unregistered)
	systems.travel_system.travel_progress_updated.connect(map_view._on_travel_progress)
	systems.travel_system.location_changed.connect(map_view._on_location_changed)
	systems.battle_resolution_system.battle_resolved.connect(
		func(attacker: StrategySquad, defender: StrategySquad, result: CombatController.CombatResult) -> void:
			map_view._on_squad_fights(attacker, defender, result.victory)
	)
	#endregion

	systems.sin_inhering_system.spawn_triggered.connect(systems.monster_spawn_system._on_spawn_triggered)
	systems.monster_spawn_system.squad_spawned.connect(func(_s: StrategySquad):
		scenario.world.add_roaming_squad(_s)
		systems.squad_acting_system.register_squad(_s))
	systems.clock_system.hour_changed.connect(systems.sin_inhering_system.on_hour_pass)
	systems.debug_command_system.setup(_load_default_commands(), {
		&"squad": func(token: String) -> StrategySquad: return systems.squad_acting_system.get_squad(token),
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

## Thin wrapper: debug_scenario owns fixing up what a .tres can't round-trip (see
## DebugScenario.prepare()), so this production script never depends on test-only data.
func load_debug_scenario() -> Array[StrategySquad]:
	assert(debug_scenario != null, "DEBUG is on but no debug_scenario Resource is assigned")
	var squads := debug_scenario.prepare()
	load_scenario(debug_scenario.scenario, squads)
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
