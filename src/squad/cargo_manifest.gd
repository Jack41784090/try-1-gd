class_name CargoManifest
extends RefCounted

var manifest: Dictionary = {}
var destination_id: String = ""
var shipment_id: String = ""


func is_empty() -> bool:
	for item_type in manifest:
		if manifest[item_type] > 0.0:
			return true
	return false


func get_total_value() -> float:
	var total := 0.0
	for item_type in manifest:
		total += manifest[item_type]
	return total


func has_reached(current_location_id: String) -> bool:
	return not destination_id.is_empty() and current_location_id == destination_id
