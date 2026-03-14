extends RefCounted
class_name Contract

enum ContractType {
	CONSTRUCTION,
	LUXURY_GOODS,
	MILITARY_SUPPLY,
	FOOD_SUPPLY,
}

var contract_id: String
var contract_type: ContractType
var patron: EconPerson
var location_id: String
var budget: float
var labor_needed: int
var workers_assigned: Array[EconPerson] = []
var merchant_assigned: EconPerson = null
var turns_remaining: int
var wage_per_worker: float
var merchant_fee: float
var completed: bool = false

func assign_merchant(m: EconPerson) -> void:
	merchant_assigned = m

func assign_worker(w: EconPerson) -> void:
	workers_assigned.append(w)

func is_fully_staffed() -> bool:
	return workers_assigned.size() >= labor_needed and merchant_assigned != null

func work_one_turn() -> bool:
	if not is_fully_staffed():
		return false
	turns_remaining -= 1
	if turns_remaining <= 0:
		completed = true
	return completed

func get_total_wage_cost() -> float:
	return wage_per_worker * workers_assigned.size()

func get_total_cost_per_turn() -> float:
	return get_total_wage_cost() + merchant_fee

func _to_string() -> String:
	return "Contract[%s %s by %s: budget=%.0f workers=%d/%d turns=%d]" % [
		contract_id,
		ContractType.keys()[contract_type],
		patron.person_name,
		budget,
		workers_assigned.size(),
		labor_needed,
		turns_remaining,
	]

static var _next_id: int = 0

static func create(
	p_type: ContractType,
	p_patron: EconPerson,
	p_location_id: String,
	p_budget: float,
	p_labor: int,
	p_duration: int,
	p_wage: float,
	p_merchant_fee: float,
) -> Contract:
	_next_id += 1
	var c := Contract.new()
	c.contract_id = "contract_%d" % _next_id
	c.contract_type = p_type
	c.patron = p_patron
	c.location_id = p_location_id
	c.budget = p_budget
	c.labor_needed = p_labor
	c.turns_remaining = p_duration
	c.wage_per_worker = p_wage
	c.merchant_fee = p_merchant_fee
	return c
