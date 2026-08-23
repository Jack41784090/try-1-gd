class_name TownConnection
extends Resource

@export var from_location_id: String = ""
@export var to_location_id: String = ""
@export var distance_km: float = 10.0

func _init(_from, _to, _dist) -> void:
    from_location_id = _from
    to_location_id = _to
    distance_km = _dist
