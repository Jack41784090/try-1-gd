class_name ContactOrchestrator
extends RefCounted


static func snapshot_states(tracker, player_squad_id: String) -> Dictionary:
	var states := {}
	var contacts = tracker.get_contacts_for(player_squad_id)
	for contact in contacts:
		var key := "%s::%s" % [contact.observer_id, contact.target_id]
		states[key] = contact.get_state()
	return states


static func cache_squad_names(roaming_squads) -> Dictionary:
	var names := {}
	for sq in roaming_squads:
		names[sq.squad_id] = sq.squad_name
	return names


func update(
	world, player: SquadData, walking_towards,
	ai_fleet: AIFleetManager, activity: Activity,
	player_location_before: String, pre_states: Dictionary,
	notification_collector, squad_names: Dictionary,
) -> Dictionary:
	var tracker = world.contact_tracker

	var activity_log: Dictionary = {}
	var edge_log: Dictionary = {}

	activity_log[player.squad_id] = activity.activity_type

	var player_location_after = player.current_location_id
	if player_location_before != player_location_after:
		edge_log[player.squad_id] = {"from": player_location_before, "to": player_location_after}
	elif walking_towards and walking_towards is Dictionary and walking_towards.get("location") != null:
		var dest_loc: Location = walking_towards["location"]
		edge_log[player.squad_id] = {"from": player_location_after, "to": dest_loc.location_id}

	ai_fleet.fill_activity_log(activity_log, edge_log)

	var all_squads: Array = [player]
	for sq in world.roaming_squads:
		all_squads.append(sq)

	var focus_map: Dictionary = {}
	if player.scouting_focus and not player.scouting_focus.is_empty():
		focus_map[player.squad_id] = player.scouting_focus

	var before_states: Dictionary = pre_states if not pre_states.is_empty() else snapshot_states(tracker, player.squad_id)
	tracker.update_all_contacts(world, all_squads, activity_log, edge_log, world.current_hour, focus_map)
	var after_states := snapshot_states(tracker, player.squad_id)
	notification_collector.collect_contact_notifications(before_states, after_states, world, player.squad_id, world.current_hour, squad_names)

	var location = world.get_location_by_id(player.current_location_id)
	if location:
		var active_clues = location.get_active_clues(world.current_hour)
		for clue in active_clues:
			for enemy in world.roaming_squads:
				if clue.left_by_squad_id == enemy.squad_id:
					tracker.apply_clue_bonus(clue, enemy, player)

	var player_engagements: Array[Dictionary] = []
	var engagements = tracker.check_engagements(world, all_squads)
	for engagement in engagements:
		var involves_player = engagement["attacker_id"] == player.squad_id or engagement["defender_id"] == player.squad_id
		if involves_player:
			player_engagements.append(engagement)

	return {"engagements": player_engagements, "contact_after": after_states}
