extends RefCounted
class_name TravelGraph

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
				var final_path: Array= path.duplicate() as Array;
				final_path.append(to_id)
				return final_path
			
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				var new_path: Array = path.duplicate()
				new_path.append(neighbor_id)
				queue.append(new_path)
	
	return []

func calculate_path_travel_time(path: Array) -> int:
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

func get_all_reachable_locations(from_id: String, max_hops: int = -1) -> Array[String]:
	if not locations.has(from_id):
		return []
	
	var reachable: Array[String] = []
	var visited: Dictionary = {from_id: true}
	var queue: Array = [[from_id, 0]]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_id: String = current[0]
		var current_depth: int = current[1]
		
		if current_id != from_id:
			reachable.append(current_id)
		
		if max_hops >= 0 and current_depth >= max_hops:
			continue
		
		var current_location = get_location(current_id)
		if not current_location:
			continue
		
		for neighbor_id in current_location.connected_location_ids:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append([neighbor_id, current_depth + 1])
	
	return reachable
