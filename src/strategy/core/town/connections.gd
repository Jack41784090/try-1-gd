class_name TownConnections
extends Resource

const start = 0
var current = 0
var end = 0
const increment = 1

@export var tt: Array[TownConnection]

func should_continue():
	return (current < end)

func _iter_init(_arg):
	end = tt.size()
	current = start
	return should_continue()

func _iter_next(_arg):
	current += increment
	return should_continue()

func _iter_get(_arg):
	return tt[current].to_location_id
