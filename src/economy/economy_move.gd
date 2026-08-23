class_name EconomyMove
extends RefCounted

## Dispatch record for goods moving between locations. No timer of its own —
## the convoy is a real StrategySquad and arrival is detected through travel,
## so this record only names what is being moved and tracks its lifecycle.

var thing: Thing
var quantity: float
var source_location_id: String
var dest_location_id: String
var state: EconomyTypes.MoveState = EconomyTypes.MoveState.PLANNED
var squad: StrategySquad = null

func _to_string() -> String:
	return "%s→%s: %.1f %s (%s)" % [
		source_location_id,
		dest_location_id,
		quantity,
		thing.thing_name,
		EconomyTypes.MoveState.keys()[state],
	]

static func create(
	p_thing: Thing,
	qty: float,
	from_id: String,
	to_id: String,
) -> EconomyMove:
	var m := EconomyMove.new()
	m.thing = p_thing
	m.quantity = qty
	m.source_location_id = from_id
	m.dest_location_id = to_id
	m.state = EconomyTypes.MoveState.IN_TRANSIT
	return m
