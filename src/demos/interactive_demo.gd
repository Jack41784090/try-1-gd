extends Node
## Run via: godot-mono --headless --path . scenes/demos/interactive_demo.tscn — type 'help' for commands.

const SCENARIO_PATH := "res://resources/strategy/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")

var presenter: StrategyPresenter
var player_squad: StrategySquad
var world: World

var _events_fired: Array[String] = []
var _missions_completed: Array[String] = []
var _initialized := false
var _command_queue: Array[String] = []

var _stdin_thread: Thread
var _stdin_mutex: Mutex
var _stdin_buffer: Array[String] = []
var _should_quit := false

func _ready():
	MyLog.set_level(MyLog.Level.ERROR)

	print("")
	print("╔══════════════════════════════════════════════════╗")
	print("║        CONDOR — Interactive Terminal Game        ║")
	print("║     Squad-Based Narrative Strategy (Headless)    ║")
	print("╠══════════════════════════════════════════════════╣")
	print("║  Type 'help' for commands. Type 'quit' to exit. ║")
	print("╚══════════════════════════════════════════════════╝")
	print("")
	_print_line("Initializing game scenario...")

	var is_gui := DisplayServer.get_name() != "headless"

	if is_gui:
		var real_scene: Node = load("res://scenes/scenario.tscn").instantiate()
		add_child(real_scene)
		presenter = real_scene.get_node("StrategyPresenter") as StrategyPresenter
		while presenter.actor == null:
			await get_tree().create_timer(0.1).timeout
	else:
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

	for t in presenter.game_scenario.triggerable_manager.registered_triggerables:
		if t is GameEvent and t.times_triggered > 0:
			_events_fired.append(t.trigger_id)
	for faction in presenter.game_scenario.factions:
		for mission in faction.missions:
			if mission.is_completed:
				_missions_completed.append(mission.mission_id)

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
			_print_separator()
			_print_line("=== Warriors ===")
			var living = player_squad.get_living_warriors()
			for i in range(living.size()):
				var w = living[i]
				var pos_name: String
				match w.location_prebattle:
					1: pos_name = "Front"
					2: pos_name = "Middle"
					3: pos_name = "Back"
					_: pos_name = "???"
				var status := ""
				if w.is_injured:
					status = " [INJURED]"
				elif w.is_dead:
					status = " [DEAD]"
				_print_line("  %d. %s — %s | Position: %s | Morale: %.0f%s" % [
					i + 1, w.display_name, w.identification, pos_name, float(w.get_stat_value(StatName.I.MORALE)), status])
			_print_separator()
		"inventory", "inv":
			_print_separator()
			_print_line("=== Squad Inventory ===")
			var inv = player_squad.inventory
			if inv.is_empty():
				_print_line("  (empty)")
			else:
				if not inv.weapons.is_empty():
					_print_line("  Weapons:")
					for w in inv.weapons:
						_print_line("    - %s" % SquadBattleTypes.WeaponClasses.keys()[w.weapon_class])
				if not inv.armors.is_empty():
					_print_line("  Armors:")
					for a in inv.armors:
						_print_line("    - %s" % SquadBattleTypes.ArmorClasses.keys()[a.armor_class])
			_print_line("")
			_print_line("=== StrategyEntity Equipment ===")
			for w in player_squad.get_living_warriors():
				var weapon_name := "None"
				var armor_name := "None"
				var equipped_weapon := w.get_equipped_weapon()
				var equipped_armor := w.get_equipped_armor()
				if equipped_weapon:
					weapon_name = SquadBattleTypes.WeaponClasses.keys()[equipped_weapon.weapon_class]
				if equipped_armor:
					armor_name = SquadBattleTypes.ArmorClasses.keys()[equipped_armor.armor_class]
				_print_line("  %s — W: %s | A: %s" % [w.display_name, weapon_name, armor_name])
			_print_separator()
		"travel", "t":
			await _cmd_travel(arg)
		"rest":
			await _cmd_activity(StrategyTypes.ActivityType.REST, "Resting...", arg)
		"forage", "f":
			await _cmd_activity(StrategyTypes.ActivityType.FORAGE, "Foraging for supplies...", arg)
		"drill":
			await _cmd_activity(StrategyTypes.ActivityType.DRILL, "Drilling troops...", arg)
		"patrol", "p":
			await _cmd_activity(StrategyTypes.ActivityType.PATROL, "Patrolling the area...", arg)
		"heal":
			await _cmd_activity(StrategyTypes.ActivityType.HEAL, "Healing injured warriors...", arg)
		"buy":
			await _cmd_activity(StrategyTypes.ActivityType.BUY_SUPPLIES, "Buying supplies...", arg)
		"mercenary", "merc":
			await _cmd_activity(StrategyTypes.ActivityType.MERCENARY_WORK, "Doing mercenary work...", arg)
		"mass":
			await _cmd_activity(StrategyTypes.ActivityType.HOLD_MASS, "Holding mass...", arg)
		"recruit":
			_cmd_recruit(arg)
		"attack", "a":
			if arg.is_empty():
				_print_line("Usage: attack <squad_id>")
				_print_line("Squads with LOCKED contact at this location:")
				var loc_id := player_squad.current_location_id
				var ct = world.contact_tracker
				if ct == null:
					_print_line("  No contact tracker.")
				else:
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
			else:
				_print_line("Attacking %s!" % arg)
				var snap := _snapshot_state()
				presenter.on_activity_requested(StrategyTypes.ActivityType.ATTACK)
				while presenter.is_executing_activity:
					await get_tree().create_timer(0.05).timeout
				_print_turn_report(snap)
		"contacts", "c":
			_print_separator()
			_print_line("=== Contact Intelligence ===")
			var ct = world.contact_tracker
			if ct == null:
				_print_line("  No contact tracker initialized.")
				_print_separator()
			else:
				var contacts = ct.get_contacts_for(player_squad.squad_id)
				if contacts.size() == 0:
					_print_line("  No contacts detected. Try patrolling.")
					_print_separator()
				else:
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
		"missions", "m":
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
		"events":
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
		"notifications", "notif", "n":
			var view = presenter.view
			var notifs: Array = view.last_notifications if "last_notifications" in view else []
			_print_separator()
			_print_line("=== Active Notifications ===")
			if notifs.is_empty():
				_print_line("  No active notifications.")
			else:
				for n in notifs:
					var type_name: String = NotificationData.NotificationType.keys()[n.type]
					_print_line("  [%s] %s" % [type_name, n.title])
					if n.description != "":
						_print_line("    %s" % n.description)
			_print_separator()
		"economy", "econ", "e":
			_print_separator()
			_print_line("=== Economy Overview ===")
			assert(world.economy_engine != null, "Economy command requires initialized world.economy_engine")

			for loc in world.get_economy_locations():
				var pop_count := loc.population.size() if loc.population else 0
				var avg_sat := loc.population.get_average_satisfaction() if loc.population else 0.0
				var food_stock := 0.0
				var stocks_str := ""
				assert(loc.inventory != null, "Economy command found location '%s' without inventory" % loc.location_id)
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
		"map":
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
					_print_line("    → %s (%.0f km)" % [to_name, conn.distance_km])

				var squads_here := world.get_squads_at_location(loc.location_id)
				for sq in squads_here:
					var role := "Caravan" if sq.is_caravan() else "Squad"
					var yours := " (YOU)" if sq.squad_id == player_squad.squad_id else ""
					_print_line("    * %s [%s, %d warriors]%s" % [sq.squad_name, role, sq.get_living_warriors().size(), yours])
			_print_separator()
		"god_squads", "gs":
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
					extra = " → dest:%s cargo:%s" % [sq.cargo.destination_id, str(sq.cargo.manifest)]
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
		"god_contacts", "gc":
			_print_separator()
			_print_line("=== GOD: Raw Contact Data ===")
			var ct = world.contact_tracker
			if ct == null:
				_print_line("  No contact tracker.")
				_print_separator()
			else:
				var contacts = ct.get_contacts_for(player_squad.squad_id)
				if contacts.size() == 0:
					_print_line("  No contacts at all.")
					_print_separator()
				else:
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
							str(contact.being_tracked), contact.last_updated_hour])
						_print_line("")
					_print_separator()
		"god_lock", "gl":
			_print_separator()
			if arg.is_empty():
				_print_line("Usage: god_lock <squad_id>")
				_print_line("Forces contact progress to 100 (LOCKED) on a target.")
				_print_line("Use god_squads to see squad IDs.")
				_print_separator()
			else:
				var ct = world.contact_tracker
				if ct == null:
					_print_line("  No contact tracker.")
					_print_separator()
				else:
					var contact = ct.get_or_create_contact(player_squad.squad_id, arg)
					contact.progress = 100.0
					_print_line("GOD: Forced LOCKED contact on '%s'" % arg)
					_print_line("You can now: attack %s" % arg)
					_print_separator()
		"god_economy", "ge":
			_print_separator()
			_print_line("=== GOD: Full Economy ===")
			assert(world.economy_engine != null, "god_economy command requires initialized world.economy_engine")
			var engine = world.economy_engine
			_print_line("  Hour: %d | Deaths: %d | Births: %d | Promotions: %d" % [
				world.current_hour, engine.total_deaths, engine.total_births, engine.total_promotions])
			_print_line("  Active contracts: %d | Completed: %d" % [
				engine.active_contracts_count, engine.completed_contracts_count])
			_print_line("")
			for loc in world.get_economy_locations():
				var pop_count := loc.population.size() if loc.population else 0
				var avg_sat := loc.population.get_average_satisfaction() if loc.population else 0.0
				_print_line("  --- %s (pop:%d sat:%.0f) ---" % [loc.location_name, pop_count, avg_sat])
				assert(loc.inventory != null, "god_economy found location '%s' without inventory" % loc.location_id)
				for thing in loc.inventory.stocks:
					var amt = loc.inventory.stocks[thing]
					var price = loc.inventory.prices[thing] if loc.inventory.prices.has(thing) else thing.base_price
					_print_line("    %s: stock=%.1f price=%.2f" % [thing.thing_name, amt, price])
				if loc.natural_resources and loc.natural_resources.size() > 0:
					for resource in loc.natural_resources:
						var thing_name = resource.thing.thing_name if resource.thing else "?"
						var job_name = EconomyTypes.JobType.keys()[resource.worker_job]
						_print_line("    resource: %s (capacity:%.1f, job:%s)" % [
							thing_name, resource.base_capacity, job_name])
			_print_separator()
		"screenshot", "ss":
			await _cmd_screenshot(arg)
		"pause", "pp":
			presenter.game_clock.toggle_pause()
			var state := "PAUSED" if world.is_paused else "RUNNING (speed %.1fx)" % world.speed_multiplier
			_print_line("Game clock: %s | Hour %d (Day %d, %s)" % [state, world.current_hour, world.get_day(), world.get_clock_display()])
		"speed":
			if arg.is_empty():
				_print_line("Current speed: %.1fx | %s" % [world.speed_multiplier, "PAUSED" if world.is_paused else "RUNNING"])
				_print_line("Usage: speed <multiplier>  (e.g. speed 5)")
			else:
				var spd := float(arg)
				if spd <= 0.0:
					_print_line("Speed must be positive.")
				else:
					presenter.game_clock.set_speed(spd)
					_print_line("Speed set to %.1fx" % spd)
		"tick":
			var hours := int(arg) if not arg.is_empty() else 1
			if hours <= 0:
				_print_line("Must tick at least 1 hour.")
			elif not world.is_paused:
				_print_line("Pause the game first (use 'pause'), then tick manually.")
			else:
				var snap := _snapshot_state()
				for i in range(hours):
					var act_type := player_squad.current_activity_type
					var activity = presenter.actor.get_activity(act_type)
					if activity:
						var handler = Activity._get_registry().get_handler(act_type)
						if handler:
							var ctx := {"squad": player_squad, "world": world, "location": world.get_location_by_id(player_squad.current_location_id)}
							handler.execute(ctx, ActivityResult.new())
					world.current_hour += 1
					presenter.game_clock.gameclock_hour_tick.emit(world.current_hour)
					await get_tree().create_timer(0.1).timeout
					while presenter.is_executing_activity:
						await get_tree().create_timer(0.05).timeout
				_print_line("Advanced %d hour(s). Now: Hour %d (Day %d, %s)" % [hours, world.current_hour, world.get_day(), world.get_clock_display()])
				_print_turn_report(snap)
		"check_missions", "cm":
			await _cmd_check_missions()
		"click", "advance", "x":
			var vn_pres = presenter.vn_view.presenter if presenter.vn_view else null
			if vn_pres and (vn_pres._debug_chain_pending or vn_pres.is_playing_chain):
				vn_pres.on_advance()
				_print_line("Advanced dialog.")
			else:
				_print_line("No active dialog to advance.")
		"quit", "q", "exit":
			_print_line("Farewell, commander!")
			_should_quit = true
			await get_tree().create_timer(0.2).timeout
			get_tree().quit()
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
	_print_line("  INVENTORY (inv)   Squad equipment inventory")
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
	_print_line("  NOTIF   (n)       Active notifications")
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
	_print_line("")
	_print_line("  --- SCREENSHOT ---")
	_print_line("  SCREENSHOT (ss) [path]  Save viewport screenshot (GUI mode only)")
	_print_line("")
	_print_line("  --- TIME CONTROL ---")
	_print_line("  PAUSE   (pp)      Toggle pause on/off")
	_print_line("  SPEED   <n>       Set speed multiplier (e.g. speed 5)")
	_print_line("  TICK    [n]       Advance n hours (default 1, game must be paused)")
	_print_line("  CLICK   (x)       Advance/dismiss current dialog")
	_print_separator()

