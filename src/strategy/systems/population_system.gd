class_name PopulationSystem
extends Node

## Must connect to ClockSystem.hour_changed BEFORE LocationEconomySystem so _generate_intents() reads this hour's freshly recomputed wants, not last hour's.

@export var locations: Array[Location] = []
@export var goods: Array[Thing] = []
var _last_unmet_by_location: Dictionary = {}   # location_id -> Dictionary[Thing, float]


func setup(world: World) -> void:
	locations = world.locations
	goods = world.goods


#region On Events
func _on_trade_offer(location_id: String, _surplus: Dictionary, unmet: Dictionary) -> void:
	_last_unmet_by_location[location_id] = unmet


func _on_hour_changed(_hour: int) -> void:
	for loc in locations:
		if loc.population and not loc.population.people.is_empty():
			# var people := loc.population.people
			var population := loc.population

			# 
			# var population_demand: Dictionary = {}
			# for p: EconPerson in people:
			# 	p.compute_wants(goods, loc.inventory)
			# 	for thing: Thing in p.wants:
			# 		population_demand[thing] = population_demand.get(thing, 0.0) + p.wants[thing]
			population.set_round_demand(goods, loc.inventory)

			# var last_unmet: Dictionary = _last_unmet_by_location.get(loc.location_id, {})
			# for p: EconPerson in people:
			# 	p.update_satisfaction(last_unmet, population_demand)
			
	_last_unmet_by_location.clear()
#endregion