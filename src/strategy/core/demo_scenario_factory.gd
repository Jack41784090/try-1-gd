extends RefCounted
class_name DemoScenarioFactory

## Factory for creating demo/test GameScenario instances
## Extracts demo scenario creation logic from TrainingGUI

static var DEFAULT_DEMO_VALUES: Dictionary = {
	"city": {
		"location_id": "test_city",
		"location_name": "Ravenna",
		"development": 75,
		"stability": 85.0
	},
	"village": {
		"location_id": "test_village",
		"location_name": "Countryside",
		"development": 30,
		"stability": 60.0
	},
	"squad": {
		"squad_id": "player_squad",
		"squad_name": "The Condors",
		"money": 150.0,
		"food": 20,
		"travel_tools": 8,
		"karma": 10.0,
		"starting_location_id": "test_city"
	},
	"world": {
		"turn_count": 0,
		"end_progression": 0.0
	}
}

static func create_demo_scenario(demo_values: Dictionary = {}) -> GameScenario:
	var values = DEFAULT_DEMO_VALUES.duplicate(true)
	values.merge(demo_values, true)
	
	var world = _create_demo_world(values)
	var starting_location_id = values["city"]["location_id"]
	var squad = _create_demo_squad(values)
	var config = _create_scenario_config(world, squad, starting_location_id, [], [])
	
	var scenario = GameScenario.new(config)
	print("Demo scenario initialized: %s in %s" % [squad.squad_name, world.travel_graph.get_location(starting_location_id).location_name])
	return scenario

static func _create_demo_world(demo_values: Dictionary) -> World:
	var world_values = demo_values["world"]
	var locations = _create_demo_locations(demo_values)
	return _create_world(world_values["turn_count"], world_values["end_progression"], locations)

static func _create_demo_locations(demo_values: Dictionary) -> Array[Location]:
	var city_values = demo_values["city"]
	var village_values = demo_values["village"]
	
	var location_configs: Array[Dictionary] = [
		{
			"location_id": city_values["location_id"],
			"location_name": city_values["location_name"],
			"type": StrategyTypes.LocationType.CITY,
			"development": city_values["development"],
			"stability": city_values["stability"],
			"activity_types": [
				StrategyTypes.ActivityType.REST,
				StrategyTypes.ActivityType.DRILL,
				StrategyTypes.ActivityType.PATROL,
				StrategyTypes.ActivityType.INVESTIGATE,
				StrategyTypes.ActivityType.HOLD_MASS
			]
		},
		{
			"location_id": village_values["location_id"],
			"location_name": village_values["location_name"],
			"type": StrategyTypes.LocationType.VILLAGE,
			"development": village_values["development"],
			"stability": village_values["stability"],
			"activity_types": [
				StrategyTypes.ActivityType.REST,
				StrategyTypes.ActivityType.DRILL,
				StrategyTypes.ActivityType.HOLD_MASS
			]
		}
	]
	
	var connections: Array[Array] = [
		[city_values["location_id"], village_values["location_id"]],
		[village_values["location_id"], city_values["location_id"]]
	]

	var locations = _create_locations_with_connections(location_configs, connections)

	for location in locations:
		if location.location_id == city_values["location_id"]:
			location.shop = _create_demo_shop()
			break

	return locations

static func _create_demo_squad(demo_values: Dictionary) -> SquadStrategicData:
	var squad_values = demo_values["squad"]
	return _create_squad(
		squad_values["squad_id"],
		squad_values["squad_name"],
		squad_values["money"],
		squad_values["food"],
		squad_values["travel_tools"],
		squad_values["karma"],
		squad_values["starting_location_id"]
	)

static func _create_demo_shop() -> Shop:
	var supply_thing := Thing.create("food", "Supply", EconomyTypes.ThingType.FOOD, 5.0, "Replenish food stores")

	var shop = Shop.new()
	shop.shop_name = "Ravenna Market"
	shop.items.append(supply_thing)
	return shop

static func _create_location(location_id: String, location_name: String, location_type: StrategyTypes.LocationType, development: int, stability: float, activity_types: Array) -> Location:
	var location = Location.new()
	location.location_id = location_id
	location.location_name = location_name
	location.type = location_type
	location.development = development
	location.stability = stability
	for activity_type in activity_types:
		location.add_activity_type(activity_type)
	return location

