class_name ScoutingPresenter extends Node

var view: ScoutingView
var _world: World
var _player_squad: SquadData

func _ready() -> void:
	view = get_parent() as ScoutingView

func refresh(world: World, player_squad: SquadData) -> void:
	_world = world
	_player_squad = player_squad

	if not player_squad.scouting_focus:
		player_squad.scouting_focus = ScoutingFocus.new()

	view.update_focus_ui(player_squad.scouting_focus, player_squad.get_coordination())

	var tracker = world.contact_tracker
	var our_contacts = tracker.get_contacts_for(player_squad.squad_id)
	var contacts_on_us = tracker.get_contacts_on(player_squad.squad_id)

	_display_warnings(contacts_on_us, world)
	_display_contact_cards(our_contacts, world)

func _display_warnings(contacts_on_us: Array, world: World) -> void:
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

func _display_contact_cards(contacts: Array, world: World) -> void:
	var active: Array[Dictionary] = []
	for contact in contacts:
		if contact.progress <= 0.0:
			continue
		var target_squad = _find_squad(contact.target_id, world)
		if not target_squad:
			continue
		active.append(_build_card_data(contact, target_squad))

	active.sort_custom(func(a, b): return float(a["being_tracked"]) * a["progress"] > float(b["being_tracked"]) * b["progress"])

	if active.is_empty():
		view.show_no_contacts()
	else:
		view.hide_no_contacts()

	view.display_contacts(active)

func _build_card_data(contact, target_squad: SquadData) -> Dictionary:
	var state = contact.get_state()
	var focus = _player_squad.scouting_focus if _player_squad else null
	var focus_mult = 1.0
	if _world and _player_squad and focus:
		focus_mult = _world.contact_tracker.calculate_focus_multiplier(_player_squad, target_squad, focus)
	var data := {
		"state": state,
		"progress": contact.progress,
		"target_id": contact.target_id,
		"being_tracked": contact.being_tracked,
		"is_caravan": target_squad.is_caravan(),
		"focus_multiplier": focus_mult,
	}
	match state:
		StrategyTypes.ContactState.SUSPECTED:
			if target_squad.is_caravan():
				data["title"] = "Trade Caravan"
				data["size_hint"] = _get_size_hint(target_squad)
			else:
				data["title"] = "Unknown Force"
				data["size_hint"] = _get_size_hint(target_squad)
			data["area_hint"] = target_squad.current_location_id
		StrategyTypes.ContactState.TRACKED:
			data["title"] = target_squad.squad_name
			data["warrior_count"] = target_squad.get_living_warriors().size()
			data["location"] = target_squad.current_location_id
			data["morale_hint"] = _get_morale_category(target_squad.get_morale())
			if target_squad.is_caravan():
				data["cargo_hint"] = "Carrying goods"
				data["destination_hint"] = target_squad.cargo_destination_id
		StrategyTypes.ContactState.LOCKED:
			data["title"] = target_squad.squad_name
			data["warrior_count"] = target_squad.get_living_warriors().size()
			data["location"] = target_squad.current_location_id
			data["morale"] = target_squad.get_morale()
			data["warriors"] = _get_warrior_details(target_squad)
			data["stance"] = target_squad.engagement_stance
			if target_squad.is_caravan():
				data["cargo_value"] = target_squad.get_cargo_value()
				data["cargo_destination"] = target_squad.cargo_destination_id
	return data

func _get_size_hint(squad: SquadData) -> String:
	var count = squad.get_living_warriors().size()
	if count <= 2:
		return "Small (1-2 warriors)"
	elif count <= 5:
		return "Medium (3-5 warriors)"
	else:
		return "Large (6+ warriors)"

func _get_morale_category(morale: float) -> String:
	if morale >= 90.0:
		return "Excellent"
	elif morale >= 70.0:
		return "Good"
	elif morale >= 50.0:
		return "Fair"
	elif morale >= 30.0:
		return "Poor"
	else:
		return "Critical"

func _get_warrior_details(squad: SquadData) -> Array[Dictionary]:
	var details: Array[Dictionary] = []
	for warrior in squad.warriors:
		var status := "Healthy"
		if warrior.is_dead:
			status = "Dead"
		elif warrior.is_injured:
			status = "Injured"
		details.append({"name": warrior.name, "status": status})
	return details

func _find_squad(squad_id: String, world: World) -> SquadData:
	for squad in world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad
	return null


func on_role_toggled(role: StrategyTypes.SquadRole) -> void:
	if not _player_squad:
		return
	_player_squad.scouting_focus.toggle_role(role)
	_refresh_after_focus_change()


func on_class_toggled(cls: EntityClasses.Types) -> void:
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
