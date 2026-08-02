class_name ScoutingPresenter extends Node

var view: ScoutingView
var _world: World
var _player_squad: StrategySquad
var _ai_decisions: Dictionary = {}

func _ready() -> void:
	view = get_parent() as ScoutingView

func refresh(world: World, player_squad: StrategySquad, ai_decisions: Dictionary = {}) -> void:
	_world = world
	_player_squad = player_squad
	_ai_decisions = ai_decisions

	if not player_squad.scouting_focus:
		player_squad.scouting_focus = ScoutingFocus.new()

	view.update_focus_ui(player_squad.scouting_focus, player_squad.get_coordination())

	var tracker = world.contact_tracker
	var our_contacts = tracker.get_contacts_for(player_squad.squad_id)
	var contacts_on_us = tracker.get_contacts_on(player_squad.squad_id)

	var warnings: Array[String] = []
	for contact in contacts_on_us:
		if contact.progress <= 0.0:
			continue
		var state = contact.get_state()
		match state:
			StrategyTypes.ContactState.SUSPECTED:
				warnings.append("An unknown force is watching you")
			StrategyTypes.ContactState.TRACKED, StrategyTypes.ContactState.LOCKED:
				var squad = _find_squad(contact.observer_id, world)
				var squad_name = squad.squad_name if squad else "Unknown"
				warnings.append("%s is tracking you (%.0f%%)" % [squad_name, contact.progress])
	view.display_warnings(warnings)
	_display_contact_cards(our_contacts, world)

func _display_contact_cards(contacts: Array[Contact], world: World) -> void:
	var active: Array[Dictionary] = []
	for contact in contacts:
		if contact.progress <= 0.0:
			continue
		var target_squad = _find_squad(contact.target_id, world)
		if not target_squad:
			continue
		var card_state = contact.get_state()
		var focus = _player_squad.scouting_focus if _player_squad else null
		var focus_mult = 1.0
		if _world and _player_squad and focus:
			focus_mult = _world.contact_tracker.calculate_focus_multiplier(_player_squad, target_squad, focus)
		var card_data := {
			"state": card_state,
			"progress": contact.progress,
			"progress_delta": contact.last_delta,
			"target_id": contact.target_id,
			"being_tracked": contact.being_tracked,
			"is_caravan": target_squad.is_caravan(),
			"focus_multiplier": focus_mult,
		}
		match card_state:
			StrategyTypes.ContactState.SUSPECTED:
				if target_squad.is_caravan():
					card_data["title"] = target_squad.squad_name
					card_data["size_hint"] = _get_size_hint(target_squad)
				else:
					card_data["title"] = "Unknown Force"
					card_data["size_hint"] = _get_size_hint(target_squad)
				card_data["area_hint"] = target_squad.current_location_id
			StrategyTypes.ContactState.TRACKED:
				card_data["title"] = target_squad.squad_name
				card_data["warrior_count"] = target_squad.get_living_warriors().size()
				card_data["location"] = target_squad.current_location_id
				var morale_val: float = target_squad.get_morale()
				if morale_val >= 90.0:
					card_data["morale_hint"] = "Excellent"
				elif morale_val >= 70.0:
					card_data["morale_hint"] = "Good"
				elif morale_val >= 50.0:
					card_data["morale_hint"] = "Fair"
				elif morale_val >= 30.0:
					card_data["morale_hint"] = "Poor"
				else:
					card_data["morale_hint"] = "Critical"
				if target_squad.is_caravan():
					card_data["cargo_hint"] = "Carrying goods"
					card_data["destination_hint"] = target_squad.cargo.destination_id
				var tracked_dest = _get_destination_intel(contact, target_squad)
				if not tracked_dest.is_empty():
					card_data["destination_intel"] = tracked_dest
			StrategyTypes.ContactState.LOCKED:
				card_data["title"] = target_squad.squad_name
				card_data["warrior_count"] = target_squad.get_living_warriors().size()
				card_data["location"] = target_squad.current_location_id
				card_data["morale"] = target_squad.get_morale()
				var warrior_details: Array[Dictionary] = []
				for warrior in target_squad.warriors:
					var status := "Healthy"
					if warrior.is_dead:
						status = "Dead"
					elif warrior.is_injured:
						status = "Injured"
					warrior_details.append({"name": warrior.display_name, "status": status})
				card_data["warriors"] = warrior_details
				card_data["stance"] = target_squad.engagement_stance
				if target_squad.is_caravan():
					card_data["cargo_value"] = target_squad.get_cargo_value()
					card_data["cargo_destination"] = target_squad.cargo.destination_id
				var locked_dest = _get_destination_intel(contact, target_squad)
				if not locked_dest.is_empty():
					card_data["destination_intel"] = locked_dest
		active.append(card_data)

	active.sort_custom(func(a, b): return float(a["being_tracked"]) * a["progress"] > float(b["being_tracked"]) * b["progress"])

	if active.is_empty():
		view.show_no_contacts()
	else:
		view.hide_no_contacts()

	view.display_contacts(active)

