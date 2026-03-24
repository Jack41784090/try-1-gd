extends Node
## Interactive Terminal Demo — Play CONDOR strategy game from a terminal.
##
## Runs the real StrategyPresenter with a headless mock view, accepting
## text commands from stdin. Displays rich game state after each turn.
##
## Usage: godot-mono --headless --path . scenes/demos/interactive_demo.tscn
##
## Commands:
##   status        — Full squad status (food, gold, morale, warriors)
##   look          — Describe current location, connections, and squads
##   warriors      — List all warriors with class, position, status
##   travel <id>   — Travel to a connected location (e.g. "travel oehringen")
##   rest          — Rest to recover morale
##   forage        — Forage for food
##   drill         — Drill to improve combat readiness
##   patrol        — Patrol for intel (boosts scouting)
##   heal          — Heal injured warriors (requires town)
##   buy           — Buy supplies at a shop (requires town with shop)
##   mercenary     — Do mercenary work for gold
##   mass          — Hold mass (Feldprediger activity)
##   recruit       — (Not yet interactive — shows info)
##   attack <id>   — Attack a squad (requires LOCKED contact)
##   contacts      — Show contact intel on all known squads
##   missions      — Show active and completed missions
##   events        — Show events that have fired
##   economy       — Show economy state per location
##   map           — Show all locations and connections
##   help          — Show available commands
##   quit          — Exit the game

const SCENARIO_PATH := "res://resources/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")

var presenter: StrategyPresenter
var player_squad: SquadStrategicData
var world: World

var _events_fired: Array[String] = []
var _missions_completed: Array[String] = []
var _awaiting_command := false
var _initialized := false
var _turn_number := 0
var _command_queue: Array[String] = []

var _stdin_thread: Thread
var _stdin_mutex: Mutex
var _stdin_buffer: Array[String] = []
var _should_quit := false


func _ready():
	Log.set_level(Log.Level.ERROR)

	_print_banner()
	_print_line("Initializing game scenario...")

	var mock_view = HeadlessView.new()
	add_child(mock_view)
	mock_view.setup_headless()

	presenter = StrategyPresenter.new()
	presenter.scenario_path = SCENARIO_PATH
	presenter.is_demo_scenario = false
	mock_view.add_child(presenter)

	await presenter.bind_view(mock_view)

	player_squad = presenter.actor.player_squad
	world = presenter.game_scenario.world

	_hook_triggerable_logging()
	_retroactive_detect_events()

	_stdin_mutex = Mutex.new()
	_stdin_thread = Thread.new()
	_stdin_thread.start(_stdin_reader)

	_initialized = true
	_print_line("")
	_print_line("Game ready! You are %s." % player_squad.squad_name)
	_print_separator()
	_cmd_look()
	_cmd_status()
	_print_prompt()


func _process(_delta):
	if not _initialized:
		return

	_stdin_mutex.lock()
	var lines = _stdin_buffer.duplicate()
	_stdin_buffer.clear()
	_stdin_mutex.unlock()

	for line in lines:
		_command_queue.append(line)

	if _command_queue.size() > 0 and not presenter.is_executing_activity:
		var cmd = _command_queue.pop_front()
		_handle_command(cmd)


func _stdin_reader():
	while not _should_quit:
		var line := OS.read_string_from_stdin(256).strip_edges()
		if line.is_empty():
			continue
		_stdin_mutex.lock()
		_stdin_buffer.append(line)
		_stdin_mutex.unlock()


func _exit_tree():
	_should_quit = true
	if _stdin_thread and _stdin_thread.is_started():
		_stdin_thread.wait_to_finish()


func _hook_triggerable_logging():
	var tm = presenter.game_scenario.triggerable_manager
	tm.triggerable_fired.connect(_on_triggerable_fired)


func _on_triggerable_fired(triggerable, _result):
	var tid = triggerable.trigger_id
	if triggerable is Mission:
		_missions_completed.append(tid)
		_print_event("MISSION COMPLETED: %s" % tid)
	else:
		_events_fired.append(tid)
		_print_event("EVENT: %s" % tid)


func _retroactive_detect_events():
	for t in presenter.game_scenario.triggerable_manager.registered_triggerables:
		if t is GameEvent and t.times_triggered > 0:
			_events_fired.append(t.trigger_id)
	for faction in presenter.game_scenario.factions:
		for mission in faction.missions:
			if mission.is_completed:
				_missions_completed.append(mission.mission_id)


