class_name GameScenario extends Resource

var triggerable_manager: TriggerableManager

@export var starting_player_squad: SquadData
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
	Log.debug("Scenario", "init (config empty=%s)" % str(config.is_empty()))

	if config.is_empty():
		pass
	else:
		_setup(config)
		_initialized = true

func initialize(_config = {}) -> void:
	Log.debug("Scenario", "Manual initialize called")
	assert(not _initialized, "scenario->initialize must not be called when it has already initialised through other means.")
	_setup(_config)
	_initialized = true

func _setup(config: Dictionary) -> void:
	Log.debug("Scenario", "Setup with config keys: %s" % str(config.keys()))
	# Uses exported @export properties if already set (from .tres resource files), falls back to config dict
	# Registration order: factions→missions → endings → events → activities → set location
	# e.g., world has 5 locations, 2 factions with 3 missions each, 10 generic events, 8 activities
	#   → triggerable_manager gets 6 missions + 2 endings + 10 events + 8 activities = 26 triggerables
	Log.debug("Scenario", "Scenario setup: %s" % str(config))
	# 1. Initialize triggerable_manager — central registry for all game triggerables
	triggerable_manager = TriggerableManager.new()
	
	# Use exported properties if already set (from .tres), otherwise use config
	if world == null:
		world = config.get("world", World.new())
	assert(world.map_scene != null, "World requires a map_scene PackedScene to be set")
	if starting_player_squad == null:
		starting_player_squad = config.get("starting_player_squad")
		assert(starting_player_squad != null, "GameScenario requires starting_player_squad to be set")
	
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
	starting_player_squad.set_location(starting_location_id)

	_setup_economy()

	# triggerable_manager.triggerable_fired.connect(_on_triggerable_fired)


func _setup_economy() -> void:
	assert(not world.goods.is_empty(), "World requires goods array to be populated for economy")
	var has_any_inventory := false
	for loc in world.locations:
		if loc.inventory != null:
			has_any_inventory = true
			break
	assert(has_any_inventory, "World requires at least one location with an inventory for economy")

	var thing_map: Dictionary = {}
	for thing in world.goods:
		thing_map[thing.thing_id] = thing

	for loc in world.locations:
		if loc.inventory == null:
			continue
		if loc.population_config != null:
			loc.population = loc.population_config.build_population(loc.location_id)
		else:
			loc.population = _create_population_for(loc)
		if loc.natural_resources.is_empty():
			loc.natural_resources = _create_natural_resources_for(loc, thing_map)

	var engine := EconomyEngine.new()
	engine.world = world
	engine.bank = CentralBank.new()
	engine.bank.loan_interest_rate = 0.08
	engine.bank.print_per_turn = 500.0
	engine.noble_loan_threshold = 100.0
	engine.loan_amount = 500.0
	engine.enable_csharp()  # asserts on failure — godot-mono required
	world.economy_engine = engine
	Log.info("Scenario", "Economy initialized: %d locations with economy" % world.get_economy_locations().size())


func _create_population_for(loc: Location) -> Population:
	var pop := Population.new()
	var dev := loc.development
	var scale := dev / 50.0

	match loc.type:
		StrategyTypes.LocationType.CITY:
			var farmers := int(20 * scale)
			var craftsmen := int(15 * scale)
			var merchants := int(10 * scale)
			var nobles := int(3 * scale)
			var laborers := int(10 * scale)
			for p in Population.create_batch(farmers, "%s_farmer" % loc.location_id, EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 2.0):
				pop.add_person(p)
			for p in Population.create_batch(craftsmen, "%s_craftsman" % loc.location_id, EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.CRAFTSMAN, 10.0):
				pop.add_person(p)
			for p in Population.create_batch(merchants, "%s_merchant" % loc.location_id, EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 15.0):
				pop.add_person(p)
			for p in Population.create_batch(nobles, "%s_noble" % loc.location_id, EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 50.0):
				pop.add_person(p)
			for p in Population.create_batch(laborers, "%s_laborer" % loc.location_id, EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 1.0):
				pop.add_person(p)

		StrategyTypes.LocationType.TOWN:
			var farmers := int(30 * scale)
			var craftsmen := int(5 * scale)
			var merchants := int(3 * scale)
			var nobles := int(1 * scale)
			for p in Population.create_batch(farmers, "%s_farmer" % loc.location_id, EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 1.0):
				pop.add_person(p)
			for p in Population.create_batch(craftsmen, "%s_craftsman" % loc.location_id, EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.CRAFTSMAN, 5.0):
				pop.add_person(p)
			for p in Population.create_batch(merchants, "%s_merchant" % loc.location_id, EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.JobType.MERCHANT, 8.0):
				pop.add_person(p)
			for p in Population.create_batch(nobles, "%s_noble" % loc.location_id, EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 30.0):
				pop.add_person(p)

		StrategyTypes.LocationType.FORT:
			var servants := int(5 * scale)
			var laborers := int(3 * scale)
			var nobles := int(2 * scale)
			for p in Population.create_batch(servants, "%s_servant" % loc.location_id, EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.SERVANT, 0.0):
				pop.add_person(p)
			for p in Population.create_batch(laborers, "%s_laborer" % loc.location_id, EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 1.0):
				pop.add_person(p)
			for p in Population.create_batch(nobles, "%s_noble" % loc.location_id, EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 80.0):
				pop.add_person(p)

		StrategyTypes.LocationType.VILLAGE:
			var farmers := int(20 * scale)
			var nobles := maxi(1, int(0.5 * scale))
			for p in Population.create_batch(farmers, "%s_farmer" % loc.location_id, EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.FARMER, 0.5):
				pop.add_person(p)
			for p in Population.create_batch(nobles, "%s_noble" % loc.location_id, EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 20.0):
				pop.add_person(p)

		_:
			for p in Population.create_batch(5, "%s_person" % loc.location_id, EconomyTypes.SocialClass.PEASANT, EconomyTypes.JobType.LABORER, 1.0):
				pop.add_person(p)

	return pop


