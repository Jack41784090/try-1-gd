extends Node

class_name AIFleetManager

var scenario: GameScenario = null
var squad_brains: Dictionary = { }
var squad_executors: Dictionary = { }
var faction_brain: FactionBrain = FactionBrain.new()

var decisions_this_turn: Dictionary = { }
var combat_log: Array[String] = []


func setup(_scenario: GameScenario) -> void:
	# Initializes the AI fleet — creates a SquadBrain + ActivityExecuteManager for each roaming squad
	# e.g., scenario has 3 roaming squads: ["Wolves", "Hawks", "Bears"]
	#   → creates 3 SquadBrain instances (decision makers) + 3 ActivityExecuteManagers (action executors)
	assert(_scenario != null, "AIFleetManager requires a GameScenario")
	scenario = _scenario

	Log.info("Fleet", "Setting up fleet with %d roaming squads" % scenario.world.roaming_squads.size())

	squad_brains.clear()
	squad_executors.clear()

	# 1. Load the default AI behavior profile (considerations + fallback action)
	# e.g., "balanced-roamer.tres" with considerations like ["low_food_forage", "enemy_nearby_attack", ...]
	var profile = AIProfileFactory.get_default_squad_profile()

	# 2. For each roaming squad, create its brain and executor
	for squad in scenario.world.roaming_squads:
		# 2.1 If squad has no current location, use its starting_location_id
		if squad.current_location_id.is_empty() and not squad.starting_location_id.is_empty():
			squad.set_location(squad.starting_location_id)

		# 2.2 Duplicate warriors to prevent shared-resource mutation across squads
		_ensure_unique_warriors(squad)

		# 2.3 Create brain (decides WHAT to do) and executor (executes the activity)
		var brain = SquadBrain.new(squad, profile)
		squad_brains[squad.squad_id] = brain
		var executor = ActivityExecuteManager.new(true)
		executor.setup(scenario, { "squad": squad })
		squad_executors[squad.squad_id] = executor

		Log.debug("Fleet", "Created brain for squad: %s" % squad.squad_name)

	Log.info("Fleet", "Fleet setup complete with %d squad brains" % squad_brains.size())


func prepare_ai_turns() -> Dictionary:
	if squad_brains.is_empty():
		return { "decisions_this_turn": {} }

	Log.debug("Fleet", "=== Preparing AI Turn for %d squads ===" % squad_brains.size())
	decisions_this_turn.clear()

	var directives = faction_brain.produce_directives(scenario.world)
	var default_directive = directives[0] if not directives.is_empty() else FactionDirective.create_none()

	for squad_id in squad_brains:
		decisions_this_turn[squad_id] = _prepare_squad_decision(squad_id, default_directive)

	return { "decisions_this_turn": decisions_this_turn }


func _prepare_squad_decision(squad_id: String, directive: FactionDirective) -> Dictionary:
	var brain = squad_brains[squad_id]
	var result: Dictionary = brain.decide(scenario.world, null, directive)

	var activity_type: StrategyTypes.ActivityType = result["activity_type"]
	var context: Dictionary = result["context"]

	var activity: Activity = _resolve_activity(activity_type)
	activity = _customize_travel_activity(activity, activity_type, context)

	if squad_executors.has(squad_id):
		squad_executors[squad_id].ai_decision_context = context

	return {
		"activity_type": activity_type,
		"context": context,
		"squad": brain.squad,
		"activity": activity,
		"location_at_decision": brain.squad.current_location_id,
	}


func _resolve_activity(activity_type: StrategyTypes.ActivityType) -> Activity:
	var activity: Activity = _get_activity_from_scenario(activity_type)
	if not activity:
		activity = _get_activity_from_scenario(StrategyTypes.ActivityType.REST)
	assert(activity != null, "Must have a REST activity as fallback")
	return activity


func _customize_travel_activity(activity: Activity, activity_type: StrategyTypes.ActivityType, context: Dictionary) -> Activity:
	match activity_type:
		StrategyTypes.ActivityType.TRAVEL, StrategyTypes.ActivityType.FORCE_MARCH:
			activity = activity.duplicate(true)
			activity.result = activity.result.duplicate(true)
			var destination: String = context.get("travel_destination", "")
			if not destination.is_empty():
				activity.destination_id = destination
				activity.result.location_changed = destination
				if activity_type == StrategyTypes.ActivityType.FORCE_MARCH:
					activity.ultimate_destination_id = context.get("ultimate_destination", "")
	return activity


func _find_squad_by_id(squad_id: String) -> SquadData:
	for squad in scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad

	if scenario.starting_player_squad and scenario.starting_player_squad.squad_id == squad_id:
		return scenario.starting_player_squad

	return null