#region Command Dispatch

func _handle_command(input: String):
	var parts := input.split(" ", false)
	if parts.is_empty():
		_print_prompt()
		return

	var cmd := parts[0].to_lower()
	var arg := parts[1] if parts.size() > 1 else ""

	match cmd:
		"help", "h", "?":
			_cmd_help()
		"status", "s":
			_cmd_status()
		"look", "l":
			_cmd_look()
		"warriors", "w":
			_cmd_warriors()
		"travel", "t":
			await _cmd_travel(arg)
		"rest":
			await _cmd_activity(StrategyTypes.ActivityType.REST, "Resting...")
		"forage", "f":
			await _cmd_activity(StrategyTypes.ActivityType.FORAGE, "Foraging for supplies...")
		"drill":
			await _cmd_activity(StrategyTypes.ActivityType.DRILL, "Drilling troops...")
		"patrol", "p":
			await _cmd_activity(StrategyTypes.ActivityType.PATROL, "Patrolling the area...")
		"heal":
			await _cmd_activity(StrategyTypes.ActivityType.HEAL, "Healing injured warriors...")
		"buy":
			await _cmd_activity(StrategyTypes.ActivityType.BUY_SUPPLIES, "Buying supplies...")
		"mercenary", "merc":
			await _cmd_activity(StrategyTypes.ActivityType.MERCENARY_WORK, "Doing mercenary work...")
		"mass":
			await _cmd_activity(StrategyTypes.ActivityType.HOLD_MASS, "Holding mass...")
		"recruit":
			_cmd_recruit_info()
		"attack", "a":
			await _cmd_attack(arg)
		"contacts", "c":
			_cmd_contacts()
		"missions", "m":
			_cmd_missions()
		"events":
			_cmd_events()
		"economy", "econ", "e":
			_cmd_economy()
		"map":
			_cmd_map()
		"god_squads", "gs":
			_cmd_god_squads()
		"god_contacts", "gc":
			_cmd_god_contacts()
		"god_lock", "gl":
			_cmd_god_lock(arg)
		"god_economy", "ge":
			_cmd_god_economy()
		"quit", "q", "exit":
			_cmd_quit()
		_:
			_print_line("Unknown command: '%s'. Type 'help' for available commands." % cmd)

	if not _should_quit:
		_print_prompt()

#endregion


#region Commands

func _cmd_help():
	_print_separator()
	_print_line("=== CONDOR — Interactive Commands ===")
	_print_line("")
	_print_line("  STATUS  (s)       Full squad status")
	_print_line("  LOOK    (l)       Describe current location")
	_print_line("  WARRIORS (w)      List all warriors")
	_print_line("  TRAVEL  (t) <id>  Travel to location")
	_print_line("  REST              Rest to recover morale")
	_print_line("  FORAGE  (f)       Forage for food")
	_print_line("  DRILL             Drill troops")
	_print_line("  PATROL  (p)       Patrol for intel")
	_print_line("  HEAL              Heal injured warriors")
	_print_line("  BUY               Buy supplies at shop")
	_print_line("  MERCENARY (merc)  Mercenary work for gold")
	_print_line("  MASS              Hold mass")
	_print_line("  RECRUIT           Recruitment info")
	_print_line("  ATTACK  (a) <id>  Attack a squad")
	_print_line("  CONTACTS (c)      Show contact intel")
	_print_line("  MISSIONS (m)      Show missions")
	_print_line("  EVENTS            Show fired events")
	_print_line("  ECONOMY (e)       Economy overview")
	_print_line("  MAP               Show world map")
	_print_line("  HELP    (h/?)     This help text")
	_print_line("  QUIT    (q)       Exit the game")
	_print_line("")
	_print_line("  --- GOD MODE (omniscient) ---")
	_print_line("  GOD_SQUADS  (gs)  All squads: location, role, ID")
	_print_line("  GOD_CONTACTS(gc)  Raw contact data with squad IDs")
	_print_line("  GOD_LOCK (gl)<id> Force-lock contact on a squad")
	_print_line("  GOD_ECONOMY (ge)  Full economy: stocks, prices, moves")
	_print_separator()


