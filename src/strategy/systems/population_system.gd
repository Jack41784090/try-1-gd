class_name PopulationSystem
extends Node

## Must connect to ClockSystem.hour_changed BEFORE LocationEconomySystem so _generate_intents() reads this hour's freshly recomputed wants, not last hour's.

var locations: Array[Location] = []
var _goods: Array[Thing] = []
var _last_unmet_by_location: Dictionary = {}   # location_id -> Dictionary[Thing, float]


func setup(world: World) -> void:
	locations = world.locations
	_goods = world.goods


func _on_trade_offer(location_id: String, _surplus: Dictionary, unmet: Dictionary) -> void:
	_last_unmet_by_location[location_id] = unmet


func _on_hour_changed(_hour: int) -> void:
	for loc in locations:
		if loc.population == null or loc.population.people.is_empty():
			continue
		_update_location_population(loc)


func _update_location_population(loc: Location) -> void:
	var people := loc.population.people

	for p: EconPerson in people:
		p.compute_wants(_goods, loc.inventory)

	var population_demand: Dictionary = {}
	for p: EconPerson in people:
		for thing: Thing in p.wants:
			population_demand[thing] = population_demand.get(thing, 0.0) + p.wants[thing]

	var last_unmet: Dictionary = _last_unmet_by_location.get(loc.location_id, {})
	for p: EconPerson in people:
		p.update_satisfaction(last_unmet, population_demand)
