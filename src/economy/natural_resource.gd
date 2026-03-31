extends Resource
class_name NaturalResource

@export var thing: Thing
@export var base_capacity: float = 10.0
@export var worker_job: EconomyTypes.JobType = EconomyTypes.JobType.FARMER
@export var workers_needed: float = 50.0


static func create(
	p_thing: Thing,
	p_capacity: float,
	p_job: EconomyTypes.JobType = EconomyTypes.JobType.FARMER,
	p_workers: float = 50.0,
) -> NaturalResource:
	var r := NaturalResource.new()
	r.thing = p_thing
	r.base_capacity = p_capacity
	r.worker_job = p_job
	r.workers_needed = p_workers
	return r


static func create_craft(
	p_thing: Thing,
	p_capacity: float,
	p_workers: float = 20.0,
) -> NaturalResource:
	var r := NaturalResource.new()
	r.thing = p_thing
	r.base_capacity = p_capacity
	r.worker_job = EconomyTypes.JobType.CRAFTSMAN
	r.workers_needed = p_workers
	return r


func _to_string() -> String:
	return "NaturalResource(%s: %.1f/tick, %s x%.0f)" % [
		thing.thing_name, base_capacity,
		EconomyTypes.JobType.keys()[worker_job], workers_needed,
	]
