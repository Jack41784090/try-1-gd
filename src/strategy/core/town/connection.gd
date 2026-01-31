class_name TownConnection extends Resource

@export var from_location_id: String = ""
@export var to_location_id: String = ""
@export var travel_time: int = 1

func _init(_from = null, _to = null, _tt = null) -> void:
    if _from == null or _to == null or _tt == null:
        return
    from_location_id = _from
    to_location_id = _to
    travel_time = _tt
