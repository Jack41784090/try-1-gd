extends RefCounted
class_name EconPerson

var person_id: String
var person_name: String
var social_class: EconomyTypes.SocialClass
var job: EconomyTypes.JobType
var money: float
var inventory: Dictionary = {}
var wants: Dictionary = {}
var satisfaction: float = 50.0
var income_per_turn: float = 0.0
var employer_id: String = ""
var _fed_this_turn: bool = false
var _comfort_this_turn: float = 0.0

static var _next_id: int = 0

static func _generate_id() -> String:
	_next_id += 1
	return "person_%d" % _next_id

func compute_wants(goods_list: Array[Thing]) -> void:
	wants.clear()
	for thing in goods_list:
		match thing.thing_type:
			EconomyTypes.ThingType.FOOD:
				wants[thing] = 1.0
			EconomyTypes.ThingType.CLOTH:
				match social_class:
					EconomyTypes.SocialClass.PEASANT: wants[thing] = 0.3
					EconomyTypes.SocialClass.BOURGEOIS: wants[thing] = 0.5
					EconomyTypes.SocialClass.NOBLE: wants[thing] = 1.0
			EconomyTypes.ThingType.TOOLS:
				match social_class:
					EconomyTypes.SocialClass.PEASANT: wants[thing] = 0.1
					EconomyTypes.SocialClass.BOURGEOIS: wants[thing] = 0.3
					EconomyTypes.SocialClass.NOBLE: wants[thing] = 0.3
			EconomyTypes.ThingType.LUXURY:
				if social_class == EconomyTypes.SocialClass.NOBLE:
					wants[thing] = 0.5
				elif social_class == EconomyTypes.SocialClass.BOURGEOIS:
					wants[thing] = 0.2

func get_food_in_inventory(food_thing: Thing) -> float:
	return inventory.get(food_thing, 0.0)

func consume(thing: Thing, qty: float) -> float:
	var held: float = inventory.get(thing, 0.0)
	var consumed := minf(held, qty)
	inventory[thing] = held - consumed
	return consumed

func can_afford(price: float, qty: float) -> float:
	if price <= 0.0:
		return qty
	return minf(qty, money / price)

func buy(thing: Thing, qty: float, price: float) -> float:
	var affordable := can_afford(price, qty)
	if affordable <= 0.0:
		return 0.0
	money -= affordable * price
	inventory[thing] = inventory.get(thing, 0.0) + affordable
	return affordable

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
	p.person_id = _generate_id()
	p.person_name = p_name
	p.social_class = p_class
	p.job = p_job
	p.money = p_money
	p.satisfaction = 50.0
	return p

static func create_peasant(p_name: String, p_job: EconomyTypes.JobType = EconomyTypes.JobType.FARMER) -> EconPerson:
	return create(p_name, EconomyTypes.SocialClass.PEASANT, p_job, 5.0)

static func create_bourgeois(p_name: String, p_job: EconomyTypes.JobType = EconomyTypes.JobType.MERCHANT) -> EconPerson:
	return create(p_name, EconomyTypes.SocialClass.BOURGEOIS, p_job, 50.0)

static func create_noble(p_name: String) -> EconPerson:
	return create(p_name, EconomyTypes.SocialClass.NOBLE, EconomyTypes.JobType.LANDLORD, 200.0)
