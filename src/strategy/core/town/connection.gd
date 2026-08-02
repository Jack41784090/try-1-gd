class_name TownConnection extends Resource

@export var from_location_id: String = ""
@export var to_location_id: String = ""
@export var distance_km: float = 10.0

func _init(_from = null, _to = null, _dist = null) -> void:
    if _from == null or _to == null or _dist == null:
        return
    from_location_id = _from
    to_location_id = _to
    distance_km = _dist
