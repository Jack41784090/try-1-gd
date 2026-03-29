class_name ContactTracker extends RefCounted

const ContactClass = preload("res://src/strategy/core/contact/contact.gd")

var contacts: Dictionary = {}

const ACTIVITY_MODIFIERS: Dictionary = {
	StrategyTypes.ActivityType.REST: [0.5, 1.3],
	StrategyTypes.ActivityType.DRILL: [0.6, 0.5],
	StrategyTypes.ActivityType.TRAVEL: [0.7, 0.6],
	StrategyTypes.ActivityType.PATROL: [1.5, 0.8],
	StrategyTypes.ActivityType.INVESTIGATE: [1.3, 0.9],
	StrategyTypes.ActivityType.HOLD_MASS: [0.4, 1.0],
	StrategyTypes.ActivityType.MERCENARY_WORK: [0.6, 0.8],
	StrategyTypes.ActivityType.FORAGE: [0.8, 0.7],
	StrategyTypes.ActivityType.ATTACK: [1.0, 0.4],
	StrategyTypes.ActivityType.FORCE_MARCH: [0.3, 0.3],
	StrategyTypes.ActivityType.MANAGE_SQUAD: [0.4, 1.0],
	StrategyTypes.ActivityType.RECRUIT: [0.5, 0.7],
	StrategyTypes.ActivityType.CUSTOM: [0.5, 0.5],
}

const LOCATION_VISIBILITY: Dictionary = {
	StrategyTypes.LocationType.ROAD: 1.0,
	StrategyTypes.LocationType.VILLAGE: 0.8,
	StrategyTypes.LocationType.TOWN: 0.7,
	StrategyTypes.LocationType.CITY: 0.5,
	StrategyTypes.LocationType.FORT: 0.4,
}

const BASE_SPOTTING_RATE: float = 15.0
const DECAY_RATE: float = 10.0
const SAME_LOCATION_PROXIMITY: float = 1.0
const ADJACENT_PROXIMITY: float = 0.3
const SAME_EDGE_PROXIMITY: float = 0.7
const FOCUS_BOOST: float = 1.0
const FOCUS_PENALTY: float = 0.6

func _make_key(observer_id: String, target_id: String) -> String:
	return "%s::%s" % [observer_id, target_id]

func get_or_create_contact(observer_id: String, target_id: String):
	var key = _make_key(observer_id, target_id)
	if not contacts.has(key):
		contacts[key] = ContactClass.create(observer_id, target_id)
	return contacts[key]

func get_contact(observer_id: String, target_id: String):
	var key = _make_key(observer_id, target_id)
	return contacts.get(key)

func get_contacts_for(squad_id: String) -> Array:
	var result: Array = []
	for key in contacts:
		var c = contacts[key]
		if c.observer_id == squad_id:
			result.append(c)
	return result

func get_contacts_on(squad_id: String) -> Array:
	var result: Array = []
	for key in contacts:
		var c = contacts[key]
		if c.target_id == squad_id:
			result.append(c)
	return result

func update_all_contacts(world: World, all_squads: Array, activity_log: Dictionary, edge_log: Dictionary, current_turn: int, focus_map: Dictionary = {}) -> void:
	for i in range(all_squads.size()):
		var observer: SquadData = all_squads[i]
		var observer_activity: StrategyTypes.ActivityType = activity_log.get(observer.squad_id, StrategyTypes.ActivityType.REST)

		var enemies: Array[SquadData] = []
		for j in range(all_squads.size()):
			if i != j:
				enemies.append(all_squads[j])

		var focus = focus_map.get(observer.squad_id)
		var capacity = _get_tracking_capacity(observer, observer_activity)
		var tracked_targets = _select_tracked_targets(observer, enemies, world, edge_log, capacity, focus)

		for enemy in enemies:
			var contact = get_or_create_contact(observer.squad_id, enemy.squad_id)
			var is_tracked = tracked_targets.has(enemy.squad_id)
			if not is_tracked:
				contact.apply_delta(-DECAY_RATE, current_turn)
				continue

			var enemy_activity: StrategyTypes.ActivityType = activity_log.get(enemy.squad_id, StrategyTypes.ActivityType.REST)
			var proximity = _determine_proximity(observer, enemy, world, edge_log)
			if proximity <= 0.0:
				contact.apply_delta(-DECAY_RATE, current_turn)
				continue

			var observer_location = world.get_location_by_id(observer.current_location_id)
			var location_vis = LOCATION_VISIBILITY.get(observer_location.type, 0.7) if observer_location else 0.7

			var eff_scouting = observer.get_aggregate_scouting() * _get_scouting_mod(observer_activity) * location_vis
			var eff_stealth = enemy.get_aggregate_stealth() * _get_stealth_mod(enemy_activity)

			if enemy.squad_role == StrategyTypes.SquadRole.MERCHANT:
				eff_stealth *= 0.3

			var size_factor = 1.0 + 0.15 * log(1.0 + enemy.get_living_warriors().size())
			var divisor = eff_scouting + eff_stealth
			var ratio = eff_scouting / divisor if divisor > 0.0 else 0.5

			var rate = BASE_SPOTTING_RATE * proximity * ratio * size_factor

			if focus and not focus.is_empty():
				var coordination = observer.get_coordination()
				if focus.matches(enemy):
					rate *= (1.0 + coordination * FOCUS_BOOST)
				else:
					rate *= (1.0 - coordination * FOCUS_PENALTY)

			contact.apply_delta(rate, current_turn)

	_log_contacts(current_turn)


