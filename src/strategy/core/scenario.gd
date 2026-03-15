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

	_setup_economy()

	# triggerable_manager.triggerable_fired.connect(_on_triggerable_fired)


func _setup_economy() -> void:
	if world.goods.is_empty():
		return

	var has_any_inventory := false
	for loc in world.locations:
		if loc.inventory != null:
			has_any_inventory = true
			break
	if not has_any_inventory:
		return

	var thing_map: Dictionary = {}
	for thing in world.goods:
		thing_map[thing.thing_id] = thing

	for loc in world.locations:
		if loc.inventory == null:
			continue
		loc.population = _create_population_for(loc)
		if loc.supply_rules.is_empty():
			loc.supply_rules = _create_supply_rules_for(loc, thing_map)

	var engine := EconomyEngine.new()
	engine.world = world
	engine.bank = CentralBank.new()
	engine.bank.loan_interest_rate = 0.08
	engine.bank.print_per_turn = 500.0
	engine.noble_loan_threshold = 100.0
	engine.loan_amount = 500.0
	engine.enable_csharp()
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


func _create_supply_rules_for(loc: Location, thing_map: Dictionary) -> Array[SupplyRule]:
	var rules: Array[SupplyRule] = []
	var food: Thing = thing_map.get("food")
	var cloth: Thing = thing_map.get("cloth")
	var tools: Thing = thing_map.get("tools")
	var lid := loc.location_id

	match loc.type:
		StrategyTypes.LocationType.CITY:
			if food:
				rules.append(SupplyRule.create_extract("%s_food" % lid, food, 15.0))
			if cloth:
				rules.append(SupplyRule.create_craft("%s_cloth" % lid, cloth, 8.0))
			if tools:
				rules.append(SupplyRule.create_craft("%s_tools" % lid, tools, 5.0))
			if food:
				for conn_id in _get_connected_ids(loc):
					var neighbor := world.get_location_by_id(conn_id)
					if neighbor and neighbor.type in [StrategyTypes.LocationType.TOWN, StrategyTypes.LocationType.VILLAGE]:
						rules.append(SupplyRule.create_import("%s_food_from_%s" % [lid, conn_id], food, conn_id, 20.0))

		StrategyTypes.LocationType.TOWN:
			if food:
				rules.append(SupplyRule.create_extract("%s_food" % lid, food, 20.0))
			if cloth:
				rules.append(SupplyRule.create_craft("%s_cloth" % lid, cloth, 3.0))
			for conn_id in _get_connected_ids(loc):
				var neighbor := world.get_location_by_id(conn_id)
				if neighbor and neighbor.type == StrategyTypes.LocationType.CITY:
					if tools:
						rules.append(SupplyRule.create_import("%s_tools_from_%s" % [lid, conn_id], tools, conn_id, 5.0))

		StrategyTypes.LocationType.FORT:
			for conn_id in _get_connected_ids(loc):
				if food:
					rules.append(SupplyRule.create_import("%s_food_from_%s" % [lid, conn_id], food, conn_id, 10.0))
				if cloth:
					rules.append(SupplyRule.create_import("%s_cloth_from_%s" % [lid, conn_id], cloth, conn_id, 3.0))

		StrategyTypes.LocationType.VILLAGE:
			if food:
				rules.append(SupplyRule.create_extract("%s_food" % lid, food, 15.0))

	return rules


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
	Log.debug("Scenario", "Loaded %d generic activities" % activities.size())
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
