extends Node
@onready var level_root: Node2D = $World/LevelRoot
@onready var entity_root: Node2D = $World/EntityRoot
@onready var effects_root: Node2D = $World/EffectsRoot
@onready var hud_root: Control = $HudLayer/Root
@onready var pause_root: Control = $PauseLayer/Root
@onready var trans_root: Control = $TransitionLayer/Root
@onready var debug_root: Control = $DebugLayer/Root
@onready var systems: Node = $Systems

var clock_system: ClockSystem
var squad_being_system: SquadBeingSystem
var squad_ai_system: SquadAISystem
var travel_system: SquadTravelSystem
var battle_system: BattleResolutionSystem
var activity_run_system: ActivityRunSystem
var debug_command_system: DebugCommandSystem
var command_bar_hud: CommandBarHud


func _ready() -> void:
	_setup_default_systems()
	_setup_hud()
	#_run_prototype_tests()


func _enter_system(system_node: GDScript) -> Node:
	var system = system_node.new()
	assert(system is Node)
	system.name = system_node.get_global_name()
	systems.add_child(system)
	return system

func _setup_default_systems() -> void:
	clock_system = _enter_system(ClockSystem) as ClockSystem
	squad_being_system = _enter_system(SquadBeingSystem) as SquadBeingSystem
	squad_ai_system = _enter_system(SquadAISystem) as SquadAISystem
	travel_system = _enter_system(SquadTravelSystem) as SquadTravelSystem
	battle_system = _enter_system(BattleResolutionSystem) as BattleResolutionSystem
	activity_run_system = _enter_system(ActivityRunSystem) as ActivityRunSystem
	debug_command_system = _enter_system(DebugCommandSystem) as DebugCommandSystem

	debug_command_system.command_dispatched.connect(_on_debug_command_dispatched)


## Builds the command-bar HUD as a plain child of hud_root, not a System —
## it's UI, it doesn't participate in the Systems signal graph itself, it
## only feeds raw text into DebugCommandSystem (wired in load_scenario(),
## once DebugCommandSystem's arg resolvers can actually be built).
func _setup_hud() -> void:
	command_bar_hud = CommandBarHud.new()
	command_bar_hud.name = "CommandBarHud"
	hud_root.add_child(command_bar_hud)


func load_scenario(scenario: GameScenario, squads: Array[StrategySquad]) -> void:
	travel_system.setup(scenario)
	battle_system.setup(scenario.world.contact_tracker if scenario.world else null)
	activity_run_system.setup(scenario)
	squad_ai_system.setup(scenario)

	for squad in squads:
		squad_being_system.register_squad(squad)

	# AI decision must land before ActivityRunSystem reads current_activity_type
	# for the same squad_turn emission — Godot fires signal listeners in
	# connection order, so squad_ai_system's connect() MUST stay first. Do not
	# reorder these two lines.
	squad_being_system.squad_turn.connect(squad_ai_system._on_squad_turn)
	squad_being_system.squad_turn.connect(activity_run_system._on_squad_turn)
	squad_ai_system.ai_travel_requested.connect(travel_system.begin_travel)
	activity_run_system.request_travel.connect(travel_system.on_request_travel)
	# _on_request_combat: resolves combat_target_squad_id via SquadBeingSystem, neither side may know about
	activity_run_system.request_combat.connect(
		func(squad: StrategySquad, activity_result: ActivityResult) -> void:
			var defender := squad_being_system.get_squad(activity_result.combat_target_squad_id)
			if defender == null:
				LogGd.warn("[Main] combat requested but enemy squad '%s' not found" % activity_result.combat_target_squad_id)
				return
			await battle_system.resolve_combat(squad, defender, activity_result.engagement_type)
	)
	clock_system.hour_changed.connect(squad_being_system.on_hour_pass)

	debug_command_system.setup(_load_default_commands(), {
		&"squad": func(token: String) -> StrategySquad: return squad_being_system.get_squad(token),
		&"location": func(token: String) -> Location: return scenario.world.get_location_by_id(token),
		&"location_id": func(token: String) -> Variant:
			var loc := scenario.world.get_location_by_id(token)
			return loc.location_id if loc else null,
		&"raw": func(token: String) -> String: return token,
	})
	command_bar_hud.command_submitted.connect(debug_command_system.interpret)