static func _create_locations_with_connections(location_configs: Array[Dictionary], connections: Array[Array]) -> Array[Location]:
	var locations: Array[Location] = []
	for config in location_configs:
		var location = _create_location(
			config.get("location_id", ""),
			config.get("location_name", ""),
			config.get("type", StrategyTypes.LocationType.CITY),
			config.get("development", 0),
			config.get("stability", 0.0),
			config.get("activity_types", [])
		)
		locations.append(location)
	
	for connection in connections:
		if connection.size() >= 2:
			var from_id: String = connection[0]
			var to_id: String = connection[1]
			var from_location = locations.filter(func(loc): return loc.location_id == from_id)
			var to_location = locations.filter(func(loc): return loc.location_id == to_id)
			if from_location.size() > 0 and to_location.size() > 0:
				from_location[0].add_connection(to_id, 1)
	return locations

static func _create_world(turn_count: int, end_progression: float, locations: Array[Location]) -> World:
	var world = World.new()
	world.turn_count = turn_count
	world.end_progression = end_progression

	for location in locations:
		world.add_location(location)
	world.build_travel_graph()
	world.map_scene = load("res://scenes/ui/maps/demo_map.tscn")
	assert(world.map_scene != null, "Demo map scene not found at res://scenes/ui/maps/demo_map.tscn")

	var food := Thing.create("food", "Provisions", EconomyTypes.ThingType.FOOD, 5.0)
	var cloth := Thing.create("cloth", "Cloth", EconomyTypes.ThingType.CLOTH, 8.0)
	var tools := Thing.create("tools", "Tools", EconomyTypes.ThingType.TOOLS, 12.0)
	world.goods.append(food)
	world.goods.append(cloth)
	world.goods.append(tools)
	for location in locations:
		var inv := LocationInventory.new()
		var food_amount := 30.0 if location.type == StrategyTypes.LocationType.CITY else 15.0
		inv.init_thing(food, food_amount)
		inv.init_thing(cloth, 5.0)
		location.inventory = inv

	return world

static func _create_warriors() -> Array[Warrior]:
	var warriors: Array[Warrior] = []
	var names = ["Marcus", "Giovanni", "Alessandro", "Francesco", "Lorenzo"]
	var religions = [
		StrategyTypes.Religion.CATHOLIC,
		StrategyTypes.Religion.CATHOLIC,
		StrategyTypes.Religion.PROTESTANT,
		StrategyTypes.Religion.CATHOLIC,
		StrategyTypes.Religion.MUSLIM
	]
	
	for i in range(5):
		var warrior = Warrior.new()
		warrior.id = "warrior_%d" % i
		warrior.name = names[i]
		warrior.morale = randf_range(70.0, 100.0)
		warrior.religion = religions[i]
		
		warrior.combat_stats = EntityBaseStats.new()
		warrior.combat_stats.strength = randi_range(5, 10)
		warrior.combat_stats.dex = randi_range(5, 10)
		warrior.combat_stats.endurance = randi_range(5, 10)
		
		warrior.set_attribute(StrategyTypes.WarriorAttribute.PERCEPTION, randi_range(30, 70))
		warrior.set_attribute(StrategyTypes.WarriorAttribute.LEADERSHIP, randi_range(20, 60))
		warrior.logic_type = "frontline" if i < 3 else "archer"
		
		warriors.append(warrior)
	return warriors

static func _create_squad(squad_id: String, squad_name: String, money: float, food: int, travel_tools: int, karma: float, starting_location_id: String) -> SquadStrategicData:
	var squad = SquadStrategicData.new()
	squad.squad_id = squad_id
	squad.squad_name = squad_name
	squad.money = money
	squad.food = food
	squad.travel_tools = travel_tools
	squad.karma = karma
	squad.set_location(starting_location_id)
	
	var warriors = _create_warriors()
	for warrior in warriors:
		squad.add_warrior(warrior)
	
	# squad.update_aggregate_morale()
	
	return squad

static func _create_scenario_config(world: World, squad: SquadStrategicData, starting_location_id: String, events: Array[GameEvent], activities: Array[Activity]) -> Dictionary:
	var wrapped_squad := Squad.new()
	wrapped_squad.strategic_data = squad
	return {
		"world": world,
		"starting_player_squad": wrapped_squad,
		"starting_location_id": starting_location_id,
		"factions": [],
		"events": events,
		"activities": activities,
		"endings": []
	}
