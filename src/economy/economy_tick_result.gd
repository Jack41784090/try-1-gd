extends RefCounted
class_name EconomyTickResult

var turn: int = 0
var deaths: int = 0
var births: int = 0
var location_snapshots: Array[LocationSnapshot] = []
var moves_created: Array[EconomyMove] = []
var moves_completed: Array[EconomyMove] = []
var shipment_dispatches: Array[ShipmentDispatch] = []
var mercenary_work_changes: Dictionary = {} ## location_id -> bool; applied onto Location.available_activity_types each tick


class ShipmentDispatch:
	var shipment_id: String
	var move: EconomyMove
	var guard_count: int


	static func create(p_id: String, p_move: EconomyMove, p_guards: int) -> ShipmentDispatch:
		var d := ShipmentDispatch.new()
		d.shipment_id = p_id
		d.move = p_move
		d.guard_count = p_guards
		return d

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
	var peasant_count: int = 0
	var bourgeois_count: int = 0
	var noble_count: int = 0
	var government_treasury: float = 0.0
	var government_tax_collected: float = 0.0
	var government_directives_count: int = 0
	var government_workers_hired: int = 0
	var guild_treasury: float = 0.0
	var guild_produced: float = 0.0
	var guild_worker_count: int = 0

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


