class_name SquadMapView
extends Node2D

## Primitive Systems-layer map: an authored marker scene plus one token per
## squad currently traveling — convoys and everything else alike. Pure view:
## no system references; the composition root wires the signals and injects
## the squad/distance resolvers.

const TOKEN_SCENE: PackedScene = preload("res://scenes/ui/maps/squad_token.tscn")

@export var map_scene: PackedScene

var squad_resolver: Callable ## (squad_id: String) -> StrategySquad
var distance_resolver: Callable ## (from_id: String, to_id: String) -> float

var _marker_by_id: Dictionary = {}
var _token_by_squad_id: Dictionary = {}


func _ready() -> void:
	assert(map_scene != null, "SquadMapView requires a map_scene")
	var map := map_scene.instantiate()
	add_child(map)
	for child in map.get_children():
		if child is LocationMarker:
			_marker_by_id[child.location_id] = child


func _on_squad_registered(squad: StrategySquad) -> void:
	_refresh_token(squad)


func _on_squad_unregistered(squad_id: String) -> void:
	var token: Node2D = _token_by_squad_id.get(squad_id)
	if token != null:
		token.queue_free()
		_token_by_squad_id.erase(squad_id)


func _on_travel_progress(squad_id: String, current_km: float, total_km: float, _destination_name: String) -> void:
	var squad := squad_resolver.call(squad_id) as StrategySquad
	if squad != null:
		_refresh_token(squad, current_km, total_km)


func _on_location_changed(squad_id: String, _from_id: String, _to_id: String) -> void:
	var squad := squad_resolver.call(squad_id) as StrategySquad
	if squad != null:
		_refresh_token(squad)


func _refresh_token(squad: StrategySquad, covered_km: float = -1.0, total_km: float = -1.0) -> void:
	if not squad.is_traveling():
		_on_squad_unregistered(squad.squad_id)
		return

	var token: SquadToken = _token_by_squad_id.get(squad.squad_id)
	if token == null:
		token = TOKEN_SCENE.instantiate()
		add_child(token)
		token.setup(squad)
		_token_by_squad_id[squad.squad_id] = token

	if covered_km < 0.0:
		covered_km = _route_covered_km(squad)
	if total_km < 0.0:
		total_km = _route_total_km(squad)
	token.position = _point_along_route(squad.travel_route, covered_km, total_km)


func _route_total_km(squad: StrategySquad) -> float:
	var total := 0.0
	for i in range(squad.travel_route.size() - 1):
		total += float(distance_resolver.call(squad.travel_route[i], squad.travel_route[i + 1]))
	return total


func _route_covered_km(squad: StrategySquad) -> float:
	var covered := 0.0
	for i in range(squad.travel_segment_index):
		covered += float(distance_resolver.call(squad.travel_route[i], squad.travel_route[i + 1]))
	return covered + squad.travel_progress_km


func _point_along_route(route: Array[String], covered_km: float, total_km: float) -> Vector2:
	var pts: Array[Vector2] = []
	for loc_id in route:
		var marker: LocationMarker = _marker_by_id.get(loc_id)
		if marker == null:
			return Vector2.ZERO
		pts.append(marker.position)

	var pixel_total := 0.0
	for i in range(pts.size() - 1):
		pixel_total += pts[i].distance_to(pts[i + 1])
	if pixel_total <= 0.0 or total_km <= 0.0:
		return pts[0]

	var target := pixel_total * clampf(covered_km / total_km, 0.0, 1.0)
	for i in range(pts.size() - 1):
		var seg := pts[i].distance_to(pts[i + 1])
		if target <= seg:
			return pts[i].lerp(pts[i + 1], target / seg if seg > 0.0 else 0.0)
		target -= seg
	return pts[-1]
