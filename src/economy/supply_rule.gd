extends Resource
class_name SupplyRule

@export var rule_id: String = ""
@export var thing: Thing
@export var action: EconomyTypes.RuleAction = EconomyTypes.RuleAction.EXTRACT
@export var source_location_id: String = ""
@export var capacity_per_turn: float = 10.0
@export var priority: int = 0
var worker_job: EconomyTypes.JobType = EconomyTypes.JobType.FARMER
var workers_per_full_output: float = 50.0

func execute(inventory: LocationInventory, population: Population) -> float:
	match action:
		EconomyTypes.RuleAction.EXTRACT:
			return _execute_extract(inventory, population)
		EconomyTypes.RuleAction.PRODUCE:
			return _execute_produce(inventory)
		EconomyTypes.RuleAction.IMPORT:
			return 0.0
	return 0.0

func _execute_extract(inventory: LocationInventory, population: Population) -> float:
	var workers := population.get_by_job(worker_job)
	var worker_count := workers.size()
	if worker_count == 0:
		return 0.0
	var worker_ratio := minf(float(worker_count) / workers_per_full_output, 1.0)
	var produced := capacity_per_turn * worker_ratio
	inventory.add(thing, produced)
	return produced

func _execute_produce(inventory: LocationInventory) -> float:
	inventory.add(thing, capacity_per_turn)
	return capacity_per_turn

func create_import_move(
	dest_location_id: String,
	qty: float,
	travel_turns: int = 1,
) -> EconomyMove:
	assert(action == EconomyTypes.RuleAction.IMPORT)
	var actual_qty := minf(qty, capacity_per_turn)
	return EconomyMove.create(
		thing,
		actual_qty,
		source_location_id,
		dest_location_id,
		travel_turns,
		"rule:%s" % rule_id,
	)

static func create_extract(
	id: String,
	p_thing: Thing,
	capacity: float,
	p_priority: int = 0,
) -> SupplyRule:
	var r := SupplyRule.new()
	r.rule_id = id
	r.thing = p_thing
	r.action = EconomyTypes.RuleAction.EXTRACT
	r.capacity_per_turn = capacity
	r.priority = p_priority
	return r

static func create_craft(
	id: String,
	p_thing: Thing,
	capacity: float,
	p_priority: int = 0,
) -> SupplyRule:
	var r := SupplyRule.new()
	r.rule_id = id
	r.thing = p_thing
	r.action = EconomyTypes.RuleAction.EXTRACT
	r.worker_job = EconomyTypes.JobType.CRAFTSMAN
	r.workers_per_full_output = 20.0
	r.capacity_per_turn = capacity
	r.priority = p_priority
	return r

static func create_import(
	id: String,
	p_thing: Thing,
	from_location_id: String,
	capacity: float,
	p_priority: int = 0,
) -> SupplyRule:
	var r := SupplyRule.new()
	r.rule_id = id
	r.thing = p_thing
	r.action = EconomyTypes.RuleAction.IMPORT
	r.source_location_id = from_location_id
	r.capacity_per_turn = capacity
	r.priority = p_priority
	return r
