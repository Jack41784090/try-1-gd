extends RefCounted
class_name EconomyMove

var thing: Thing
var quantity: float
var source_location_id: String
var dest_location_id: String
var state: EconomyTypes.MoveState = EconomyTypes.MoveState.PLANNED
var turns_remaining: int = 1
var origin: String = ""

func advance() -> bool:
	if state != EconomyTypes.MoveState.IN_TRANSIT:
		return false
	turns_remaining -= 1
	if turns_remaining <= 0:
		state = EconomyTypes.MoveState.COMPLETED
		return true
	return false

func start() -> void:
	state = EconomyTypes.MoveState.IN_TRANSIT

func cancel() -> void:
	state = EconomyTypes.MoveState.CANCELLED

func is_active() -> bool:
	return state == EconomyTypes.MoveState.IN_TRANSIT or state == EconomyTypes.MoveState.PLANNED

func _to_string() -> String:
	return "%s→%s: %.1f %s (%s, %d turns)" % [
		source_location_id,
		dest_location_id,
		quantity,
		thing.thing_name,
		EconomyTypes.MoveState.keys()[state],
		turns_remaining,
	]

static func create(
	p_thing: Thing,
	qty: float,
	from_id: String,
	to_id: String,
	travel_turns: int = 1,
	p_origin: String = "",
) -> EconomyMove:
	var m := EconomyMove.new()
	m.thing = p_thing
	m.quantity = qty
	m.source_location_id = from_id
	m.dest_location_id = to_id
	m.turns_remaining = travel_turns
	m.origin = p_origin
	m.state = EconomyTypes.MoveState.IN_TRANSIT
	return m