func _cmd_status():
	_print_separator()
	var living = player_squad.get_living_warriors()
	var injured := 0
	for w in living:
		if w.is_injured:
			injured += 1

	_print_line("=== %s — %s ===" % [player_squad.squad_name, world.get_clock_display()])
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
		_print_line("    → %s (%s) — %.0f km" % [to_name, conn.to_location_id, conn.distance_km])

	_print_line("")
	_print_line("  --- Available Activities ---")
	var activities: Array[String] = []
	for at in loc.available_activity_types:
		activities.append(StrategyTypes.ActivityType.keys()[at])
	_print_line("    %s" % ", ".join(activities))

	if loc.has_shop():
		assert(loc.inventory != null, "Shop location '%s' is missing inventory" % loc.location_id)
		var inv := loc.inventory
		_print_line("")
		_print_line("  --- Shop: %s ---" % loc.shop.shop_name)
		for item in loc.shop.items:
			var price: float = inv.prices[item] if inv.prices.has(item) else item.base_price
			var stock_str := " (stock: %.0f)" % inv.stocks[item] if inv.stocks.has(item) else ""
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

func _cmd_travel(destination: String):
	if destination.is_empty():
		_print_line("Usage: travel <location_id>")
		_print_line("Connected locations:")
		var loc := world.get_location_by_id(player_squad.current_location_id)
		for conn in loc.connections.tt:
			var connected_loc := world.get_location_by_id(conn.to_location_id)
			var to_name := connected_loc.location_name if connected_loc else conn.to_location_id
			_print_line("  %s — %s (%.0f km)" % [conn.to_location_id, to_name, conn.distance_km])
		return

	var to_loc := world.get_location_by_id(destination)
	if not to_loc:
		_print_line("Unknown location: '%s'. Type 'look' to see connections." % destination)
		return

	_print_line("Setting out for %s..." % to_loc.location_name)
	var snap := _snapshot_state()
	presenter.on_travel_confirmed(destination)

	var was_paused := world.is_paused
	var max_hours := 200
	var hours_traveled := 0
	while presenter.actor.walking_towards["location"] != null and hours_traveled < max_hours:
		world.current_hour += 1
		presenter.game_clock.gameclock_hour_tick.emit(world.current_hour)
		while presenter.is_executing_activity:
			await get_tree().create_timer(0.05).timeout
		hours_traveled += 1

	if presenter.actor.walking_towards["location"] != null:
		_print_line("Travel still in progress after %d hours." % hours_traveled)
	else:
		_print_line("Arrived at %s! (%d hours)" % [to_loc.location_name, hours_traveled])
	presenter.actor.aem.player_squad.current_location_id = player_squad.current_location_id
	if was_paused:
		world.is_paused = true
	_print_turn_report(snap)