func get_ai_squad_count() -> int:
	return squad_brains.size()


func get_ai_squad_ids() -> Array[String]:
	var ids: Array[String] = []
	for squad_id in squad_brains:
		ids.append(squad_id)
	return ids


func _get_activity_from_scenario(activity_type: StrategyTypes.ActivityType) -> Activity:
	for triggerable in scenario.triggerable_manager.registered_triggerables:
		if triggerable is Activity and triggerable.activity_type == activity_type:
			return triggerable
	return null


func _execute_headless_combat(combat_data: Dictionary) -> void:
	# Simplified AI vs AI combat — no tactical SquadBattle, just strength comparison + RNG
	# e.g., Wolves(3 warriors, morale=80) vs Bears(2 warriors, morale=60)
	#   → atk_strength = 3 × (80+50) = 390 × random(0.7-1.3)
	#   → def_strength = 2 × (60+50) = 220 × random(0.7-1.3)
	#   → Wolves win, Bears lose half their warriors
	var attacker_id: String = combat_data["attacker_id"]
	var defender_id: String = combat_data["defender_id"]
	var is_mutual: bool = combat_data.get("is_mutual", false)

	Log.info("Fleet", "Resolving combat: %s vs %s%s" % [
		attacker_id,
		defender_id,
		" (MUTUAL)" if is_mutual else "",
	])

	var attacker = _find_squad_by_id(attacker_id)
	var defender = _find_squad_by_id(defender_id)

	if not attacker or not defender:
		Log.error("Fleet", "Could not find squads for combat")
		return

	var atk_living = attacker.get_living_warriors()
	var def_living = defender.get_living_warriors()
	var atk_strength := atk_living.size() * (attacker.get_morale() + 50.0)
	var def_strength := def_living.size() * (defender.get_morale() + 50.0)

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	atk_strength *= rng.randf_range(0.7, 1.3)
	def_strength *= rng.randf_range(0.7, 1.3)

	Log.debug("Fleet", "Strength: %s=%.0f vs %s=%.0f" % [
		attacker.squad_name,
		atk_strength,
		defender.squad_name,
		def_strength,
	])

	var winner: SquadData
	var loser: SquadData
	if atk_strength >= def_strength:
		winner = attacker
		loser = defender
	else:
		winner = defender
		loser = attacker

	var loser_living = loser.get_living_warriors()
	var casualties = maxi(1, loser_living.size() / 2)
	for i in range(mini(casualties, loser_living.size())):
		loser_living[i].is_dead = true
	Log.info("Fleet", "%s lost %d warriors" % [loser.squad_name, casualties])

	var winner_living = winner.get_living_warriors()
	if winner_living.size() > 1 and rng.randf() < 0.4:
		winner_living[0].is_injured = true
		Log.debug("Fleet", "%s had 1 warrior injured" % winner.squad_name)

	winner.modify_morale(15)
	loser.modify_morale(-20)
	Log.info("Fleet", "%s VICTORIOUS (morale: %d)" % [winner.squad_name, winner.get_morale()])
	Log.info("Fleet", "%s DEFEATED (morale: %d, living: %d)" % [
		loser.squad_name,
		loser.get_morale(),
		loser.get_living_warriors().size(),
	])
	combat_log.append("AI_COMBAT %s defeated %s (%d killed)" % [
		winner.squad_name, loser.squad_name, casualties])

	if loser.is_caravan() and loser.has_cargo():
		var Bridge = load("res://src/economy/caravan_bridge.gd")
		Bridge.apply_loot(loser, winner)
		Log.info("Fleet", "%s looted caravan %s" % [winner.squad_name, loser.squad_name])

	if loser.get_living_warriors().size() > 0:
		var nearest = scenario.world.find_nearest_location(loser.current_location_id)
		if nearest != "":
			loser.set_location(nearest)
			Log.info("Fleet", "%s fled to %s" % [loser.squad_name, nearest])


