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

func find_path(from_id: String, to_id: String) -> Array:
	assert(locations.has(from_id))
	assert(locations.has(to_id));

	if from_id == to_id:
		return [from_id]
	
	var queue: Array = [[from_id]]
	var visited: Dictionary = {from_id: true}
	
	while queue.size() > 0:
		var path: Array = queue.pop_front()
		var current_pathloc_id: String = path[path.size() - 1]
		var current_pathloc = get_location(current_pathloc_id)
		assert(current_pathloc != null)
		
		for neighbor_id in current_pathloc.connected_location_ids:
			if neighbor_id == to_id:
				var final_path: Array = path.duplicate() as Array;
				final_path.append(to_id)
				return final_path
			
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				var new_path: Array = path.duplicate()
				new_path.append(neighbor_id)
				queue.append(new_path)
	
	return []

func calculate_travel_time_from(from, to) -> int:
	assert(from is String or from is Location)
	assert(to is String or to is Location)
	if from is Location:
		from = from.location_id
	if to is Location:
		to = to.location_id

	var path = find_path(from, to)
	if path.is_empty():
		return -1
	return calculate_travel_time(path)

func calculate_travel_time(path: Array) -> int:
	if path.size() <= 1:
		return 0
	
	var total_time = 0
	
	for i in range(path.size() - 1):
		assert(locations.has(path[i]))
		assert(locations.has(path[i + 1]));

		var from_location = get_location(path[i])
		var to_location = get_location(path[i + 1])
		
		# if from_location and to_location:
		var segment_time = from_location.calculate_base_travel_time(to_location)
		if segment_time < 0:
			return -1
		total_time += segment_time
	
	return total_time

func get_distance(from_id: String, to_id: String) -> int:
	var path = find_path(from_id, to_id)
	if path.is_empty():
		return -1
	return path.size() - 1
