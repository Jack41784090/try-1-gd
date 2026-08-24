class_name EntityRoot
extends Node2D

@onready var map: Node2D = $Map

var loc_vis_scene: PackedScene = preload("res://scenes/location.tscn")
var loc_vis_cache: Dictionary[String, Node2D] = {}

func load_vs_cache(loc_dict: Dictionary[StringName, Location]):
	var loc_arr = loc_dict.values()
	var main_loc: Location = loc_arr.pop_front()
	while main_loc != null:
		if not loc_vis_cache.has(main_loc.location_id):
			loc_vis_cache[main_loc.location_id] = loc_vis_scene.instantiate()
		
		for __loc: TownConnection in main_loc.connections:
			var loc_neigh_id = __loc.to_location_id
			if not loc_vis_cache.has(loc_neigh_id):
				var neigh_loc: Location = loc_dict[loc_neigh_id]
				loc_vis_cache[neigh_loc.location_id] = loc_vis_scene.instantiate()
		main_loc = loc_arr.pop_front()


# func _shipment_dispatched(move: EconomyMove, __: int) -> void:
#     var source = loc_vis_cache.get(move.source_location_id, null)
#     var dest = loc_vis_cache.get(move.dest_location_id, null)
#     if source is Node2D and dest is Node2D:
#         var source_loc = source as Node2D
#         var dest_loc = dest as Node2D
#         # animate a caravan going from source_loc to dest_loc
#         pass