func _cmd_activity(type: StrategyTypes.ActivityType, description: String, arg: String = ""):
	var hours := int(arg) if not arg.is_empty() else 1
	if hours <= 0:
		hours = 1
	_print_line(description)
	player_squad.current_activity_type = type
	var snap := _snapshot_state()
	for i in range(hours):
		var handler = Activity._get_registry().get_handler(type)
		if handler:
			var ctx := {"squad": player_squad, "world": world, "location": world.get_location_by_id(player_squad.current_location_id)}
			handler.execute(ctx, ActivityResult.new())
		world.current_hour += 1
		presenter.game_clock.gameclock_hour_tick.emit(world.current_hour)
		await get_tree().create_timer(0.1).timeout
		while presenter.is_executing_activity:
			await get_tree().create_timer(0.05).timeout
	_print_turn_report(snap)

var _RECRUIT_COSTS: Dictionary = {
	EntityClasses.Types.Landsknecht: 100.0,
	EntityClasses.Types.Healer: 150.0,
	EntityClasses.Types.Crossbowman: 120.0,
	EntityClasses.Types.Arquebusier: 200.0,
	EntityClasses.Types.Pikeman: 130.0,
	EntityClasses.Types.Feldprediger: 180.0,
	EntityClasses.Types.Gelehrter: 250.0,
}