func calculate_focus_multiplier(observer: SquadData, target: SquadData, focus) -> float:
	if not focus or focus.is_empty():
		return 1.0
	var coordination = observer.get_coordination()
	if focus.matches(target):
		return 1.0 + coordination * FOCUS_BOOST
	return 1.0 - coordination * FOCUS_PENALTY

func check_engagements(world: World, all_squads: Array) -> Array[Dictionary]:
	var engagements: Array[Dictionary] = []
	var processed: Dictionary = {}

	for i in range(all_squads.size()):
		var squad_a: SquadData = all_squads[i]
		if processed.has(squad_a.squad_id):
			continue

		for j in range(i + 1, all_squads.size()):
			var squad_b: SquadData = all_squads[j]
			if processed.has(squad_b.squad_id):
				continue

			if squad_a.current_location_id != squad_b.current_location_id:
				continue

			var contact_ab = get_contact(squad_a.squad_id, squad_b.squad_id)
			var contact_ba = get_contact(squad_b.squad_id, squad_a.squad_id)
			if not contact_ab or not contact_ba:
				continue

			var state_ab = contact_ab.get_state()
			var state_ba = contact_ba.get_state()

			if state_ab == StrategyTypes.ContactState.LOCKED and state_ba in [StrategyTypes.ContactState.NONE, StrategyTypes.ContactState.SUSPECTED]:
				engagements.append({
					"attacker_id": squad_a.squad_id,
					"defender_id": squad_b.squad_id,
					"type": StrategyTypes.EngagementType.AMBUSH,
					"location_id": squad_a.current_location_id
				})
				processed[squad_a.squad_id] = true
				processed[squad_b.squad_id] = true
			elif state_ba == StrategyTypes.ContactState.LOCKED and state_ab in [StrategyTypes.ContactState.NONE, StrategyTypes.ContactState.SUSPECTED]:
				engagements.append({
					"attacker_id": squad_b.squad_id,
					"defender_id": squad_a.squad_id,
					"type": StrategyTypes.EngagementType.AMBUSH,
					"location_id": squad_a.current_location_id
				})
				processed[squad_a.squad_id] = true
				processed[squad_b.squad_id] = true
			elif state_ab == StrategyTypes.ContactState.LOCKED and state_ba == StrategyTypes.ContactState.LOCKED:
				engagements.append({
					"attacker_id": squad_a.squad_id,
					"defender_id": squad_b.squad_id,
					"type": StrategyTypes.EngagementType.SET_PIECE,
					"location_id": squad_a.current_location_id
				})
				processed[squad_a.squad_id] = true
				processed[squad_b.squad_id] = true

	return engagements

func apply_clue_bonus(clue: Clue, target_squad: SquadData, observer_squad: SquadData) -> void:
	if clue.destination_id == target_squad.current_location_id:
		var bonus = remap(clue.detail_level, 0.0, 10.0, 10.0, 20.0)
		var contact = get_or_create_contact(observer_squad.squad_id, target_squad.squad_id)
		contact.apply_delta(bonus, 0)
		Log.debug("Contact", "Clue bonus +%.1f on %s → %s" % [bonus, observer_squad.squad_id, target_squad.squad_id])

func clear_contacts_for(squad_id: String) -> void:
	var keys_to_remove: Array[String] = []
	for key in contacts:
		var c = contacts[key]
		if c.observer_id == squad_id or c.target_id == squad_id:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		contacts.erase(key)

