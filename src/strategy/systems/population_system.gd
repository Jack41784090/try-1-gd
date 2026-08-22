class_name PopulationSystem
extends Node

## Owns the hourly recompute of every Location's Population — wants and
## satisfaction, per individual. Holds Array[Location] directly (like
## LocationEconomySystem), since population is long-lived per-location
## state, not a transient event; mutates loc.population in place.
##
## Connected to ClockSystem.hour_changed BEFORE LocationEconomySystem by the
## composition root, so LocationEconomySystem._generate_intents() reads
## this hour's freshly recomputed wants, not last hour's. Never references
## LocationEconomySystem directly — caches its trade_offer broadcast via
## _on_trade_offer, same pattern TradeSystem/CaravanEconomySystem use.

var locations: Array[Location] = []
var _goods: Array[Thing] = []
var _last_unmet_by_location: Dictionary = {}   # location_id -> Dictionary[Thing, float]


func setup(world: World) -> void:
	locations = world.locations
	_goods = world.goods


## Connected to LocationEconomySystem.trade_offer by the composition root.
func _on_trade_offer(location_id: String, _surplus: Dictionary, unmet: Dictionary) -> void:
	_last_unmet_by_location[location_id] = unmet


## Connected to ClockSystem.hour_changed by the composition root.
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