var _RECRUIT_LOGIC: Dictionary = {
	EntityClasses.Types.Landsknecht: LogicFactory.LogicAvailable.Frontline,
	EntityClasses.Types.Healer: LogicFactory.LogicAvailable.BacklineHeal,
	EntityClasses.Types.Crossbowman: LogicFactory.LogicAvailable.BacklineShooter,
	EntityClasses.Types.Arquebusier: LogicFactory.LogicAvailable.BacklineGunner,
	EntityClasses.Types.Pikeman: LogicFactory.LogicAvailable.DefensiveFrontline,
	EntityClasses.Types.Feldprediger: LogicFactory.LogicAvailable.BacklineSupport,
	EntityClasses.Types.Gelehrter: LogicFactory.LogicAvailable.BacklineCaster,
}

var _RECRUIT_POS: Dictionary = {
	EntityClasses.Types.Landsknecht: SquadBattleTypes.SquadEntityInSquadLocation.Front,
	EntityClasses.Types.Healer: SquadBattleTypes.SquadEntityInSquadLocation.Back,
	EntityClasses.Types.Crossbowman: SquadBattleTypes.SquadEntityInSquadLocation.Back,
	EntityClasses.Types.Arquebusier: SquadBattleTypes.SquadEntityInSquadLocation.Back,
	EntityClasses.Types.Pikeman: SquadBattleTypes.SquadEntityInSquadLocation.Front,
	EntityClasses.Types.Feldprediger: SquadBattleTypes.SquadEntityInSquadLocation.Back,
	EntityClasses.Types.Gelehrter: SquadBattleTypes.SquadEntityInSquadLocation.Back,
}

