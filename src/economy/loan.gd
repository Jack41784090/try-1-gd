extends RefCounted
class_name Loan

var loan_id: String
var debtor: EconPerson
var principal: float
var interest_rate: float
var total_owed: float
var total_repaid: float = 0.0
var turns_active: int = 0

func get_interest_due() -> float:
	return total_owed * interest_rate

func make_payment(amount: float) -> float:
	var payment := minf(amount, total_owed)
	total_owed -= payment
	total_repaid += payment
	return payment

func accrue_interest() -> void:
	var interest := get_interest_due()
	total_owed += interest
	turns_active += 1

func is_paid_off() -> bool:
	return total_owed <= 0.01

func _to_string() -> String:
	return "Loan[%s→%s: owed=%.1f rate=%.0f%% age=%d]" % [
		loan_id, debtor.person_name, total_owed, interest_rate * 100.0, turns_active,
	]

static var _next_id: int = 0

static func create(
	p_debtor: EconPerson,
	p_principal: float,
	p_interest_rate: float,
) -> Loan:
	_next_id += 1
	var l := Loan.new()
	l.loan_id = "loan_%d" % _next_id
	l.debtor = p_debtor
	l.principal = p_principal
	l.interest_rate = p_interest_rate
	l.total_owed = p_principal
	return l
