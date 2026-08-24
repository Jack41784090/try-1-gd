extends SceneTree

## Bakes MainTestScenario's procedural alpha/beta sandbox into a DebugScenario Resource so
## main.tscn (main.gd's DEBUG export) can load it without rebuilding it in code every run.
## Re-run whenever MainTestScenario's sandbox data changes:
##   godot-mono --headless --path . --script res://tools/bake_debug_scenario.gd

const OUT_PATH := "res://resources/strategy/scenarios/debug/prototype-sandbox.tres"


func _initialize() -> void:
	var debug_scenario := DebugScenario.new()
	debug_scenario.scenario = MainTestScenario.build_scenario()
	debug_scenario.squads = MainTestScenario.build_squads()
	# Both presets carry starting_location_id="camp" (authored for a different demo world, which
	# doesn't exist in this alpha/beta sandbox): place the player at Alpha explicitly, and leave
	# the bandits off the map (they're a direct-combat test target, not a roaming squad here).
	debug_scenario.location_overrides = {
		"test-player": "alpha",
		"bandit_squad_1": "",
	}

	var err := ResourceSaver.save(debug_scenario, OUT_PATH)
	if err != OK:
		printerr("Failed to save DebugScenario to %s: error %d" % [OUT_PATH, err])
		quit(1)
		return
	print("Saved %s" % OUT_PATH)
	quit(0)