func _cmd_recruit(arg: String):
	if arg.is_empty():
		_print_separator()
		_print_line("=== Recruitment — recruit <background> ===")
		for bg in WarriorBackgroundFactory.all():
			_print_line("  %-14s (%dg) %s" % [bg.background_id, bg.cost, bg.display_name])
		_print_line("  Your gold: %.0f" % player_squad.money)
		_print_separator()
		return

	var backgrounds := WarriorBackgroundFactory.all()
	var selected: WarriorBackground = null
	for bg in backgrounds:
		if bg.background_id.to_lower() == arg.to_lower():
			selected = bg
			break
	if selected == null:
		_print_line("Unknown background: '%s'. Type 'recruit' to see options." % arg)
		return

	var cost: int = selected.cost
	if player_squad.money < cost:
		_print_line("Not enough gold! Need %d, have %.0f" % [cost, player_squad.money])
		return

	var new_entity := StrategyEntityFactory.Create(selected, StrategyTypes.Religion.CATHOLIC)
	new_entity.id = "warrior_%d_%d" % [world.current_hour, randi()]
	var new_warrior := Character.new(new_entity)
	player_squad.add_warrior(new_warrior)
	player_squad.money -= cost
	_print_line("Recruited %s for %d gold! (%.0f gold remaining)" % [new_warrior.display_name, cost, player_squad.money])

#endregion

#region Turn Report

