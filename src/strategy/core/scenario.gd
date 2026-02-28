class_name GameScenario extends Resource

var triggerable_manager: TriggerableManager

@export var starting_player_squad: Squad
@export var starting_location_id: String
@export var world: World
@export var factions: Array[Faction] = []
@export var endings: Array[Ending] = []
@export var extra_event_directories: Array[String] = []

var rng = RandomNumberGenerator.new()
var game_ended: bool = false
var ending_triggered: Ending = null
var _initialized: bool = false

func _init(config: Dictionary = {}) -> void:
	print(" --- new scenario init --- ")

	if config.is_empty():
		print(" Should follow a \"Manual INIT func call\" ")
	else:
		print(" --- Config is not empty, setting up now using premade configs --- ")
		_setup(config)
		_initialized = true

func initialize(_config = {}) -> void:
	print(" --- Manual INIT func called --- ")
	assert(not _initialized, "scenario->initialize must not be called when it has already initialised through other means.")
	_setup(_config)
	_initialized = true

func _setup(config: Dictionary) -> void:
	# Core setup that loads all game data: world, squads, factions, triggerables (events, activities, missions, endings)
	# Uses exported @export properties if already set (from .tres resource files), falls back to config dict
	# Registration order: factions→missions → endings → events → activities → set location
	# e.g., world has 5 locations, 2 factions with 3 missions each, 10 generic events, 8 activities
	#   → triggerable_manager gets 6 missions + 2 endings + 10 events + 8 activities = 26 triggerables
	print("Scenario setup: ", config);
	# 1. Initialize triggerable_manager — central registry for all game triggerables
	triggerable_manager = TriggerableManager.new()
	
	# Use exported properties if already set (from .tres), otherwise use config
	if world == null:
		world = config.get("world", World.new())
	assert(world.map_scene != null, "World requires a map_scene PackedScene to be set")
	if starting_player_squad == null:
		starting_player_squad = config.get("starting_player_squad")
		assert(starting_player_squad != null, "GameScenario requires starting_player_squad to be set")
	starting_player_squad.ensure_initialized()
	
	# Register factions (either from exported array or config)
	var config_factions = config.get("factions", [])
	if not config_factions.is_empty():
		for faction in config_factions:
			if faction is Faction:
				factions.append(faction)
	
	for faction in factions:
		# Register all missions from this faction
		for mission in faction.missions:
			triggerable_manager.register(mission)
	
	# Register endings (either from exported array or config)
	var config_endings = config.get("endings", [])
	if not config_endings.is_empty():
		for ending in config_endings:
			if ending is Ending:
				endings.append(ending)
	
	for ending in endings:
		triggerable_manager.register(ending)
	
	# Register events - if none provided, load default generic events
	var events: Array = config.get("events", [])
	if events.is_empty():
		events = _load_generic_events()
	for extra_dir in extra_event_directories:
		_collect_event_resources(extra_dir, events)
	for event in events:
		if event is GameEvent:
			triggerable_manager.register(event)
	
	# Register activities - if none provided, load default generic activities
	var activities: Array = config.get("activities", [])
	if activities.is_empty():
		activities = _load_generic_activities()
	for activity in activities:
		if activity is Activity:
			triggerable_manager.register(activity)
	
	# Set starting location
	if starting_location_id == null:
		starting_location_id = config.get("starting_location_id", "")
	starting_player_squad.strategic_data.set_location(starting_location_id)
	
	# triggerable_manager.triggerable_fired.connect(_on_triggerable_fired)

func _load_generic_events() -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	_collect_event_resources("res://resources/generic-events", events)
	return events

func _collect_event_resources(base_path: String, target: Array) -> void:
	var dir := DirAccess.open(base_path)
	if dir == null:
		push_warning("GameScenario: Missing event directory: %s" % base_path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				_collect_event_resources("%s/%s" % [base_path, entry], target)
		elif entry.ends_with(".tres"):
			var rp = "%s/%s" % [base_path, entry]
			var resource = load(rp)
			if resource and resource is GameEvent:
				target.append(resource)
			else:
				push_warning("GameScenario: Skipping non-GameEvent resource: %s" % rp)
		entry = dir.get_next()
	dir.list_dir_end()

func _load_generic_activities() -> Array[Activity]:
	var activities: Array[Activity] = []
	_collect_activity_resources("res://resources/generic-activities", activities)
	print(activities)
	return activities

func _collect_activity_resources(base_path: String, target: Array) -> void:
	var dir := DirAccess.open(base_path)
	if dir == null:
		push_warning("TrainingScreen: Missing activity directory: %s" % base_path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				_collect_activity_resources("%s/%s" % [base_path, entry], target)
		elif entry.ends_with(".tres"):
			var rp = "%s/%s" % [base_path, entry]
			var resource = load(rp)
			if resource and resource is Activity:
				target.append(resource)
			else:
				push_warning("GameScenario: Skipping non-Activity resource: %s" % rp)
		entry = dir.get_next()
	dir.list_dir_end()
