extends Node
## Interactive Systems-Layer Driver — play main.tscn from a terminal.
##
## Instantiates scenes/main.tscn (the Systems composition root), loads the
## prototype alpha/beta scenario paused, and accepts text commands from
## stdin. Lines starting with "/" are forwarded through the full HUD
## command-bar pipeline (CommandBarHud -> DebugCommandSystem -> dispatch in
## main.gd), exactly like typing into the GUI LineEdit.
##
## Usage: godot-mono --headless --path . scenes/demos/interactive_main.tscn
##
## Commands:
##   status        — Clock state + every squad (location, activity, travel)
##   tick [n]      — Advance n hours via ClockSystem.force_tick() (default 1)
##   pause         — Pause the clock
##   unpause       — Resume the clock
##   speed <n>     — Set clock speed in hours/second (GUI/real-time mode)
##   /<cmd> ...    — DebugCommandSystem command (e.g. "/travel commander beta")
##   help          — Show available commands
##   quit          — Exit the game

const MainGame = preload("res://src/main.gd")

var main: MainGame
var _initialized := false
var _busy := false
var _command_queue: Array[String] = []

var _stdin_thread: Thread
var _stdin_mutex: Mutex
var _stdin_buffer: Array[String] = []
var _should_quit := false


func _ready():
	MyLog.set_level(MyLog.Level.ERROR)
	if DisplayServer.get_name() == "headless":
		LogGd.disable_colors()

	print("")
	print("====================================================")
	print("  CONDOR — Systems Layer Interactive (main.tscn)")
	print("  Type 'help' for commands. Type 'quit' to exit.")
	print("====================================================")
	print("")

	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.load_prototype_scenario()

	var systems := main.systems
	systems.debug_command_system.command_failed.connect(
		func(raw_text: String, reason: String): print("COMMAND FAILED: %s (%s)" % [raw_text, reason]))
	systems.travel_system.location_changed.connect(
		func(squad_id: String, from_id: String, to_id: String): print("* %s moved: %s -> %s" % [squad_id, from_id, to_id]))
	systems.activity_run_system.activity_resolved.connect(
		func(squad: StrategySquad, activity: Activity, _results: Array): print("* %s ran %s" % [
			squad.squad_name, StrategyTypes.ActivityType.keys()[activity.activity_type],
		]))
	systems.battle_system.battle_resolved.connect(
		func(attacker: StrategySquad, defender: StrategySquad, _result: CombatController.CombatResult): print(
			"* battle resolved: %s vs %s" % [attacker.squad_name, defender.squad_name]))

	_stdin_mutex = Mutex.new()
	_stdin_thread = Thread.new()
	_stdin_thread.start(_stdin_reader)

	_initialized = true
	print("Game ready!")
	_cmd_status()


func _process(_delta):
	if not _initialized or _busy:
		return

	_stdin_mutex.lock()
	var lines = _stdin_buffer.duplicate()
	_stdin_buffer.clear()
	_stdin_mutex.unlock()

	for line in lines:
		_command_queue.append(line)

	if _command_queue.size() > 0:
		var cmd = _command_queue.pop_front()
		_busy = true
		await _handle_command(cmd)
		_busy = false


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


func _handle_command(input: String):
	var parts := input.split(" ", false)
	if parts.is_empty():
		return

	var cmd := parts[0].to_lower()
	var arg := parts[1] if parts.size() > 1 else ""

	if input.begins_with("/"):
		main.hud_layer.command_bar_hud.command_submitted.emit(input)
	elif cmd in ["help", "h", "?"]:
		_cmd_help()
	elif cmd in ["status", "s"]:
		_cmd_status()
	elif cmd == "tick":
		await _cmd_tick(arg)
	elif cmd == "pause":
		main.systems.clock_system.pause()
		print("Clock paused at hour %d." % main.systems.clock_system.current_hour)
	elif cmd == "unpause":
		main.systems.clock_system.unpause()
		print("Clock running at %.1f hours/second." % main.systems.clock_system.hours_per_second)
	elif cmd == "speed":
		if arg.is_empty():
			print("Usage: speed <hours_per_second>")
		else:
			main.systems.clock_system.set_speed(float(arg))
			print("Clock speed set to %.1f hours/second." % main.systems.clock_system.hours_per_second)
	elif cmd in ["quit", "q", "exit"]:
		print("Farewell, commander!")
		_should_quit = true
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()
	else:
		print("Unknown command: '%s'. Type 'help' for available commands." % cmd)


func _cmd_help():
	print("----------------------------------------------------")
	print("  STATUS  (s)        Clock state + all squads")
	print("  TICK    [n]        Advance n hours (default 1)")
	print("  PAUSE              Pause the clock")
	print("  UNPAUSE            Resume the clock")
	print("  SPEED   <n>        Set clock hours/second")
	print("  /<cmd>  ...        DebugCommandSystem command")
	print("                     (e.g. /travel commander beta)")
	print("  HELP    (h/?)      This help text")
	print("  QUIT    (q)        Exit the game")
	print("----------------------------------------------------")


func _cmd_status():
	var clock := main.systems.clock_system
	var state := "PAUSED" if clock.is_paused else "RUNNING (%.1f h/s)" % clock.hours_per_second
	print("----------------------------------------------------")
	print("=== Hour %d (Day %d) — %s ===" % [clock.current_hour, clock.current_hour / 24, state])
	for squad: StrategySquad in main.systems.squad_being_system.get_all_squads():
		var line := "  %s [%s] @ %s — %s — %dw — food %d, gold %.0f" % [
			squad.squad_name, squad.squad_id, squad.current_location_id,
			StrategyTypes.ActivityType.keys()[squad.current_activity_type],
			squad.get_living_warriors().size(), squad.food, squad.money,
		]
		if squad.is_traveling():
			line += " — traveling %s (%.0f km into route)" % ["->".join(squad.travel_route), squad.travel_progress_km]
		print(line)
	print("----------------------------------------------------")


func _cmd_tick(arg: String):
	var hours := int(arg) if not arg.is_empty() else 1
	if hours <= 0:
		print("Must tick at least 1 hour.")
		return
	var clock := main.systems.clock_system
	for i in range(hours):
		clock.force_tick()
		await get_tree().process_frame
	print("Advanced %d hour(s). Now: Hour %d (Day %d)." % [hours, clock.current_hour, clock.current_hour / 24])