func classify_engagement(attacker_id: String, defender_id: String) -> StrategyTypes.EngagementType:
	var contact_atk = get_contact(attacker_id, defender_id)
	var contact_def = get_contact(defender_id, attacker_id)

	var state_atk = contact_atk.get_state() if contact_atk else StrategyTypes.ContactState.NONE
	var state_def = contact_def.get_state() if contact_def else StrategyTypes.ContactState.NONE

	Log.debug("Contact", "Engagement classification: attacker=%s defender=%s" % [
		StrategyTypes.ContactState.keys()[state_atk],
		StrategyTypes.ContactState.keys()[state_def]])

	# Only LOCKED attackers can initiate — classify by defender awareness
	if state_def <= StrategyTypes.ContactState.SUSPECTED:
		return StrategyTypes.EngagementType.AMBUSH
	if state_def == StrategyTypes.ContactState.TRACKED:
		return StrategyTypes.EngagementType.MEETING
	return StrategyTypes.EngagementType.SET_PIECE

#region Proximity

func _determine_proximity(observer: SquadData, target: SquadData, world: World, edge_log: Dictionary) -> float:
	if observer.current_location_id == target.current_location_id:
		return SAME_LOCATION_PROXIMITY

	var obs_edge = edge_log.get(observer.squad_id)
	var tgt_edge = edge_log.get(target.squad_id)

	if obs_edge and tgt_edge:
		var obs_from: String = obs_edge["from"]
		var obs_to: String = obs_edge["to"]
		var tgt_from: String = tgt_edge["from"]
		var tgt_to: String = tgt_edge["to"]

		if obs_from == tgt_to and obs_to == tgt_from:
			return SAME_EDGE_PROXIMITY
		if obs_from == tgt_from and obs_to == tgt_to:
			return SAME_EDGE_PROXIMITY

	if obs_edge:
		if target.current_location_id == obs_edge["from"] or target.current_location_id == obs_edge["to"]:
			return SAME_EDGE_PROXIMITY

	if tgt_edge:
		if observer.current_location_id == tgt_edge["from"] or observer.current_location_id == tgt_edge["to"]:
			return SAME_EDGE_PROXIMITY

	var observer_loc = world.get_location_by_id(observer.current_location_id)
	if observer_loc and observer_loc.is_connected_to(target.current_location_id):
		return ADJACENT_PROXIMITY

	return 0.0

#endregion

#region Tracking Capacity

func _get_tracking_capacity(squad: SquadData, activity_type: StrategyTypes.ActivityType) -> int:
	var base = 1 + int(squad.get_aggregate_scouting() / 30.0)
	if activity_type == StrategyTypes.ActivityType.PATROL:
		base += 1
	return base

func _select_tracked_targets(observer: SquadData, enemies: Array[SquadData], world: World, edge_log: Dictionary, capacity: int, focus = null) -> Dictionary:
	if enemies.size() <= capacity:
		var result: Dictionary = {}
		for e in enemies:
			result[e.squad_id] = true
		return result

	var scored: Array[Dictionary] = []
	for enemy in enemies:
		var score = 0.0
		var contact = get_contact(observer.squad_id, enemy.squad_id)
		if contact:
			score += contact.progress * 10.0

		if observer.current_location_id == enemy.current_location_id:
			score += 500.0

		var prox = _determine_proximity(observer, enemy, world, edge_log)
		score += prox * 100.0
		score += enemy.get_living_warriors().size() * 5.0

		if focus and not focus.is_empty() and focus.matches(enemy):
			score += 300.0

		scored.append({"squad_id": enemy.squad_id, "score": score})

	scored.sort_custom(func(a, b): return a["score"] > b["score"])

	var result: Dictionary = {}
	for i in range(mini(capacity, scored.size())):
		result[scored[i]["squad_id"]] = true
	return result

#endregion

#region Helpers

func _get_scouting_mod(activity: StrategyTypes.ActivityType) -> float:
	var mods = ACTIVITY_MODIFIERS.get(activity, [0.5, 0.5])
	return mods[0]

func _get_stealth_mod(activity: StrategyTypes.ActivityType) -> float:
	var mods = ACTIVITY_MODIFIERS.get(activity, [0.5, 0.5])
	return mods[1]

func _log_contacts(current_turn: int) -> void:
	for key in contacts:
		var c = contacts[key]
		if c.progress > 0.0:
			Log.trace("Contact", "T%d %s → %s: %.1f (%s)" % [
				current_turn,
				c.observer_id,
				c.target_id,
				c.progress,
				StrategyTypes.ContactState.keys()[c.get_state()]
			])

#endregion
