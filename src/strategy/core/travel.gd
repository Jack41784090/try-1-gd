class_name TravelGraph extends RefCounted

var locations: Dictionary = {}

func add_location(location: Location) -> void:
	locations[location.location_id] = location

func get_location(location_id: String) -> Location:
	return locations.get(location_id)

func is_adjacent(from_id: String, to_id: String) -> bool:
	var location = get_location(from_id)
	if not location:
		return false
	return location.is_connected_to(to_id)

func find_path(from_id: String, to_id: String) -> Array[String]:
	assert(locations.has(from_id))
	assert(locations.has(to_id))

	if from_id == to_id:
		return [from_id]
	
	# A* data structures
	var open_set: Array = [from_id]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from_id: 0}
	var f_score: Dictionary = {from_id: _heuristic(from_id, to_id)}
	
	while open_set.size() > 0:
		# Find node in open_set with lowest f_score
		var current = _get_lowest_f_score_node(open_set, f_score)
		
		if current == to_id:
			return _reconstruct_path(came_from, current)
		
		open_set.erase(current)
		var current_location = get_location(current)
		assert(current_location != null)
		
		# Check all neighbors
		for connection in current_location.connections.tt:
			var neighbor_id = connection.to_location_id
			var tentative_g_score = g_score[current] + connection.distance_km
			
			if not g_score.has(neighbor_id) or tentative_g_score < g_score[neighbor_id]:
				came_from[neighbor_id] = current
				g_score[neighbor_id] = tentative_g_score
				f_score[neighbor_id] = tentative_g_score + _heuristic(neighbor_id, to_id)
				
				if neighbor_id not in open_set:
					open_set.append(neighbor_id)
	
	return []

func _heuristic(from_id: String, to_id: String) -> int:
	# Simple heuristic: assume minimum travel time of 1 per connection
	# In future could use euclidean distance if locations had coordinates
	return 0

func _get_lowest_f_score_node(open_set: Array, f_score: Dictionary) -> String:
	var lowest_node = open_set[0]
	var lowest_score = f_score.get(lowest_node, INF)
	
	for node in open_set:
		var score = f_score.get(node, INF)
		if score < lowest_score:
			lowest_score = score
			lowest_node = node
	
	return lowest_node

func _reconstruct_path(came_from: Dictionary, current: String) -> Array[String]:
	var total_path: Array[String] = [current]
	while came_from.has(current):
		current = came_from[current]
		total_path.insert(0, current)
	return total_path

func calculate_distance_km_between(from, to) -> float:
	assert(from is String or from is Location)
	assert(to is String or to is Location)
	
	if from is Location:
		from = from.location_id
	if to is Location:
		to = to.location_id

	var path = find_path(from, to)
	if path.is_empty():
		return -1.0
	return get_path_distance_km(path)

func get_path_distance_km(path: Array) -> float:
	if path.size() <= 1:
		return 0.0
	
	var total_km := 0.0
	
	for i in range(path.size() - 1):
		assert(locations.has(path[i]))
		assert(locations.has(path[i + 1]))

		var from_location = get_location(path[i])
		var to_location = get_location(path[i + 1])
		
		var dist := from_location.get_distance_km(to_location)
		if dist < 0.0:
			return -1.0
		total_km += dist
	
	return total_km

func calculate_travel_hours(path: Array, speed_kmh: float) -> float:
	if path.size() <= 1:
		return 0.0
	
	var total_hours := 0.0
	
	for i in range(path.size() - 1):
		assert(locations.has(path[i]))
		assert(locations.has(path[i + 1]))

		var from_location = get_location(path[i])
		var to_location = get_location(path[i + 1])
		
		var segment_hours := from_location.get_travel_hours(to_location, speed_kmh)
		if segment_hours < 0.0:
			return -1.0
		total_hours += segment_hours
	
	return total_hours

func get_distance(from_id: String, to_id: String) -> float:
	var path = find_path(from_id, to_id)
	if path.is_empty():
		return -1.0
	return get_path_distance_km(path)
