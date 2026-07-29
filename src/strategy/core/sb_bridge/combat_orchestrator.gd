class_name CombatOrchestrator
extends RefCounted

var combat_controller: CombatController
var is_in_encounter: bool = false


func setup(contact_tracker) -> void:
	combat_controller = CombatController.new()
	combat_controller.set_contact_tracker(contact_tracker)


func inject_context(player: StrategySquad, enemy: StrategySquad, battle_viewport, combat_overlay, engagement_type) -> Dictionary:
	is_in_encounter = true
	return combat_controller.inject_context(player, enemy, battle_viewport, combat_overlay, engagement_type)


func execute_choice(choice: CombatController.IntermissionChoice) -> CombatController.CombatResult:
	return await combat_controller.process_intermission_choice(choice)


func apply_result(result: CombatController.CombatResult, squad: StrategySquad, location, world, turn_log: Array[String]) -> Dictionary:
	is_in_encounter = false

	var outcome_str := "VICTORY" if result.victory else ("FLED" if result.fled else ("NEGOTIATED" if result.negotiated else "DEFEAT"))
	turn_log.append("COMBAT %s — casualties:%d escaped:%d" % [
		outcome_str, result.player_casualties.size(), result.escaped_warriors.size()])

	var morale_before = squad.get_morale()

	if result.morale_change != 0:
		squad.modify_aggregate_morale(result.morale_change)
		Log.debug("Combat", "Applied morale change: %.1f" % result.morale_change)

	for casualty_id in result.player_casualties:
		var warrior = squad.get_warrior_by_id(casualty_id)
		if warrior:
			turn_log.append("CASUALTY %s" % warrior.display_name)
			Log.info("Combat", "Casualty: %s" % warrior.display_name)

	for escaped_id in result.escaped_warriors:
		var warrior = squad.get_warrior_by_id(escaped_id)
		if warrior:
			turn_log.append("ESCAPED %s (injured)" % warrior.display_name)
			Log.info("Combat", "Escaped (injured): %s" % warrior.display_name)

	if result.loot:
		Log.debug("Combat", "Loot collected: %s" % [result.loot])
		_apply_loot(squad, result.loot)

	if not result.equipment_loot.is_empty():
		LootCollector.apply_equipment_loot(squad.inventory, result.equipment_loot)

	if result.clues_dropped.size() > 0 and location:
		for clue in result.clues_dropped:
			location.add_clue(clue)
			Log.debug("Combat", "Clue dropped: %s" % clue.clue_name)

	var morale_after = squad.get_morale()

	var nearest_flee_location := ""
	if not result.victory and not result.fled and not result.negotiated:
		if not squad.get_living_warriors().is_empty():
			nearest_flee_location = world.find_nearest_location(squad.current_location_id)
			if nearest_flee_location != "":
				squad.set_location(nearest_flee_location)
				Log.info("Combat", "Defeated squad teleporting to nearest location: %s" % nearest_flee_location)

	return {
		"morale_before": morale_before,
		"morale_after": morale_after,
		"game_over": squad.get_living_warriors().is_empty(),
	}


func _apply_loot(squad: StrategySquad, loot: Dictionary) -> void:
	if loot.has("money"):
		squad.money += loot.money
		Log.debug("Combat", "Gained money: %.0f" % loot.money)
	if loot.has("food"):
		squad.food += int(loot.food)
		Log.debug("Combat", "Gained food: %d" % int(loot.food))
	if loot.has("caravan_cargo"):
		var cargo: Dictionary = loot["caravan_cargo"]
		for thing_id in cargo:
			var qty: float = cargo[thing_id]
			if thing_id == "food":
				squad.food += int(qty)
				Log.debug("Combat", "Looted caravan food: %d" % int(qty))
			else:
				squad.gain_money(qty * 2.0)
				Log.debug("Combat", "Looted caravan goods worth: %.0f" % (qty * 2.0))


static func check_game_over(squad: StrategySquad) -> bool:
	return squad.get_living_warriors().is_empty()