func _cmd_status():
	_print_separator()
	var living = player_squad.get_living_warriors()
	var injured := 0
	for w in living:
		if w.is_injured:
			injured += 1

	_print_line("=== %s — Turn %d ===" % [player_squad.squad_name, world.turn_count])
	_print_line("  Location:  %s" % _get_location_display(player_squad.current_location_id))
	_print_line("  Warriors:  %d alive (%d injured)" % [living.size(), injured])
	_print_line("  Morale:    %.0f" % player_squad.get_morale())
	_print_line("  Food:      %d" % player_squad.food)
	_print_line("  Gold:      %.0f" % player_squad.money)
	_print_line("  Karma:     %.0f" % player_squad.karma)
	_print_line("  Tools:     %d" % player_squad.travel_tools)

	var dest = presenter.actor.walking_towards
	if dest and dest.has("location") and dest["location"] != null:
		_print_line("  Traveling: → %s" % dest["location"].location_name)
	_print_separator()


func _cmd_look():
	var loc_id := player_squad.current_location_id
	var loc := world.get_location_by_id(loc_id)
	if not loc:
		_print_line("ERROR: Current location '%s' not found in world." % loc_id)
		return

	_print_separator()
	_print_line("=== %s (%s) ===" % [loc.location_name, _location_type_str(loc.type)])
	if loc.development > 0:
		_print_line("  Development: %d | Stability: %.0f" % [loc.development, loc.stability])

	_print_line("")
	_print_line("  --- Connections ---")
	for conn in loc.connections.tt:
		var to_loc := world.get_location_by_id(conn.to_location_id)
		var to_name := to_loc.location_name if to_loc else conn.to_location_id
		_print_line("    → %s (%s) — %d turns" % [to_name, conn.to_location_id, conn.travel_time])

	_print_line("")
	_print_line("  --- Available Activities ---")
	var activities: Array[String] = []
	for at in loc.available_activity_types:
		activities.append(StrategyTypes.ActivityType.keys()[at])
	_print_line("    %s" % ", ".join(activities))

	if loc.has_shop():
		_print_line("")
		_print_line("  --- Shop: %s ---" % loc.shop.shop_name)
		for item in loc.shop.items:
			var price := item.base_price
			if loc.inventory and loc.inventory.prices.has(item):
				price = loc.inventory.prices[item]
			var stock_str := ""
			if loc.inventory and loc.inventory.stocks.has(item):
				stock_str = " (stock: %.0f)" % loc.inventory.stocks[item]
			_print_line("    %s — %.1f gold%s" % [item.thing_name, price, stock_str])

	var squads_here := world.get_squads_at_location(loc_id)
	if squads_here.size() > 0:
		_print_line("")
		_print_line("  --- Other Squads Here ---")
		for sq in squads_here:
			if sq.squad_id == player_squad.squad_id:
				continue
			var role = "Caravan" if sq.is_caravan() else "Combat"
			_print_line("    %s [%s] — %d warriors" % [sq.squad_name, role, sq.get_living_warriors().size()])
	_print_separator()


func _cmd_warriors():
	_print_separator()
	_print_line("=== Warriors ===")
	var living = player_squad.get_living_warriors()
	for i in range(living.size()):
		var w = living[i]
		var pos_name := _pos_str(w.location_prebattle)
		var status := ""
		if w.is_injured:
			status = " [INJURED]"
		elif w.is_dead:
			status = " [DEAD]"
		_print_line("  %d. %s — %s | Position: %s | Morale: %.0f%s" % [
			i + 1, w.name, EntityClasses.Types.keys()[w.class_id], pos_name, w.morale, status])
	_print_separator()


func _cmd_travel(destination: String):
	if destination.is_empty():
		_print_line("Usage: travel <location_id>")
		_print_line("Connected locations:")
		var loc := world.get_location_by_id(player_squad.current_location_id)
		for conn in loc.connections.tt:
			var to_loc := world.get_location_by_id(conn.to_location_id)
			var to_name := to_loc.location_name if to_loc else conn.to_location_id
			_print_line("  %s — %s (%d turns)" % [conn.to_location_id, to_name, conn.travel_time])
		return

	var to_loc := world.get_location_by_id(destination)
	if not to_loc:
		_print_line("Unknown location: '%s'. Type 'look' to see connections." % destination)
		return

	_print_line("Setting out for %s..." % to_loc.location_name)
	await presenter.on_travel_confirmed(destination)

	while presenter.actor.walking_towards["location"] != null:
		_print_line("  ... still traveling toward %s (turn %d)" % [to_loc.location_name, world.turn_count])
		await presenter.on_continue_travel()

	_print_line("Arrived at %s!" % to_loc.location_name)
	_cmd_status()


