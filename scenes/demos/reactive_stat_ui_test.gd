extends Node

## Regression test for ReactiveStat -> units_panel/unit_item UI wiring.
## Simulates the exact scene the user manually tested (units_panel.tscn with
## its Timer driving units_panel.gd's _change_random_squad_member_prop) and
## verifies the MoraleBar in unit_item.tscn actually reflects stat changes.

const UNITS_PANEL_SCENE := preload("res://src/units_panel.tscn")
const ENTITY_RESOURCE_PATH := "res://src/strategy_entity_resource-instance1.tres"

var test_count := 0
var passed_count := 0
var failed_count := 0

var panel: TestUnitsFloatingPanel
var squad: TestStrategySquad
var warrior: TestStrategyEntity
var item: TestUnitItem
var morale_bar


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("REACTIVE STAT UI — UNIT PANEL TEST SUITE")
	print("=".repeat(70) + "\n")

	_setup_scene()
	test_key_resolution()
	test_initial_render()
	test_direct_stat_mutation_updates_ui()
	test_timer_driven_mutation_updates_ui()

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


func _setup_scene() -> void:
	var res := load(ENTITY_RESOURCE_PATH) as TestStrategyEntityResource
	warrior = TestStrategyEntity.new(res)
	warrior.display_name = "Test Warrior"

	squad = TestStrategySquad.new()
	squad.add_warrior(warrior)

	# Mirrors real usage: instance the panel scene, add it to the tree, then
	# hand it a squad — same sequence units_panel.gd relies on for @onready
	# nodes and the deferred/immediate setup() split.
	panel = UNITS_PANEL_SCENE.instantiate()
	add_child(panel)
	panel.setup(squad)

	check(panel._item_windows.size() == 1, "Panel builds one unit_item for the one warrior", "got %d" % panel._item_windows.size())
	item = panel._item_windows[0] as TestUnitItem
	morale_bar = item.morale_bar

#endregion


func test_key_resolution() -> void:
	print("\n--- Test 1: ReactiveStat key resolution ---")
	var stat := warrior.get_stat(StatName.I.MORALE)
	check(stat != null, "get_stat(MORALE) resolves to a ReactiveStat", "RS_DF_START_MORALE.tres stat_name must be int 0, not a StringName")
	if stat:
		check(stat.stat_value == 1.0, "Initial morale stat_value is 1.0", "got %s" % str(stat.stat_value))


func test_initial_render() -> void:
	print("\n--- Test 2: Initial panel render reflects entity state ---")
	check(morale_bar.value == 1.0, "MoraleBar reads initial stat_value on setup", "got %s" % str(morale_bar.value))


func test_direct_stat_mutation_updates_ui() -> void:
	print("\n--- Test 3: Direct ReactiveStat mutation propagates to UI ---")
	var stat := warrior.get_stat(StatName.I.MORALE)
	stat.stat_value = 5.0
	check(morale_bar.value == 5.0, "MoraleBar updates when stat_value is set directly", "got %s" % str(morale_bar.value))


func test_timer_driven_mutation_updates_ui() -> void:
	print("\n--- Test 4: Timer-callback flow (units_panel._change_random_squad_member_prop) ---")
	var before: float = morale_bar.value
	panel._change_random_squad_member_prop()
	var after: float = morale_bar.value
	check(after != before, "MoraleBar value changes after a simulated timer tick", "before=%s after=%s" % [str(before), str(after)])
	check(after == warrior.get_stat(StatName.I.MORALE).stat_value, "MoraleBar matches underlying stat_value exactly", "bar=%s stat=%s" % [str(after), str(warrior.get_stat(StatName.I.MORALE).stat_value)])
