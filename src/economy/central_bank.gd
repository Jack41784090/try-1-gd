extends RefCounted
class_name CentralBank

var bank_id: String = "imperial_bank"
var total_printed: float = 0.0
var total_interest_collected: float = 0.0
var reserves: float = 0.0
var active_loans: Array[Loan] = []
var loan_interest_rate: float = 0.01
var print_per_turn: float = 500.0

func print_money(amount: float) -> float:
	total_printed += amount
	return amount

func issue_loan(debtor: EconPerson, amount: float) -> Loan:
	var from_reserves := minf(reserves, amount)
	var to_print := amount - from_reserves
	reserves -= from_reserves
	if to_print > 0.0:
		print_money(to_print)
	debtor.money += amount
	var loan := Loan.create(debtor, amount, loan_interest_rate)
	active_loans.append(loan)
	Log.trace("CentralBank", "Loan %.0f to %s (%.0f from reserves, %.0f printed)" % [
		amount, debtor.person_name, from_reserves, to_print,
	])
	return loan

func collect_interest_and_repayments() -> void:
	var completed: Array[Loan] = []
	for loan in active_loans:
		loan.accrue_interest()
		var can_pay := minf(loan.debtor.money * 0.2, loan.total_owed)
		can_pay = maxf(can_pay, 0.0)
		if can_pay > 0.0:
			var paid := loan.make_payment(can_pay)
			loan.debtor.money -= paid
			reserves += paid
			total_interest_collected += paid
		if loan.is_paid_off():
			completed.append(loan)
	for loan in completed:
		active_loans.erase(loan)
		Log.trace("CentralBank", "Loan %s repaid by %s" % [loan.loan_id, loan.debtor.person_name])

func get_total_outstanding() -> float:
	var total := 0.0
	for loan in active_loans:
		total += loan.total_owed
	return total

func should_issue_loan(noble: EconPerson, min_threshold: float) -> bool:
	return noble.money < min_threshold

func _to_string() -> String:
	return "CentralBank[printed=%.0f reserves=%.0f interest_collected=%.0f loans=%d outstanding=%.0f]" % [
		total_printed, reserves, total_interest_collected, active_loans.size(), get_total_outstanding(),
	]
