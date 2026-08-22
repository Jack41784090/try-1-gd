extends RefCounted
class_name EconPerson

var person_name: String
var social_class: EconomyTypes.SocialClass
var job: EconomyTypes.JobType
var money: float
var inventory: Dictionary = {}
var wants: Dictionary = {}
var satisfaction: float = 50.0

func consume(thing: Thing, qty: float) -> float:
	var held: float = inventory.get(thing, 0.0)
	var consumed := minf(held, qty)
	inventory[thing] = held - consumed
	return consumed


## Direct port of CsPerson.ComputeWants (CsPerson.cs:58-129). Rebuilds `wants`
## from scratch each call — nobles want less of everything (elasticity 0.5)
## and peasants more (1.5); price above base_price suppresses want, below
## it inflates want, per good's own elasticity.
func compute_wants(goods: Array[Thing], inv: LocationInventory) -> void:
	wants.clear()
	var class_elasticity_mod := 1.0
	match social_class:
		EconomyTypes.SocialClass.NOBLE:
			class_elasticity_mod = 0.5
		EconomyTypes.SocialClass.PEASANT:
			class_elasticity_mod = 1.5

	for thing: Thing in goods:
		var base_want := _base_want_for(thing.thing_type)
		if base_want <= 0.0:
			continue
		if inv != null and thing.base_price > 0.0:
			var current_price := inv.get_price(thing)
			if current_price > 0.0:
				var modifier := pow(thing.base_price / current_price, thing.get_elasticity() * class_elasticity_mod)
				base_want *= clampf(modifier, 0.2, 3.0)
		wants[thing] = base_want


## Port of CsPerson.ComputeWants' per-ThingType base-want table (CsPerson.cs:74-113).
func _base_want_for(thing_type: EconomyTypes.ThingType) -> float:
	match thing_type:
		EconomyTypes.ThingType.FOOD:
			return 1.0
		EconomyTypes.ThingType.CLOTH:
			match social_class:
				EconomyTypes.SocialClass.PEASANT:
					return 0.3
				EconomyTypes.SocialClass.BOURGEOIS:
					return 0.5
				EconomyTypes.SocialClass.NOBLE:
					return 1.0
		EconomyTypes.ThingType.TOOLS:
			match social_class:
				EconomyTypes.SocialClass.PEASANT:
					return 0.1
				EconomyTypes.SocialClass.BOURGEOIS, EconomyTypes.SocialClass.NOBLE:
					return 0.3
		EconomyTypes.ThingType.LUXURY:
			match social_class:
				EconomyTypes.SocialClass.NOBLE:
					return 0.5
				EconomyTypes.SocialClass.BOURGEOIS:
					return 0.2
		EconomyTypes.ThingType.WEAPONS:
			match social_class:
				EconomyTypes.SocialClass.NOBLE:
					return 0.4
				EconomyTypes.SocialClass.BOURGEOIS:
					return 0.1
	return 0.0


## Nudges satisfaction toward this person's own wants-weighted fulfillment
## ratio (last hour's unmet vs. the whole population's demand for each
## thing they want) — same 0.2 smoothing idiom as _price_update's 0.15
## adjust_rate, so satisfaction doesn't jump straight to its target.
func update_satisfaction(unmet: Dictionary, population_demand: Dictionary) -> void:
	if wants.is_empty():
		return
	var weighted_fulfillment := 0.0
	var total_weight := 0.0
	for thing: Thing in wants:
		var wanted: float = wants[thing]
		if wanted <= 0.0:
			continue
		var total_demand: float = population_demand.get(thing, wanted)
		var thing_unmet: float = unmet.get(thing, 0.0)
		var fulfillment_ratio := clampf(1.0 - thing_unmet / maxf(total_demand, 0.01), 0.0, 1.0)
		weighted_fulfillment += fulfillment_ratio * wanted
		total_weight += wanted
	if total_weight <= 0.0:
		return
	var target := (weighted_fulfillment / total_weight) * 100.0
	satisfaction = lerpf(satisfaction, target, 0.2)

func _to_string() -> String:
	return "%s (%s, %s)" % [
		person_name,
		EconomyTypes.SocialClass.keys()[social_class],
		EconomyTypes.JobType.keys()[job],
	]

static func create(
	p_name: String,
	p_class: EconomyTypes.SocialClass,
	p_job: EconomyTypes.JobType,
	p_money: float = 0.0,
) -> EconPerson:
	var p := EconPerson.new()
	p.person_name = p_name
	p.social_class = p_class
	p.job = p_job
	p.money = p_money
	p.satisfaction = 50.0
	return p
