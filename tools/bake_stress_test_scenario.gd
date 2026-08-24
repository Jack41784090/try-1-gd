extends SceneTree

## Bakes StressTestScenario's 30-location trade network into a DebugScenario Resource so it can
## be swapped into main.tscn's DEBUG-only `debug_scenario` export in place of the small prototype
## sandbox. Re-run whenever StressTestScenario's network data changes:
##   godot-mono --headless --path . --script res://tools/bake_stress_test_scenario.gd

const OUT_PATH := "res://resources/strategy/scenarios/debug/stress-test-trade.tres"


func _initialize() -> void:
	var debug_scenario := DebugScenario.new()
	debug_scenario.scenario = StressTestScenario.build_scenario()
	debug_scenario.squads = StressTestScenario.build_squads()
	# test-player-squad-full.tres carries starting_location_id="camp" (authored for a different
	# demo world, which doesn't exist in this network) — place it at loc00 explicitly.
	debug_scenario.location_overrides = {
		"test-player": "loc00",
	}

	var err := ResourceSaver.save(debug_scenario, OUT_PATH)
	if err != OK:
		printerr("Failed to save DebugScenario to %s: error %d" % [OUT_PATH, err])
		quit(1)
		return
	print("Saved %s" % OUT_PATH)
	quit(0)
