class_name AISquadManager extends Node

var scenario: GameScenario = null
var squad_brains: Dictionary = {}
var squad_executors: Dictionary = {}
var faction_brain: FactionBrain = FactionBrain.new()

var decisions_this_turn: Dictionary = {}
var combat_log: Array[String] = []

var _bandit_spawner: BanditSpawner = BanditSpawner.new()


func setup(_scenario: GameScenario) -> void:
	assert(_scenario != null, "AISquadManager requires a GameScenario")
	assert(squad_brains.is_empty() and squad_executors.is_empty())

	scenario = _scenario

	MyLog.info("Fleet", "Setting up fleet with %d roaming squads" % scenario.world.roaming_squads.size())

	var profile = AIProfileFactory.get_default_squad_profile()

	for squad in scenario.world.roaming_squads:
		if squad.current_location_id.is_empty() and not squad.starting_location_id.is_empty():
			squad.set_location(squad.starting_location_id)

		# duplicated so squads don't share mutable warrior instances
		_ensure_unique_warriors(squad)

		var brain = StrategySquadBrain.new(squad, profile)
		_register_brain_and_executor(squad, brain)

		MyLog.debug("Fleet", "Created brain for squad: %s" % squad.squad_name)

	MyLog.info("Fleet", "Fleet setup complete with %d squad brains" % squad_brains.size())


func prepare_ai_turns() -> Dictionary:
	if squad_brains.is_empty():
		return {}

	MyLog.debug("Fleet", "=== Preparing AI Turn for %d squads ===" % squad_brains.size())
	decisions_this_turn.clear()

	var directives = faction_brain.produce_directives(scenario.world)
	var default_directive = directives[0] if not directives.is_empty() else FactionDirective.create_none()

	for squad_id in squad_brains:
		var brain = squad_brains[squad_id]
		var result: Dictionary = brain.decide(scenario.world, null, default_directive)

		var activity_type: StrategyTypes.ActivityType = result["activity_type"]
		var context: Dictionary = result["context"]

		var activity: Activity = _get_activity_from_scenario(activity_type)
		if not activity:
			activity = _get_activity_from_scenario(StrategyTypes.ActivityType.REST)
		assert(activity != null, "Must have a REST activity as fallback")
		if _is_travel_activity(activity_type):
			activity = activity.duplicate(true)
			activity.result = activity.result.duplicate(true)
			var destination: String = context.get("travel_destination", "")
			if not destination.is_empty():
				activity.destination_id = destination
				activity.result.location_changed = destination
				if activity_type == StrategyTypes.ActivityType.FORCE_MARCH:
					activity.ultimate_destination_id = context.get("ultimate_destination", "")

		if squad_executors.has(squad_id):
			squad_executors[squad_id].ai_decision_context = context

		decisions_this_turn[squad_id] = {
			"activity_type": activity_type,
			"context": context,
			"squad": brain.squad,
			"activity": activity,
			"location_at_decision": brain.squad.current_location_id,
		}

	return decisions_this_turn



func _find_squad_by_id(squad_id: String) -> StrategySquad:
	for squad in scenario.world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad

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
	# simplified AI-vs-AI combat: no tactical SquadBattle, just strength comparison + RNG
	var attacker_id: String = combat_data["attacker_id"]
	var defender_id: String = combat_data["defender_id"]
	var is_mutual: bool = combat_data.get("is_mutual", false)

	MyLog.info("Fleet", "Resolving combat: %s vs %s%s" % [
		attacker_id,
		defender_id,
		" (MUTUAL)" if is_mutual else "",
	])

	var attacker = _find_squad_by_id(attacker_id)
	var defender = _find_squad_by_id(defender_id)

	if not attacker or not defender:
		MyLog.error("Fleet", "Could not find squads for combat")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var atk_strength := _roll_strength(attacker, rng)
	var def_strength := _roll_strength(defender, rng)

	MyLog.debug("Fleet", "Strength: %s=%.0f vs %s=%.0f" % [
		attacker.squad_name,
		atk_strength,
		defender.squad_name,
		def_strength,
	])

	var winner: StrategySquad
	var loser: StrategySquad
	if atk_strength >= def_strength:
		winner = attacker
		loser = defender
	else:
		winner = defender
		loser = attacker

	var loser_living = loser.get_living_warriors()
	var casualties := maxi(1, int(loser_living.size() / 2.0))
	for i in range(mini(casualties, loser_living.size())):
		loser_living[i].is_dead = true
	MyLog.info("Fleet", "%s lost %d warriors" % [loser.squad_name, casualties])

	var winner_living = winner.get_living_warriors()
	if winner_living.size() > 1 and rng.randf() < 0.4:
		winner_living[0].is_injured = true
		MyLog.debug("Fleet", "%s had 1 warrior injured" % winner.squad_name)

	winner.modify_morale(15)
	loser.modify_morale(-20)
	MyLog.info("Fleet", "%s VICTORIOUS (morale: %d)" % [winner.squad_name, winner.get_morale()])
	MyLog.info("Fleet", "%s DEFEATED (morale: %d, living: %d)" % [
		loser.squad_name,
		loser.get_morale(),
		loser.get_living_warriors().size(),
	])
	combat_log.append("AI_COMBAT %s defeated %s (%d killed)" % [
		winner.squad_name, loser.squad_name, casualties])

	if loser.is_caravan() and loser.has_cargo():
		CaravanBridge.apply_loot(loser, winner)
		MyLog.info("Fleet", "%s looted caravan %s" % [winner.squad_name, loser.squad_name])

	if loser.get_living_warriors().size() > 0:
		var nearest = scenario.world.find_nearest_location(loser.current_location_id)
		if nearest != "":
			loser.set_location(nearest)
			MyLog.info("Fleet", "%s fled to %s" % [loser.squad_name, nearest])


