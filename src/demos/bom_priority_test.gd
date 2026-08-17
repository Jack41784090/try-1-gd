extends Node

## BOM-explosion / unified-priority-match prototype — regression test for
## the "hard knot" bug where crafting-guild input demand bypassed the
## priority-sorted order matcher and grabbed raw stock directly, always
## losing to whichever guild happened to register first in array order.
## See /home/ikec/.claude/plans/structured-churning-castle.md for full design.

var test_count := 0
var passed_count := 0
var failed_count := 0

var systems_root: Node
var clock_system: ClockSystem
var location_economy_system: LocationEconomySystem
var caravan_economy_system: CaravanEconomySystem

var iron: Thing
var wood: Thing
var iron_sword: Thing
var iron_hoe: Thing

var town_a: Location
var town_b: Location
var iron_hoe_guild: CraftingGuild
var iron_sword_guild: CraftingGuild


func _ready() -> void:
	MyLog.set_level(MyLog.Level.WARN)

	print("\n" + "=".repeat(70))
	print("BOM-EXPLOSION / UNIFIED-PRIORITY-MATCH — PROTOTYPE TEST SUITE")
	print("=".repeat(70) + "\n")

	_build_world()
	_wire_systems()

	clock_system.force_tick() # hour 1: contention resolves + shipment dispatches at the barrier
	_check_priority_fair_allocation() # must run BEFORE hour 2 — a dispatched shipment from town_b's
	# surplus arrives at the START of hour 2 (1-turn travel), topping up town_a's Iron before hour 2's
	# phase column runs, which would otherwise mask the very contention this check exists to prove

	clock_system.force_tick() # hour 2: shipment arrives — smoke-tests the full multi-hour pipeline

	_check_barrier()
	_check_arrival_filtering()

	print("\n" + "=".repeat(70))
	print("TEST RESULTS: %d passed, %d failed, %d total" % [passed_count, failed_count, test_count])
	if failed_count == 0:
		print("ALL TESTS PASSED")
	else:
		print("SOME TESTS FAILED")
	print("=".repeat(70) + "\n")

	get_tree().quit(0 if failed_count == 0 else 1)


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


func _build_world() -> void:
	iron = Thing.create("iron", "Iron", EconomyTypes.ThingType.TOOLS, 8.0)
	wood = Thing.create("wood", "Timber", EconomyTypes.ThingType.TOOLS, 3.0)
	var iron_input := ThingInput.create(iron, 2.0)
	var wood_input := ThingInput.create(wood, 1.0)
	iron_sword = Thing.create("iron-sword", "Iron Sword", EconomyTypes.ThingType.WEAPONS, 25.0, "", [iron_input, wood_input])
	iron_hoe = Thing.create("iron-hoe", "Iron Hoe", EconomyTypes.ThingType.TOOLS, 20.0, "", [iron_input, wood_input])

	town_a = Location.new()
	town_a.location_id = "town_a"
	town_a.location_name = "Town A"
	town_a.inventory = LocationInventory.new()
	town_a.inventory.init_thing(iron, 0.0)
	town_a.inventory.init_thing(wood, 0.0)
	town_a.inventory.init_thing(iron_sword, 0.0)
	town_a.inventory.init_thing(iron_hoe, 0.0)
	town_a.natural_resources = [
		NaturalResource.create(iron, 6.0, EconomyTypes.JobType.FARMER, 10.0),
		NaturalResource.create(wood, 20.0, EconomyTypes.JobType.FARMER, 10.0),  # abundant — never the bottleneck
	]

	town_b = Location.new()
	town_b.location_id = "town_b"
	town_b.location_name = "Town B"
	town_b.inventory = LocationInventory.new()
	town_b.inventory.init_thing(iron, 0.0)
	town_b.inventory.init_thing(wood, 0.0)
	town_b.inventory.init_thing(iron_sword, 0.0)
	town_b.inventory.init_thing(iron_hoe, 0.0)
	town_b.natural_resources = [
		NaturalResource.create(iron, 50.0, EconomyTypes.JobType.FARMER, 10.0),
	]

	# priorities inverted from registration order — iron_hoe_guild registers
	# FIRST but has the LOWER priority; iron_sword_guild registers SECOND but
	# has the HIGHER priority. Under the old bug, array order would decide
	# the winner; under the fix, priority must.
	iron_hoe_guild = CraftingGuild.create("hoe_guild", iron_hoe, 5.0, 6.0)
	iron_sword_guild = CraftingGuild.create("sword_guild", iron_sword, 5.0, 9.0)


