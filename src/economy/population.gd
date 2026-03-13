extends RefCounted
class_name Population

var people: Array[EconPerson] = []

func add_person(person: EconPerson) -> void:
	people.append(person)

func get_by_class(social_class: EconomyTypes.SocialClass) -> Array[EconPerson]:
	var result: Array[EconPerson] = []
	for p in people:
		if p.social_class == social_class:
			result.append(p)
	return result

func get_by_job(job: EconomyTypes.JobType) -> Array[EconPerson]:
	var result: Array[EconPerson] = []
	for p in people:
		if p.job == job:
			result.append(p)
	return result

func get_total_demand(thing: Thing) -> float:
	var total := 0.0
	for p in people:
		total += p.wants.get(thing, 0.0)
	return total

func get_total_supply(thing: Thing) -> float:
	var total := 0.0
	for p in people:
		total += p.inventory.get(thing, 0.0)
	return total

func get_average_satisfaction() -> float:
	if people.is_empty():
		return 0.0
	var total := 0.0
	for p in people:
		total += p.satisfaction
	return total / people.size()

func get_average_money() -> float:
	if people.is_empty():
		return 0.0
	var total := 0.0
	for p in people:
		total += p.money
	return total / people.size()

func size() -> int:
	return people.size()

func sorted_by_wealth_desc() -> Array[EconPerson]:
	var sorted: Array[EconPerson] = []
	sorted.append_array(people)
	sorted.sort_custom(func(a: EconPerson, b: EconPerson) -> bool: return a.money > b.money)
	return sorted

static func create_batch(
	count: int,
	name_prefix: String,
	social_class: EconomyTypes.SocialClass,
	job: EconomyTypes.JobType,
	starting_money: float,
) -> Array[EconPerson]:
	var batch: Array[EconPerson] = []
	for i in range(count):
		var p := EconPerson.create(
			"%s_%d" % [name_prefix, i + 1],
			social_class,
			job,
			starting_money,
		)
		batch.append(p)
	return batch
