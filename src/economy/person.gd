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