func _snapshot_state() -> Dictionary:
	var contacts_snap := {}
	var ct = world.contact_tracker
	if ct:
		for contact in ct.get_contacts_for(player_squad.squad_id):
			contacts_snap[contact.target_id] = {
				"progress": contact.progress,
				"state": contact.get_state(),
			}

	var squad_positions := {}
	for sq in world.roaming_squads:
		squad_positions[sq.squad_id] = {
			"location": sq.current_location_id,
			"warriors": sq.get_living_warriors().size(),
			"name": sq.squad_name,
		}

	return {
		"turn": world.current_hour,
		"location": player_squad.current_location_id,
		"warriors": player_squad.get_living_warriors().size(),
		"injured": player_squad.get_living_warriors().filter(func(w): return w.is_injured).size(),
		"morale": player_squad.get_morale(),
		"food": player_squad.food,
		"gold": player_squad.money,
		"tools": player_squad.travel_tools,
		"karma": player_squad.karma,
		"events_count": _events_fired.size(),
		"missions_count": _missions_completed.size(),
		"contacts": contacts_snap,
		"squads": squad_positions,
	}

func _print_turn_report(before: Dictionary):
	var after := _snapshot_state()
	_print_separator()
	_print_line("── Hour %d → %d Report ──" % [before["turn"], world.current_hour])

	if presenter.turn_log.size() > 0:
		_print_line("")
		_print_line("  Pipeline:")
		for entry in presenter.turn_log:
			_print_line("    %s" % entry)

	var new_events := _events_fired.slice(before["events_count"])
	var new_missions := _missions_completed.slice(before["missions_count"])
	if new_events.size() > 0 or new_missions.size() > 0:
		_print_line("")
		_print_line("  Triggers:")
		for eid in new_events:
			_print_line("    ★ EVENT %s" % eid)
		for mid in new_missions:
			_print_line("    ★ MISSION %s" % mid)

	_print_line("")
	_print_line("  Squad Delta:")
	var loc_before: String = before["location"]
	var loc_after: String = after["location"]
	if loc_before != loc_after:
		_print_line("    Location: %s → %s" % [
			_get_location_display(loc_before), _get_location_display(loc_after)])

	_print_stat_delta("    Morale", before["morale"], after["morale"], "%.0f")
	_print_stat_delta("    Food", before["food"], after["food"], "%d")
	_print_stat_delta("    Gold", before["gold"], after["gold"], "%.0f")
	_print_stat_delta("    Tools", before["tools"], after["tools"], "%d")

	var w_before: int = before["warriors"]
	var w_after: int = after["warriors"]
	var inj_before: int = before["injured"]
	var inj_after: int = after["injured"]
	if w_before != w_after or inj_before != inj_after:
		_print_line("    Warriors: %d → %d (injured: %d → %d)" % [
			w_before, w_after, inj_before, inj_after])

	var contacts_before: Dictionary = before["contacts"]
	var contacts_after := {}
	var ct = world.contact_tracker
	if ct:
		for contact in ct.get_contacts_for(player_squad.squad_id):
			contacts_after[contact.target_id] = {
				"progress": contact.progress,
				"state": contact.get_state(),
			}

	var contact_changes := false
	for tid in contacts_after:
		var a_state: int = contacts_after[tid]["state"]
		var a_progress: float = contacts_after[tid]["progress"]
		if a_state == StrategyTypes.ContactState.NONE:
			continue
		var b_progress: float = contacts_before.get(tid, {}).get("progress", 0.0)
		if abs(a_progress - b_progress) > 0.5 or not contacts_before.has(tid):
			if not contact_changes:
				_print_line("")
				_print_line("  Contacts:")
				contact_changes = true
			var state_name: String = StrategyTypes.ContactState.keys()[a_state]
			var target_name: String = tid
			var sq := _find_squad(tid)
			if sq:
				target_name = sq.squad_name
			_print_line("    %s [%s] %.0f → %.0f" % [target_name, state_name, b_progress, a_progress])

	var squads_before: Dictionary = before["squads"]
	var squad_changes := false
	for sq in world.roaming_squads:
		var sid := sq.squad_id
		if squads_before.has(sid):
			var sb = squads_before[sid]
			if sb["location"] != sq.current_location_id or sb["warriors"] != sq.get_living_warriors().size():
				if not squad_changes:
					_print_line("")
					_print_line("  World:")
					squad_changes = true
				var details := "%s: %s→%s %dw" % [
					sq.squad_name, sb["location"], sq.current_location_id,
					sq.get_living_warriors().size()]
				if sb["warriors"] != sq.get_living_warriors().size():
					details += " (was %d)" % sb["warriors"]
				_print_line("    %s" % details)
		else:
			if not squad_changes:
				_print_line("")
				_print_line("  World:")
				squad_changes = true
			var role := "Caravan" if sq.is_caravan() else "Squad"
			_print_line("    NEW %s: %s at %s (%dw)" % [
				role, sq.squad_name, sq.current_location_id, sq.get_living_warriors().size()])

	for sid in squads_before:
		if not _find_squad(sid):
			if not squad_changes:
				_print_line("")
				_print_line("  World:")
				squad_changes = true
			_print_line("    REMOVED: %s" % squads_before[sid]["name"])

	_print_separator()
	_cmd_status()

