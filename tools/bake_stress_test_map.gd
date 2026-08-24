extends SceneTree

## Bakes a LocationMarker layout for StressTestScenario's network into a map scene SquadMapView
## can render: locations placed on a circle in ring order (so the ring topology reads as the
## circle boundary and chords cut across it as visible diagonal roads), same source data as
## tools/bake_stress_test_scenario.gd. Re-run after StressTestScenario's network data changes:
##   godot-mono --headless --path . --script res://tools/bake_stress_test_map.gd

const OUT_PATH := "res://scenes/ui/maps/stress_test_map.tscn"
const MARKER_SCENE: PackedScene = preload("res://scenes/ui/maps/location_marker.tscn")
const CENTER := Vector2(960.0, 540.0)
const RADIUS := 400.0


func _initialize() -> void:
	var world := StressTestScenario.build_world()
	var locations: Array[Location] = world.locations
	var n := locations.size()

	var root := Node2D.new()
	root.name = "StressTestMap"

	var positions: Dictionary = {}   # location_id -> Vector2
	for i in range(n):
		var angle := TAU * float(i) / float(n)
		positions[locations[i].location_id] = CENTER + Vector2(cos(angle), sin(angle)) * RADIUS

	# Roads first so markers draw on top of them.
	var drawn: Dictionary = {}   # unordered "a|b" pair -> true, dedupes each bidirectional connection
	for loc in locations:
		for conn: TownConnection in loc.connections.tt:
			var a := loc.location_id
			var b := conn.to_location_id
			var key := "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
			if drawn.has(key):
				continue
			drawn[key] = true
			var line := Line2D.new()
			line.name = "Road_%s" % key.replace("|", "_")
			line.points = PackedVector2Array([positions[a], positions[b]])
			line.width = 2.0
			line.default_color = Color(0.55, 0.45, 0.3, 0.3)
			root.add_child(line)
			line.owner = root

	for loc in locations:
		var marker: Area2D = MARKER_SCENE.instantiate()
		marker.name = loc.location_id.capitalize()
		marker.position = positions[loc.location_id]
		marker.location_id = loc.location_id
		marker.location_type = loc.type
		root.add_child(marker)
		marker.owner = root
		for child in marker.get_children():
			child.owner = root

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		printerr("pack() failed: %d" % err)
		quit(1)
		return

	err = ResourceSaver.save(packed, OUT_PATH)
	if err != OK:
		printerr("Failed to save map scene to %s: error %d" % [OUT_PATH, err])
		quit(1)
		return
	print("Saved %s (%d locations, %d road segments)" % [OUT_PATH, n, drawn.size()])
	quit(0)