func _cmd_activity(type: StrategyTypes.ActivityType, description: String):
	_print_line(description)
	presenter.on_activity_requested(type)
	while presenter.is_executing_activity:
		await get_tree().create_timer(0.05).timeout
	_cmd_status()


func _cmd_attack(target_id: String):
	if target_id.is_empty():
		_print_line("Usage: attack <squad_id>")
		_print_line("Squads with LOCKED contact at this location:")
		var loc_id := player_squad.current_location_id
		var ct = world.contact_tracker
		if ct == null:
			_print_line("  No contact tracker.")
			return
		var contacts = ct.get_contacts_for(player_squad.squad_id)
		var any_locked: bool = false
		for contact in contacts:
			if contact.get_state() == StrategyTypes.ContactState.LOCKED:
				var target_sq := _find_squad(contact.target_id)
				if target_sq and target_sq.current_location_id == loc_id:
					_print_line("  %s — %s (%d warriors)" % [contact.target_id, target_sq.squad_name, target_sq.get_living_warriors().size()])
					any_locked = true
		if not any_locked:
			_print_line("  No LOCKED contacts at this location. Patrol to build intel.")
		return

	_print_line("Attacking %s!" % target_id)
	presenter.on_activity_requested(StrategyTypes.ActivityType.ATTACK)
	while presenter.is_executing_activity:
		await get_tree().create_timer(0.05).timeout
	_cmd_status()


func _cmd_contacts():
	_print_separator()
	_print_line("=== Contact Intelligence ===")
	var ct = world.contact_tracker
	if ct == null:
		_print_line("  No contact tracker initialized.")
		_print_separator()
		return

	var contacts = ct.get_contacts_for(player_squad.squad_id)
	if contacts.size() == 0:
		_print_line("  No contacts detected. Try patrolling.")
		_print_separator()
		return

	for contact in contacts:
		var state = contact.get_state()
		if state == StrategyTypes.ContactState.NONE:
			continue
		var state_name: String = StrategyTypes.ContactState.keys()[state]
		var target_sq = _find_squad(contact.target_id)
		var target_name: String = str(contact.target_id)
		var target_loc: String = "unknown"
		if target_sq:
			target_name = target_sq.squad_name
			target_loc = _get_location_display(target_sq.current_location_id)
		_print_line("  %s [%s] — Progress: %.0f/100 — Location: %s" % [
			target_name, state_name, contact.progress, target_loc])
	_print_separator()


func _cmd_missions():
	_print_separator()
	_print_line("=== Missions ===")
	for faction in presenter.game_scenario.factions:
		_print_line("  --- %s ---" % faction.faction_name)
		for mission in faction.missions:
			var state := "LOCKED"
			if mission.is_completed:
				state = "COMPLETED"
			elif mission.is_failed:
				state = "FAILED"
			elif mission.is_unlocked:
				state = "ACTIVE"
			_print_line("    [%s] %s — %s" % [state, mission.trigger_id, mission.description])
	_print_separator()


func _cmd_events():
	_print_separator()
	_print_line("=== Events Fired ===")
	if _events_fired.is_empty():
		_print_line("  No events fired yet.")
	else:
		for eid in _events_fired:
			_print_line("  - %s" % eid)
	_print_line("")
	_print_line("=== Missions Completed ===")
	if _missions_completed.is_empty():
		_print_line("  No missions completed yet.")
	else:
		for mid in _missions_completed:
			_print_line("  - %s" % mid)
	_print_separator()


