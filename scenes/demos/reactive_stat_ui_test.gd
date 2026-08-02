extends Node

## Regression test for ReactiveStat -> units_panel/unit_item UI wiring.
## Promoted from the src/test_reactive_stat.gd prototype harness onto the real
## production UnitsFloatingPanel/UnitItem + StrategySquad/Character/StrategyEntity
## stack, to confirm the `changed`-signal reactivity survives the promotion.

const UNITS_PANEL_SCENE := preload("res://scenes/ui/manage_squad/units_panel.tscn")

var test_count := 0
var passed_count := 0
var failed_count := 0

var panel: UnitsFloatingPanel
var squad: StrategySquad
var warrior: Character
var item: UnitItem
var morale_bar


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("REACTIVE STAT UI — UNIT PANEL TEST SUITE")
	print("=".repeat(70) + "\n")

	_setup_scene()
	test_key_resolution()
	test_initial_render()
	test_direct_stat_mutation_updates_ui()
	test_external_driver_mutation_updates_ui()

	print("\n" + "=".repeat(70))
	print("TEST RESULTS: %d passed, %d failed, %d total" % [passed_count, failed_count, test_count])
	if failed_count == 0:
		print("✓ ALL TESTS PASSED!")
	else:
		print("✗ SOME TESTS FAILED!")
	print("=".repeat(70) + "\n")

	get_tree().quit(0 if failed_count == 0 else 1)


#region Helpers

func check(condition: bool, test_name: String, detail: String = "") -> void:
	test_count += 1
	if condition:
		passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_count += 1
		var msg := "  [FAIL] %s" % test_name
		if detail != "":
			msg += ": %s" % detail
		print(msg)


func _make_warrior(display_name: String, morale: float = 1.0) -> Character:
	var res := StrategyEntityResource.new()
	res.name = display_name

	var morale_stat := ReactiveStat.new()
	morale_stat.stat_name = StatName.I.MORALE
	morale_stat.stat_value = morale
	var speed_stat := ReactiveStat.new()
	speed_stat.stat_name = StatName.I.MV_SPD
	speed_stat.stat_value = 5.0
	res.rs_array = [morale_stat, speed_stat]

	return Character.new(StrategyEntity.new(res))


func _setup_scene() -> void:
	squad = StrategySquad.new()
	warrior = _make_warrior("Test Warrior", 1.0)
	squad.add_warrior(warrior)
	for i in range(4):
		squad.add_warrior(_make_warrior("Filler %d" % i, 0.5))

	## Mirrors real usage: instance the panel scene, add to tree, then hand it a
	## squad — same sequence units_panel.gd relies on for @onready + setup() split.
	panel = UNITS_PANEL_SCENE.instantiate()
	add_child(panel)
	panel.setup(squad)

	check(panel._item_windows.size() == 5, "Panel builds one unit_item per warrior", "got %d" % panel._item_windows.size())
	item = panel._item_windows[0] as UnitItem
	morale_bar = item.morale_bar

#endregion


func test_key_resolution() -> void:
	print("\n--- Test 1: ReactiveStat key resolution through Character → StrategyEntity ---")
	var stat := warrior.get_stat(StatName.I.MORALE)
	check(stat != null, "get_stat(MORALE) resolves to a ReactiveStat")
	if stat:
		check(stat.stat_value == 1.0, "Initial morale stat_value is 1.0", "got %s" % str(stat.stat_value))


func test_initial_render() -> void:
	print("\n--- Test 2: Initial panel render reflects entity state ---")
	check(is_equal_approx(morale_bar.value, 100.0), "MoraleBar reads initial stat_value on setup", "got %s" % str(morale_bar.value))


func test_direct_stat_mutation_updates_ui() -> void:
	print("\n--- Test 3: Direct ReactiveStat mutation propagates to UI ---")
	var stat := warrior.get_stat(StatName.I.MORALE)
	stat.stat_value = 0.4
	check(is_equal_approx(morale_bar.value, 40.0), "MoraleBar updates when stat_value is set directly", "got %s" % str(morale_bar.value))


func test_external_driver_mutation_updates_ui() -> void:
	print("\n--- Test 4: External-driver-style flow (random squad member mutated externally) ---")
	var idx := randi() % squad.warriors.size()
	var target: Character = squad.warriors[idx]
	var target_item := panel._item_windows[idx] as UnitItem
	var target_bar = target_item.morale_bar

	var before: float = target_bar.value
	var new_value: float = fmod(before / 100.0 + 0.37, 1.0)
	target.get_stat(StatName.I.MORALE).stat_value = new_value
	var after: float = target_bar.value

	check(after != before, "MoraleBar value changes after an external mutation", "before=%s after=%s" % [str(before), str(after)])
	check(is_equal_approx(after, new_value * 100.0), "MoraleBar matches underlying stat_value exactly", "bar=%s stat=%s" % [str(after), str(new_value * 100.0)])
