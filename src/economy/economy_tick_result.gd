extends RefCounted
class_name EconomyTickResult

var turn: int = 0
var location_snapshots: Array[LocationSnapshot] = []
var moves_created: Array[EconomyMove] = []
var moves_completed: Array[EconomyMove] = []

class LocationSnapshot:
	var location_id: String
	var location_name: String
	var population_count: int
	var avg_satisfaction: float
	var avg_money: float
	var stocks: Dictionary = {}
	var prices: Dictionary = {}
	var produced: Dictionary = {}
	var consumed: Dictionary = {}
	var revenue: float = 0.0

	func _to_string() -> String:
		var stock_parts: Array[String] = []
		for thing in stocks:
			stock_parts.append("%s=%.1f@%.2f" % [
				thing.thing_name,
				stocks[thing],
				prices.get(thing, 0.0),
			])
		return "%s: pop=%d sat=%.0f money=%.1f | %s" % [
			location_name,
			population_count,
			avg_satisfaction,
			avg_money,
			", ".join(stock_parts),
		]

static func create_snapshot(
	loc_id: String,
	loc_name: String,
	pop: Population,
	inv: LocationInventory,
) -> LocationSnapshot:
	var s := LocationSnapshot.new()
	s.location_id = loc_id
	s.location_name = loc_name
	s.population_count = pop.size()
	s.avg_satisfaction = pop.get_average_satisfaction()
	s.avg_money = pop.get_average_money()
	for thing in inv.stocks:
		s.stocks[thing] = inv.stocks[thing]
		s.prices[thing] = inv.get_price(thing)
	return s

func log_to_console() -> void:
	Log.info("Economy", "=== TURN %d ===" % turn)
	for snap in location_snapshots:
		Log.info("Economy", "  %s" % snap)
	if not moves_created.is_empty():
		for m in moves_created:
			Log.debug("Economy", "  [MOVE+] %s" % m)
	if not moves_completed.is_empty():
		for m in moves_completed:
			Log.debug("Economy", "  [MOVE✓] %s" % m)
