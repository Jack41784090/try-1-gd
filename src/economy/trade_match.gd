class_name TradeMatch
extends RefCounted

var supply: EconomicSupply
var demand: EconomicDemand
var quantity: float = 0.0
var route: Array[String] = []
var route_safety: float = 1.0
var score: float = 0.0


func _to_string() -> String:
	return "TradeMatch(%.1f %s: %s→%s, score=%.2f, safety=%.2f)" % [
		quantity, supply.thing.thing_name,
		supply.location_id, demand.location_id,
		score, route_safety,
	]