func cleanup_defeated_squads() -> void:
	var to_remove: Array[String] = []

	for squad_id in squad_brains:
		var brain = squad_brains[squad_id]
		var squad: SquadData = brain.squad

		var living_count = 0
		var total_count = squad.warriors.size()

		for warrior in squad.warriors:
			if warrior != null and not warrior.is_dead:
				living_count += 1

		Log.trace("Fleet", "Squad %s: %d/%d warriors alive" % [
			squad.squad_name,
			living_count,
			total_count,
		])

		if living_count == 0:
			Log.info("Fleet", "Squad %s eliminated - removing from fleet" % squad.squad_name)
			to_remove.append(squad_id)
			continue

		if squad.get_morale() <= 0.0 and living_count > 0:
			var deserters := 0
			for warrior in squad.get_living_warriors():
				if warrior.morale <= 0.0:
					warrior.is_dead = true
					deserters += 1
			if deserters > 0:
				Log.info("Fleet", "%s: %d warrior(s) deserted (0 morale)" % [squad.squad_name, deserters])
			if squad.get_living_warriors().size() == 0:
				Log.info("Fleet", "Squad %s disbanded from mass desertion" % squad.squad_name)
				to_remove.append(squad_id)

	for squad_id in to_remove:
		var brain = squad_brains[squad_id]
		scenario.world.roaming_squads.erase(brain.squad)
		scenario.world.contact_tracker.clear_contacts_for(squad_id)
		squad_brains.erase(squad_id)
		squad_executors.erase(squad_id)

	if to_remove.size() > 0:
		for sid in to_remove:
			combat_log.append("ELIMINATED squad removed from world")
		Log.info("Fleet", "%d squads eliminated. Remaining: %d" % [to_remove.size(), squad_brains.size()])


func fill_activity_log(activity_log: Dictionary, edge_log: Dictionary) -> void:
	for squad_id in decisions_this_turn:
		var decision = decisions_this_turn[squad_id]
		var activity_type: StrategyTypes.ActivityType = decision["activity_type"]
		var context: Dictionary = decision["context"]

		activity_log[squad_id] = activity_type

		if activity_type in [StrategyTypes.ActivityType.TRAVEL, StrategyTypes.ActivityType.FORCE_MARCH]:
			var destination = context.get("travel_destination", "")
			if not destination.is_empty():
				edge_log[squad_id] = { "from": decision["location_at_decision"], "to": destination }


const WARRIOR_NAMES := [
	"Albrecht", "Bernhard", "Conrad", "Dietrich", "Eberhard",
	"Friedrich", "Gunther", "Heinrich", "Ivo", "Jakob",
	"Karl", "Ludwig", "Markus", "Nikolaus", "Otto",
	"Philipp", "Reinhard", "Siegmund", "Theodor", "Ulrich",
	"Volker", "Wilhelm", "Xaver", "Yannick", "Zacharias",
]

func _ensure_unique_warriors(squad: SquadData) -> void:
	var unique_warriors: Array[Warrior] = []
	for i in range(squad.warriors.size()):
		var copy: Warrior = squad.warriors[i].duplicate(true)
		copy.id = "%s_w%d" % [squad.squad_id, i]
		copy.name = WARRIOR_NAMES[(squad.squad_id.hash() + i) % WARRIOR_NAMES.size()]
		unique_warriors.append(copy)
	squad.warriors = unique_warriors


func register_caravan(squad: SquadData) -> void:
	assert(squad.is_caravan(), "register_caravan requires a merchant squad")
	_ensure_unique_warriors(squad)
	var profile = AIProfileFactory.get_default_squad_profile()
	var BrainClass = load("res://src/strategy/ai/caravan_brain.gd")
	var brain = BrainClass.new(squad, profile)
	squad_brains[squad.squad_id] = brain
	var executor = ActivityExecuteManager.new(true)
	executor.setup(scenario, {"squad": squad})
	squad_executors[squad.squad_id] = executor
	Log.debug("Fleet", "Registered caravan brain: %s" % squad.squad_name)


func unregister_caravan(squad_id: String) -> void:
	squad_brains.erase(squad_id)
	squad_executors.erase(squad_id)
	decisions_this_turn.erase(squad_id)
	scenario.world.contact_tracker.clear_contacts_for(squad_id)
	Log.debug("Fleet", "Unregistered caravan: %s" % squad_id)


func register_bandit(squad: SquadData, profile_path: String) -> void:
	assert(squad.squad_role == StrategyTypes.SquadRole.BANDIT, "register_bandit requires a bandit squad")
	_ensure_unique_warriors(squad)
	var profile = AIProfileFactory.get_squad_profile(profile_path)
	var brain = SquadBrain.new(squad, profile)
	squad_brains[squad.squad_id] = brain
	var executor = ActivityExecuteManager.new(true)
	executor.setup(scenario, {"squad": squad})
	squad_executors[squad.squad_id] = executor
	Log.debug("Fleet", "Registered bandit brain: %s" % squad.squad_name)


func unregister_squad(squad_id: String) -> void:
	squad_brains.erase(squad_id)
	squad_executors.erase(squad_id)
	decisions_this_turn.erase(squad_id)
	scenario.world.contact_tracker.clear_contacts_for(squad_id)
	Log.debug("Fleet", "Unregistered squad: %s" % squad_id)