func _create_natural_resources_for(loc: Location, thing_map: Dictionary) -> Array[NaturalResource]:
	var resources: Array[NaturalResource] = []
	var food: Thing = thing_map.get("food")
	var wool: Thing = thing_map.get("wool")
	var iron_ore: Thing = thing_map.get("iron_ore")
	var cloth: Thing = thing_map.get("cloth")
	var tools: Thing = thing_map.get("tools")
	var luxury: Thing = thing_map.get("luxury")
	var pop_count: int = loc.population.size() if loc.population else 50
	var ps := maxf(1.0, float(pop_count) / 50.0)

	match loc.type:
		StrategyTypes.LocationType.CITY:
			if food:
				resources.append(NaturalResource.create(food, 30.0 * ps))
			if cloth:
				resources.append(NaturalResource.create_craft(cloth, 12.0 * ps))
			if tools:
				resources.append(NaturalResource.create_craft(tools, 8.0 * ps))

		StrategyTypes.LocationType.TOWN:
			if food:
				resources.append(NaturalResource.create(food, 60.0 * ps))
			if wool:
				resources.append(NaturalResource.create(wool, 20.0 * ps))
			if iron_ore:
				resources.append(NaturalResource.create(iron_ore, 10.0 * ps))
			if cloth:
				resources.append(NaturalResource.create_craft(cloth, 5.0 * ps))

		StrategyTypes.LocationType.VILLAGE:
			if food:
				resources.append(NaturalResource.create(food, 40.0 * ps))
			if wool:
				resources.append(NaturalResource.create(wool, 15.0 * ps))
			if iron_ore:
				resources.append(NaturalResource.create(iron_ore, 8.0 * ps))

		StrategyTypes.LocationType.FORT:
			pass

	return resources


func _get_connected_ids(loc: Location) -> Array[String]:
	var ids: Array[String] = []
	if loc.connections == null:
		return ids
	for conn in loc.connections.tt:
		ids.append(conn.to_location_id)
	return ids


func _load_generic_events() -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	_collect_event_resources("res://resources/generic-events", events)
	return events

func _collect_event_resources(base_path: String, target: Array) -> void:
	var dir := DirAccess.open(base_path)
	if dir == null:
		Log.warn("Scenario", "Missing event directory: %s" % base_path)
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
				Log.warn("Scenario", "Skipping non-GameEvent resource: %s" % rp)
		entry = dir.get_next()
	dir.list_dir_end()

func _load_generic_activities() -> Array[Activity]:
	var activities: Array[Activity] = []
	_collect_activity_resources("res://resources/generic-activities", activities)
	Log.debug("Scenario", "Loaded %d generic activities" % activities.size())
	return activities

func _collect_activity_resources(base_path: String, target: Array) -> void:
	var dir := DirAccess.open(base_path)
	if dir == null:
		Log.warn("Scenario", "Missing activity directory: %s" % base_path)
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
				Log.warn("Scenario", "Skipping non-Activity resource: %s" % rp)
		entry = dir.get_next()
	dir.list_dir_end()