func _cmd_economy():
	_print_separator()
	_print_line("=== Economy Overview ===")
	if world.economy_engine == null:
		_print_line("  No economy engine active.")
		_print_separator()
		return

	for loc in world.get_economy_locations():
		var pop_count := loc.population.size() if loc.population else 0
		var avg_sat := loc.population.get_average_satisfaction() if loc.population else 0.0
		var food_stock := 0.0
		var stocks_str := ""
		if loc.inventory:
			for thing in loc.inventory.stocks:
				var amt = loc.inventory.stocks[thing]
				if amt > 0.1:
					var price = loc.inventory.prices[thing] if loc.inventory.prices.has(thing) else thing.base_price
					stocks_str += "    %s: %.0f (%.1fg)" % [thing.thing_name, amt, price]
					stocks_str += "\n"
				if thing.thing_type == EconomyTypes.ThingType.FOOD:
					food_stock = amt
		_print_line("  %s — Pop:%d Sat:%.0f Food:%.0f" % [
			loc.location_name, pop_count, avg_sat, food_stock])
		if not stocks_str.is_empty():
			print(stocks_str.strip_edges(false, true))
	_print_separator()


func _cmd_map():
	_print_separator()
	_print_line("=== World Map ===")
	for loc in world.locations:
		var marker := ""
		if loc.location_id == player_squad.current_location_id:
			marker = " <<<< YOU ARE HERE"
		var type_str := _location_type_str(loc.type)
		_print_line("  %s (%s) [%s]%s" % [loc.location_name, loc.location_id, type_str, marker])
		for conn in loc.connections.tt:
			var to_loc := world.get_location_by_id(conn.to_location_id)
			var to_name := to_loc.location_name if to_loc else conn.to_location_id
			_print_line("    → %s (%d turns)" % [to_name, conn.travel_time])

		var squads_here := world.get_squads_at_location(loc.location_id)
		for sq in squads_here:
			var role := "Caravan" if sq.is_caravan() else "Squad"
			var yours := " (YOU)" if sq.squad_id == player_squad.squad_id else ""
			_print_line("    * %s [%s, %d warriors]%s" % [sq.squad_name, role, sq.get_living_warriors().size(), yours])
	_print_separator()


func _cmd_recruit_info():
	_print_separator()
	_print_line("=== Recruitment ===")
	_print_line("  Recruitment is not yet interactive in terminal mode.")
	_print_line("  Available classes: Landsknecht(100g), Crossbowman(120g), Pikeman(130g),")
	_print_line("  Healer(150g), Feldprediger(180g), Arquebusier(200g), Gelehrter(250g)")
	_print_line("  Your gold: %.0f" % player_squad.money)
	_print_separator()


func _cmd_quit():
	_print_line("Farewell, commander!")
	_should_quit = true
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

#endregion


#region Helpers

func _find_squad(squad_id: String) -> SquadStrategicData:
	for sq in world.roaming_squads:
		if sq.squad_id == squad_id:
			return sq
	if player_squad.squad_id == squad_id:
		return player_squad
	return null


func _get_location_display(loc_id: String) -> String:
	var loc := world.get_location_by_id(loc_id)
	if loc:
		return "%s (%s)" % [loc.location_name, loc_id]
	return loc_id


func _location_type_str(loc_type) -> String:
	return StrategyTypes.LocationType.keys()[loc_type] if loc_type >= 0 else "UNKNOWN"


func _pos_str(pos) -> String:
	match pos:
		1: return "Front"
		2: return "Middle"
		3: return "Back"
		_: return "???"


func _print_line(text: String):
	print(text)


func _print_separator():
	print("────────────────────────────────────────────────────────")


func _print_event(text: String):
	print("")
	print("  ★ %s" % text)
	print("")


func _print_prompt():
	printt("")
	print("[Turn %d] %s @ %s > " % [
		world.turn_count,
		player_squad.squad_name,
		_get_location_display(player_squad.current_location_id)])


func _cmd_god_squads():
	_print_separator()
	_print_line("=== GOD: All Squads (omniscient) ===")
	_print_line("  Player: %s [%s] @ %s" % [
		player_squad.squad_name, player_squad.squad_id, player_squad.current_location_id])
	_print_line("")
	var caravans := 0
	var combat := 0
	for sq in world.roaming_squads:
		var role := "MERCHANT" if sq.is_caravan() else "COMBAT"
		var extra := ""
		if sq.is_caravan():
			caravans += 1
			extra = " → dest:%s cargo:%s" % [sq.cargo_destination_id, str(sq.cargo_manifest)]
			if sq.has_reached_destination():
				extra += " [AT DEST]"
		else:
			combat += 1
		_print_line("  %s [%s] @ %s — %s — %d warriors%s" % [
			sq.squad_name, sq.squad_id, sq.current_location_id,
			role, sq.get_living_warriors().size(), extra])
	_print_line("")
	_print_line("  Total: %d roaming (%d caravans, %d combat)" % [
		world.roaming_squads.size(), caravans, combat])
	_print_separator()