func _print_stat_delta(label: String, before_val, after_val, fmt: String):
	if typeof(before_val) == TYPE_FLOAT and typeof(after_val) == TYPE_FLOAT:
		if abs(before_val - after_val) < 0.01:
			return
	elif before_val == after_val:
		return
	var delta = after_val - before_val
	var delta_sign := "+" if delta > 0 else ""
	_print_line("%s: %s → %s (%s%s)" % [
		label, fmt % before_val, fmt % after_val, delta_sign, fmt % delta])

#endregion

#region Helpers

func _find_squad(squad_id: String) -> StrategySquad:
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
	print("[%s] %s @ %s > " % [
		world.get_clock_display(),
		player_squad.squad_name,
		_get_location_display(player_squad.current_location_id)])

const SCREENSHOT_PATH := "/tmp/condor_screenshot.jpg"

func _cmd_screenshot(arg: String):
	var path := arg if not arg.is_empty() else SCREENSHOT_PATH
	if DisplayServer.get_name() == "headless":
		_print_line("ERROR: Screenshots require GUI mode. Use tools/start_game_gui.sh")
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var max_width := 640
	if image.get_width() > max_width:
		var scale := float(max_width) / float(image.get_width())
		var new_h := int(float(image.get_height()) * scale)
		image.resize(max_width, new_h, Image.INTERPOLATE_BILINEAR)
	if path.ends_with(".jpg") or path.ends_with(".jpeg"):
		var err := image.save_jpg(path, 0.7)
		if err != OK:
			_print_line("ERROR: Failed to save screenshot (error %d)" % err)
			return
	else:
		var err := image.save_png(path)
		if err != OK:
			_print_line("ERROR: Failed to save screenshot (error %d)" % err)
			return
	_print_line("SCREENSHOT_SAVED:%s" % path)

func _cmd_debug_activities():
	_print_line("Current activity type: %s" % StrategyTypes.ActivityType.keys()[player_squad.current_activity_type])
	var activity = presenter.actor.get_activity(player_squad.current_activity_type)
	_print_line("Activity found: %s" % (activity.trigger_name if activity else "NULL"))
	_print_line("Registered triggerables:")
	for t in presenter.actor.aem.scenario.triggerable_manager.registered_triggerables:
		if t is Activity:
			_print_line("  Activity: %s (type=%s)" % [t.trigger_name, StrategyTypes.ActivityType.keys()[t.activity_type]])

func _cmd_check_missions():
	_print_line("Checking missions...")
	# Sync AEM's player_squad location with the actual player_squad — the two must match before mission checks run
	presenter.actor.aem.player_squad.current_location_id = player_squad.current_location_id
	var context := {
		"squad": player_squad,
		"world": world,
		"activity": null,
		"location": world.get_location_by_id(player_squad.current_location_id),
		"prev_location": null,
		"next_location": null,
		"is_location_changing": false,
		"turn": world.current_hour,
		"completed_missions": [],
	}
	for faction in presenter.game_scenario.factions:
		for id in faction.get_completed_mission_ids():
			context["completed_missions"].append(id)
		var results = faction.check_mission_completions(context)
		for r in results:
			_print_line("  ★ MISSION COMPLETED: %s" % r.mission_id)
			for unlocked_id in r.unlocked_missions:
				var unlocked_mission = faction.get_mission_by_id(unlocked_id)
				if unlocked_mission:
					unlocked_mission.unlock()
					_print_line("    → Unlocked: %s" % unlocked_id)

	await presenter._check_missions()
	var snap := _snapshot_state()
	_print_turn_report(snap)

#endregion