func _wire_systems() -> void:
	var world := World.new()
	world.add_location(town_a)
	world.add_location(town_b)

	systems_root = Node.new()
	systems_root.name = "Systems"
	add_child(systems_root)

	clock_system = ClockSystem.new()
	clock_system.name = "ClockSystem"
	systems_root.add_child(clock_system)
	clock_system.pause() ## drive time via force_tick() only, not real-time _process

	location_economy_system = LocationEconomySystem.new()
	systems_root.add_child(location_economy_system)
	location_economy_system.setup(world)

	var town_a_consumer_demand := {}
	town_a_consumer_demand[iron] = {"qty": 2.0, "priority": 3.0}   # deliberately LOW priority — should still lose to guild demand
	location_economy_system.register_location(town_a, [iron_hoe_guild, iron_sword_guild], town_a_consumer_demand)
	location_economy_system.register_location(town_b, [], {})

	caravan_economy_system = CaravanEconomySystem.new()
	systems_root.add_child(caravan_economy_system)
	caravan_economy_system.setup(world.locations.size())

	# Order matters — see doc-comments on both handlers:
	clock_system.hour_changed.connect(caravan_economy_system._on_hour_changed)       # 1: advance + deliver arrivals
	caravan_economy_system.location_arrived.connect(location_economy_system._on_location_arrived)
	clock_system.hour_changed.connect(location_economy_system._on_hour_changed)      # 2: phase columns (sees delivered cargo)
	location_economy_system.trade_offer.connect(caravan_economy_system._on_trade_offer)  # barrier + global match trigger


func _check_priority_fair_allocation() -> void:
	print("\n--- Priority-Fair Allocation ---")
	check(iron_sword_guild.produced_last_tick > 0.0, "higher-priority Iron Sword guild produced despite registering second")
	check(is_equal_approx(iron_sword_guild.produced_last_tick, 3.0), "Iron Sword output matches secured-Iron cap (6/2), not a raw-stock peek", "got %.2f" % iron_sword_guild.produced_last_tick)
	check(iron_hoe_guild.produced_last_tick == 0.0, "lower-priority Iron Hoe guild produced nothing despite registering FIRST", "got %.2f" % iron_hoe_guild.produced_last_tick)
	check(iron_sword_guild.secured_last_tick.get(iron, 0.0) > iron_hoe_guild.secured_last_tick.get(iron, 0.0), "priority order determined Iron allocation, not registration order")


func _check_barrier() -> void:
	print("\n--- Trade-Offer Barrier ---")
	var probe := CaravanEconomySystem.new()
	add_child(probe)
	probe.setup(2)
	# Single-element Array, not a plain bool: GDScript lambdas capture outer
	# locals BY VALUE at creation time, so `probe_dispatched = true` inside a
	# lambda would only mutate the lambda's own copy, never this scope's
	# variable. A shared mutable container sidesteps that.
	var probe_dispatched := [false]
	probe.shipment_dispatched.connect(func(_m: EconomyMove, _g: int) -> void: probe_dispatched[0] = true)

	var town_a_unmet := {}
	town_a_unmet[iron] = 5.0
	probe._on_trade_offer("town_a", {}, town_a_unmet)
	check(not probe_dispatched[0], "barrier withholds global match after only 1 of 2 locations reported")

	var town_b_surplus := {}
	town_b_surplus[iron] = 5.0
	probe._on_trade_offer("town_b", town_b_surplus, {})
	check(probe_dispatched[0], "barrier runs global match once all locations have reported")

	probe.queue_free()


func _check_arrival_filtering() -> void:
	print("\n--- Arrival Delivery Filtering ---")
	var iron_before_a := town_a.inventory.get_available(iron)
	var iron_before_b := town_b.inventory.get_available(iron)
	location_economy_system._on_location_arrived("town_a", iron, 7.0)
	check(is_equal_approx(town_a.inventory.get_available(iron), iron_before_a + 7.0), "location_arrived added cargo to the destination")
	check(is_equal_approx(town_b.inventory.get_available(iron), iron_before_b), "location_arrived left the OTHER location's inventory untouched")