## Every CommandResource DebugCommandSystem knows about. New commands are
## new .tres files added here — not new code/wiring in main.gd.
func _load_default_commands() -> Array[CommandResource]:
	var commands: Array[CommandResource] = []
	commands.append(load("res://resources/strategy/debug-commands/travel.tres"))
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


#region Prototype tests (no demo files/scenes — run inline against main.tscn)

var _test_failures: Array[String] = []


func _run_prototype_tests() -> void:
	LogGd.info("=== Systems prototype test (HourPassSystem -> SquadBeingSystem -> ActivityRunSystem -> {SquadTravelSystem, BattleResolutionSystem}) ===")

	var scenario := _build_test_scenario()
	var wanderer := _build_test_squad("wanderer", "Wanderer Squad", "alpha")
	var forager := _build_test_squad("forager", "Forager Squad", "alpha")
	var commander := _build_test_squad("commander", "Commander Squad", "alpha")
	var attacker: StrategySquad = ResourceLoader.load("res://resources/strategy/squads-presets/test-player-squad-full.tres")
	var bandits: StrategySquad = ResourceLoader.load("res://resources/strategy/squads-presets/test-squad-bandits.tres")

	load_scenario(scenario, [wanderer, forager, commander, attacker, bandits])
	clock_system.pause() ## drive time via force_tick() only, not real-time _process

	travel_system.location_changed.connect(
		func(squad_id, from_id, to_id): LogGd.info("[Test] location_changed: %s %s -> %s" % [squad_id, from_id, to_id])
	)
	activity_run_system.activity_resolved.connect(
		func(squad, activity, results): LogGd.info("[Test] activity_resolved: %s ran %s -> %d result(s)" % [
			squad.squad_name, StrategyTypes.ActivityType.keys()[activity.activity_type], results.size(),
		])
	)
	battle_system.battle_resolved.connect(
		func(a, d, result): LogGd.info("[Test] battle_resolved: %s vs %s -> %s" % [a.squad_name, d.squad_name, result])
	)
	StrategyEventBus.squad_resource_changed.connect(
		func(resource_name, new_amount): LogGd.info("[Test] (HUD-relevant) squad_resource_changed: %s = %s" % [resource_name, new_amount])
	)

	wanderer.current_activity_type = StrategyTypes.ActivityType.TRAVEL
	travel_system.begin_travel(wanderer, "beta")

	forager.current_activity_type = StrategyTypes.ActivityType.FORAGE
	var food_before := forager.food

	# Same journey as `wanderer`, but driven through the HUD -> DebugCommandSystem
	# pipeline instead of calling SquadTravelSystem directly, to prove the
	# command bar's full round trip: text -> CommandResource match -> arg
	# resolution ("commander" -> StrategySquad, "beta" -> location_id) ->
	# command_dispatched -> main.gd's get_node()+callv onto SquadTravelSystem.
	LogGd.info("[Test] issuing debug command: /travel commander beta")
	command_bar_hud.command_submitted.emit("/travel commander beta")

	# Speed 10 km/h, alpha<->beta is 20km. Tick 1 only registers the journey
	# (SquadTravelSystem.begin_travel doesn't move the squad yet), so
	# arrival lands on hour 3 (10km + 10km after two advance_travel calls).
	for i in range(3):
		clock_system.force_tick()
		await get_tree().process_frame

	_check("wanderer arrived at beta", wanderer.current_location_id == "beta")
	_check("forager gained food while foraging at a VILLAGE", forager.food > food_before)
	_check("commander arrived at beta via /travel debug command", commander.current_location_id == "beta")

	LogGd.info("[Test] resolving direct battle: %s vs %s" % [attacker.squad_name, bandits.squad_name])
	var result: CombatController.CombatResult = await battle_system.resolve_combat(attacker, bandits)
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

	var alpha := Location.new()
	alpha.location_id = "alpha"
	alpha.location_name = "Alpha"
	alpha.type = StrategyTypes.LocationType.VILLAGE
	alpha.development = 30
	alpha.stability = 60.0
	alpha.add_connection("beta", 20.0)

	var beta := Location.new()
	beta.location_id = "beta"
	beta.location_name = "Beta"
	beta.type = StrategyTypes.LocationType.CITY
	beta.development = 50
	beta.stability = 80.0
	beta.add_connection("alpha", 20.0)

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
