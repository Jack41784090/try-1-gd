extends RefCounted
class_name Population

var people: Array[EconPerson] = []
var _by_class: Dictionary = {}
var _by_job: Dictionary = {}
var _sorted_dirty: bool = true
var _cached_sorted: Array[EconPerson] = []

func add_person(person: EconPerson) -> void:
	people.append(person)
	_index_person(person)
	_sorted_dirty = true

func _index_person(person: EconPerson) -> void:
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

func notify_class_changed(person: EconPerson, old_class: EconomyTypes.SocialClass, old_job: EconomyTypes.JobType) -> void:
	if _by_class.has(old_class):
		(_by_class[old_class] as Array[EconPerson]).erase(person)
	if _by_job.has(old_job):
		(_by_job[old_job] as Array[EconPerson]).erase(person)
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
	_sorted_dirty = true

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

func mark_wealth_dirty() -> void:
	_sorted_dirty = true

func sorted_by_wealth_desc() -> Array[EconPerson]:
	if _sorted_dirty:
		_cached_sorted = []
		_cached_sorted.append_array(people)
		_cached_sorted.sort_custom(func(a: EconPerson, b: EconPerson) -> bool: return a.money > b.money)
		_sorted_dirty = false
	return _cached_sorted

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