func cleanup_defeated_squads() -> void:
	var to_remove: Array[String] = []

	for squad_id in squad_brains:
		var brain = squad_brains[squad_id]
		var squad: StrategySquad = brain.squad

		var living_count = 0
		var total_count = squad.warriors.size()

		for warrior in squad.warriors:
			if warrior != null and not warrior.is_dead:
				living_count += 1

		MyLog.trace("Fleet", "Squad %s: %d/%d warriors alive" % [
			squad.squad_name,
			living_count,
			total_count,
		])

		if living_count == 0:
			MyLog.info("Fleet", "Squad %s eliminated - removing from fleet" % squad.squad_name)
			to_remove.append(squad_id)
			continue

		if squad.get_morale() <= 0.0 and living_count > 0:
			var deserters := 0
			for warrior in squad.get_living_warriors():
				if float(warrior.get_stat_value(StatName.I.MORALE)) <= 0.0:
					warrior.is_dead = true
					deserters += 1
			if deserters > 0:
				MyLog.info("Fleet", "%s: %d warrior(s) deserted (0 morale)" % [squad.squad_name, deserters])
			if squad.get_living_warriors().size() == 0:
				MyLog.info("Fleet", "Squad %s disbanded from mass desertion" % squad.squad_name)
				to_remove.append(squad_id)

	for squad_id in to_remove:
		var brain = squad_brains[squad_id]
		scenario.world.roaming_squads.erase(brain.squad)
		_erase_squad_runtime_state(squad_id)

	if to_remove.size() > 0:
		for sid in to_remove:
			combat_log.append("ELIMINATED squad removed from world")
		MyLog.info("Fleet", "%d squads eliminated. Remaining: %d" % [to_remove.size(), squad_brains.size()])


func fill_activity_log(activity_log: Dictionary, edge_log: Dictionary) -> void:
	for squad_id in decisions_this_turn:
		var decision = decisions_this_turn[squad_id]
		var activity_type: StrategyTypes.ActivityType = decision["activity_type"]
		var context: Dictionary = decision["context"]

		activity_log[squad_id] = activity_type

		if _is_travel_activity(activity_type):
			var destination = context.get("travel_destination", "")
			if not destination.is_empty():
				edge_log[squad_id] = {"from": decision["location_at_decision"], "to": destination}


func _is_travel_activity(activity_type: StrategyTypes.ActivityType) -> bool:
	return activity_type == StrategyTypes.ActivityType.TRAVEL or activity_type == StrategyTypes.ActivityType.FORCE_MARCH


const WARRIOR_NAMES := [
	"Albrecht", "Bernhard", "Conrad", "Dietrich", "Eberhard",
	"Friedrich", "Gunther", "Heinrich", "Ivo", "Jakob",
	"Karl", "Ludwig", "Markus", "Nikolaus", "Otto",
	"Philipp", "Reinhard", "Siegmund", "Theodor", "Ulrich",
	"Volker", "Wilhelm", "Xaver", "Yannick", "Zacharias",
]

func _ensure_unique_warriors(squad: StrategySquad) -> void:
	var unique_warriors: Array[Character] = []
	for i in range(squad.warriors.size()):
		var copy: Character = squad.warriors[i].duplicate(true)
		copy.strategy.id = "%s_w%d" % [squad.squad_id, i]
		copy.strategy.display_name = WARRIOR_NAMES[(squad.squad_id.hash() + i) % WARRIOR_NAMES.size()]
		unique_warriors.append(copy)
	squad.warriors = unique_warriors


func register_squad(squad: StrategySquad, profile_path: String = "") -> void:
	_ensure_unique_warriors(squad)
	var resolved_profile_path := profile_path
	if resolved_profile_path.is_empty():
		if squad.is_caravan():
			resolved_profile_path = AIProfileFactory.CARAVAN_PROFILE_PATH
		else:
			resolved_profile_path = AIProfileFactory.DEFAULT_SQUAD_PROFILE_PATH
	var profile = AIProfileFactory.get_squad_profile(resolved_profile_path)
	var brain = StrategySquadBrain.new(squad, profile)
	_register_brain_and_executor(squad, brain)
	MyLog.debug("Fleet", "Registered squad brain: %s (%s)" % [squad.squad_name, profile.profile_name])


func unregister_squad(squad_id: String) -> void:
	_erase_squad_runtime_state(squad_id)
	MyLog.debug("Fleet", "Unregistered squad: %s" % squad_id)


func tick_bandit_lifecycle(faction: Faction) -> Array[String]:
	assert(scenario != null, "AISquadManager.tick_bandit_lifecycle requires setup() first")
	var event_log: Array[String] = []
	if faction == null:
		return event_log
	event_log.append_array(_bandit_spawner.tick_cleanup(scenario.world, faction, self ))
	event_log.append_array(_bandit_spawner.tick_spawning(scenario.world, faction, self ))
	return event_log


func _register_brain_and_executor(squad: StrategySquad, brain: RefCounted) -> void:
	squad_brains[squad.squad_id] = brain
	var executor = ActivityExecuteManager.new(true)
	executor.setup(scenario, {"squad": squad})
	squad_executors[squad.squad_id] = executor


func _erase_squad_runtime_state(squad_id: String) -> void:
	squad_brains.erase(squad_id)
	squad_executors.erase(squad_id)
	decisions_this_turn.erase(squad_id)
	scenario.world.contact_tracker.clear_contacts_for(squad_id)


func _roll_strength(squad: StrategySquad, rng: RandomNumberGenerator) -> float:
	var living = squad.get_living_warriors()
	var base_strength = living.size() * (squad.get_morale() + 50.0)
	return base_strength * rng.randf_range(0.7, 1.3)