func _get_size_hint(squad: StrategySquad) -> String:
	var count = squad.get_living_warriors().size()
	if count <= 2:
		return "Small (1-2 warriors)"
	elif count <= 5:
		return "Medium (3-5 warriors)"
	else:
		return "Large (6+ warriors)"

func _find_squad(squad_id: String, world: World) -> StrategySquad:
	for squad in world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad
	return null


func _get_destination_intel(contact, target_squad: StrategySquad) -> Dictionary:
	var actual_dest := ""
	if target_squad.is_caravan() and not target_squad.cargo.destination_id.is_empty():
		actual_dest = target_squad.cargo.destination_id
	elif _ai_decisions.has(target_squad.squad_id):
		var decision: Dictionary = _ai_decisions[target_squad.squad_id]
		var at = decision.get("activity_type", -1)
		if at == StrategyTypes.ActivityType.TRAVEL or at == StrategyTypes.ActivityType.FORCE_MARCH:
			var ctx: Dictionary = decision.get("context", {})
			var ultimate := ctx.get("ultimate_destination", "") as String
			if not ultimate.is_empty():
				actual_dest = ultimate
			else:
				var next_hop := ctx.get("travel_destination", "") as String
				if not next_hop.is_empty():
					actual_dest = next_hop
	if actual_dest.is_empty():
		return {}

	var progress: float = contact.progress
	var is_locked := progress >= 100.0

	var displayed_dest := actual_dest
	if not is_locked and progress < 60.0:
		var wrong_chance := clampf((1.0 - (progress - 30.0) / 30.0) * 0.8, 0.0, 0.8)
		var seed_val := hash(contact.observer_id + contact.target_id + str(_world.current_hour))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		if rng.randf() < wrong_chance:
			if not _world or not _world.travel_graph:
				displayed_dest = actual_dest
			else:
				var wrong_loc := _world.travel_graph.get_location(target_squad.current_location_id)
				if not wrong_loc or not wrong_loc.connections:
					displayed_dest = actual_dest
				else:
					var candidates: Array[String] = []
					for conn in wrong_loc.connections.tt:
						if conn.to_location_id != actual_dest:
							candidates.append(conn.to_location_id)
					if candidates.is_empty():
						displayed_dest = actual_dest
					else:
						displayed_dest = candidates[hash(target_squad.current_location_id + actual_dest) % candidates.size()]

	var result := {"destination": displayed_dest}

	if is_locked and _world and _world.travel_graph:
		var distance_km := _world.travel_graph.calculate_distance_km_between(
			target_squad.current_location_id, actual_dest)
		if distance_km >= 0:
			var speed := target_squad.get_speed_kmh()
			result["estimated_hours"] = ceili(distance_km / maxf(speed, 0.1))

	var loc := _world.get_location_by_id(displayed_dest) if _world else null
	result["destination_name"] = loc.location_name if loc else displayed_dest

	return result


func on_role_toggled(role: StrategyTypes.SquadRole) -> void:
	if not _player_squad:
		return
	_player_squad.scouting_focus.toggle_role(role)
	_refresh_after_focus_change()


func on_class_toggled(cls: String) -> void:
	if not _player_squad:
		return
	_player_squad.scouting_focus.toggle_class(cls)
	_refresh_after_focus_change()


func on_preset_aggressive() -> void:
	if not _player_squad:
		return
	_player_squad.scouting_focus.set_preset_aggressive()
	_refresh_after_focus_change()


func on_preset_support() -> void:
	if not _player_squad:
		return
	_player_squad.scouting_focus.set_preset_support()
	_refresh_after_focus_change()


func on_clear_focus() -> void:
	if not _player_squad:
		return
	_player_squad.scouting_focus.clear()
	_refresh_after_focus_change()


func _refresh_after_focus_change() -> void:
	if not _world or not _player_squad:
		return
	view.update_focus_ui(_player_squad.scouting_focus, _player_squad.get_coordination())
	var tracker = _world.contact_tracker
	var our_contacts = tracker.get_contacts_for(_player_squad.squad_id)
	_display_contact_cards(our_contacts, _world)
