extends RefCounted
class_name Population

var people: Array[EconPerson] = []
var _by_class: Dictionary = {}
var _by_job: Dictionary = {}

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