func _cmd_god_contacts():
	_print_separator()
	_print_line("=== GOD: Raw Contact Data ===")
	var ct = world.contact_tracker
	if ct == null:
		_print_line("  No contact tracker.")
		_print_separator()
		return
	var contacts = ct.get_contacts_for(player_squad.squad_id)
	if contacts.size() == 0:
		_print_line("  No contacts at all.")
		_print_separator()
		return
	for contact in contacts:
		var state_name: String = StrategyTypes.ContactState.keys()[contact.get_state()]
		var target_sq = _find_squad(contact.target_id)
		var sq_exists: bool = target_sq != null
		var sq_loc: String = target_sq.current_location_id if target_sq else "N/A"
		var sq_role: String = "MERCHANT" if (target_sq and target_sq.is_caravan()) else "COMBAT"
		var sq_alive: int = target_sq.get_living_warriors().size() if target_sq else -1
		_print_line("  target_id: %s" % contact.target_id)
		_print_line("    state: %s | progress: %.1f/100 | exists_in_world: %s" % [
			state_name, contact.progress, str(sq_exists)])
		_print_line("    location: %s | role: %s | warriors: %d" % [
			sq_loc, sq_role, sq_alive])
		_print_line("    being_tracked: %s | last_updated: %d" % [
			str(contact.being_tracked), contact.last_updated_turn])
		_print_line("")
	_print_separator()


func _cmd_god_lock(target_id: String):
	_print_separator()
	if target_id.is_empty():
		_print_line("Usage: god_lock <squad_id>")
		_print_line("Forces contact progress to 100 (LOCKED) on a target.")
		_print_line("Use god_squads to see squad IDs.")
		_print_separator()
		return
	var ct = world.contact_tracker
	if ct == null:
		_print_line("  No contact tracker.")
		_print_separator()
		return
	var contact = ct.get_or_create_contact(player_squad.squad_id, target_id)
	contact.progress = 100.0
	_print_line("GOD: Forced LOCKED contact on '%s'" % target_id)
	_print_line("You can now: attack %s" % target_id)
	_print_separator()


func _cmd_god_economy():
	_print_separator()
	_print_line("=== GOD: Full Economy ===")
	if world.economy_engine == null:
		_print_line("  No economy engine.")
		_print_separator()
		return
	var engine = world.economy_engine
	_print_line("  Turn: %d | Deaths: %d | Births: %d | Promotions: %d" % [
		world.turn_count, engine.total_deaths, engine.total_births, engine.total_promotions])
	_print_line("  Active contracts: %d | Completed: %d" % [
		engine.active_contracts_count, engine.completed_contracts_count])
	_print_line("")
	for loc in world.get_economy_locations():
		var pop_count := loc.population.size() if loc.population else 0
		var avg_sat := loc.population.get_average_satisfaction() if loc.population else 0.0
		_print_line("  --- %s (pop:%d sat:%.0f) ---" % [loc.location_name, pop_count, avg_sat])
		if loc.inventory:
			for thing in loc.inventory.stocks:
				var amt = loc.inventory.stocks[thing]
				var price = loc.inventory.prices[thing] if loc.inventory.prices.has(thing) else thing.base_price
				_print_line("    %s: stock=%.1f price=%.2f" % [thing.thing_name, amt, price])
		if loc.supply_rules and loc.supply_rules.size() > 0:
			for rule in loc.supply_rules:
				var action_name = EconomyTypes.RuleAction.keys()[rule.action]
				var thing_name = rule.thing.thing_name if rule.thing else "?"
				var source = rule.source_location_id if rule.source_location_id else "local"
				_print_line("    rule: %s %s from %s (qty:%.1f)" % [
					action_name, thing_name, source, rule.quantity])
	_print_separator()


func _print_banner():
	print("")
	print("╔══════════════════════════════════════════════════╗")
	print("║        CONDOR — Interactive Terminal Game        ║")
	print("║     Squad-Based Narrative Strategy (Headless)    ║")
	print("╠══════════════════════════════════════════════════╣")
	print("║  Type 'help' for commands. Type 'quit' to exit. ║")
	print("╚══════════════════════════════════════════════════╝")
	print("")

#endregion
