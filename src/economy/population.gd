class_name Population
extends Resource

var people: Array[EconPerson] = []
var _by_class: Dictionary[EconomyTypes.SocialClass, Array] = {}
var _by_job: Dictionary[EconomyTypes.JobType, Array] = {}

@export var last_unmet: Dictionary[Thing, float] = {}

func add_person(person: EconPerson) -> void:
	people.append(person)
	var cls := person.social_class
	if not _by_class.has(cls):
		var arr: Array[EconPerson] = []
		_by_class[cls] = arr
	(_by_class[cls] as Array[EconPerson]).append(person)
	var job := person.job
	if not _by_job.has(job):
		var arr: Array[EconPerson] = []
		_by_job[job] = arr
	(_by_job[job] as Array[EconPerson]).append(person)

func set_round_demand(goods: Array[Thing], inv: LocationInventory) -> void:
	for p: EconPerson in people:
		p.compute_wants(goods, inv)
		for thing: Thing in p.wants:
			last_unmet.set(thing, last_unmet.get(thing, 0.0) + p.wants[thing])

func update_satisfaction() -> void:
	for p: EconPerson in people:
		for thing: Thing in p.wants:
			last_unmet.set(thing, last_unmet.get(thing, 0.0) + p.wants[thing])
			# population_demand[thing] = population_demand.get(thing, 0.0) + p.wants[thing]
	for p: EconPerson in people:
		p.update_satisfaction(last_unmet, population_demand)

func get_by_class(social_class: EconomyTypes.SocialClass) -> Array[EconPerson]:
	if _by_class.has(social_class):
		return _by_class[social_class] as Array[EconPerson]
	var empty: Array[EconPerson] = []
	return empty

func get_by_job(job: EconomyTypes.JobType) -> Array[EconPerson]:
	if _by_job.has(job):
		return _by_job[job] as Array[EconPerson]
	var empty: Array[EconPerson] = []
	return empty

func get_total_demand(thing: Thing) -> float:
	var total := 0.0
	for p in people:
		total += p.wants.get(thing, 0.0)
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
