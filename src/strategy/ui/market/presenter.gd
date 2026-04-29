class_name MarketPresenter
extends Node

var view: Control


func _ready() -> void:
	view = get_parent() as Control


func refresh(world: World, location: Location, visited_location_ids: Array[String]) -> void:
	var goods_cards := _build_goods_cards(world, location)
	var production_names := _get_local_production(location)
	var pop_data := _build_population_data(location)
	var rumors := _build_rumors(world, location, visited_location_ids)
	view.display_market(location, goods_cards, production_names, pop_data, rumors)


func _build_goods_cards(world: World, location: Location) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	assert(location.has_economy(), "Market requested for location '%s' without economy" % location.location_id)

	var inv := location.inventory
	assert(inv != null, "Market requested for location '%s' without inventory" % location.location_id)
	var pop := location.population
	assert(pop != null, "Market requested for location '%s' without population" % location.location_id)

	for thing in world.goods:
		var stock := inv.get_available(thing)
		var price := inv.get_price(thing)
		var price_ratio := price / thing.base_price if thing.base_price > 0.0 else 1.0
		var demand := pop.get_total_demand(thing) if pop else 0.0
		var abundance_ratio := stock / (demand + 1.0)

		cards.append({
			"name": thing.get_label(),
			"stock": stock,
			"price": price,
			"price_ratio": price_ratio,
			"abundance_ratio": abundance_ratio,
		})
	return cards


func _get_local_production(location: Location) -> Array[String]:
	var names: Array[String] = []
	for resource in location.natural_resources:
		var label := resource.thing.get_label()
		if label not in names:
			names.append(label)
	return names


func _build_population_data(location: Location) -> Dictionary:
	assert(location.has_economy(), "Market population requested for location '%s' without economy" % location.location_id)
	var pop := location.population
	assert(pop != null, "Market population requested for location '%s' without population" % location.location_id)
	return {
		"total": pop.size(),
		"peasants": pop.get_by_class(EconomyTypes.SocialClass.PEASANT).size(),
		"bourgeois": pop.get_by_class(EconomyTypes.SocialClass.BOURGEOIS).size(),
		"nobles": pop.get_by_class(EconomyTypes.SocialClass.NOBLE).size(),
		"satisfaction": pop.get_average_satisfaction(),
		"avg_money": pop.get_average_money(),
	}


func _build_rumors(world: World, current_loc: Location, visited_ids: Array[String]) -> Array[String]:
	var rumors: Array[String] = []
	assert(current_loc.has_economy(), "Market rumors requested for location '%s' without economy" % current_loc.location_id)

	var diffs: Array[Dictionary] = []
	for loc_id in visited_ids:
		if loc_id == current_loc.location_id:
			continue
		var loc := world.get_location_by_id(loc_id)
		if loc == null:
			continue
		assert(loc.has_economy(), "Visited location '%s' has no economy but was used for market rumors" % loc.location_id)

		for thing in world.goods:
			var here_price := current_loc.inventory.get_price(thing)
			var there_price := loc.inventory.get_price(thing)
			var diff := absf(here_price - there_price)
			if diff < 0.2:
				continue
			var text: String
			if there_price > here_price * 1.3:
				text = "%s is dear at %s" % [thing.get_label(), loc.location_name]
			elif there_price < here_price * 0.8:
				text = "%s is plentiful in %s" % [thing.get_label(), loc.location_name]
			else:
				continue
			diffs.append({"text": text, "diff": diff})

	diffs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["diff"] > b["diff"])
	var cap := mini(diffs.size(), 3)
	for i in range(cap):
		rumors.append(diffs[i]["text"])
	return rumors
