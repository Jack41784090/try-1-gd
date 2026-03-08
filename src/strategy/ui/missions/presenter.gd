class_name MissionsPresenter
extends Node

signal missions_closed

var view: MissionsView
var all_missions: Array[Mission] = []
var selected_mission: Mission = null


func bind_view(v: MissionsView) -> void:
	view = v
	view.closed.connect(_on_closed)
	view.mission_selected.connect(_on_mission_selected)


func open(p_missions: Array[Mission]) -> void:
	all_missions = p_missions
	selected_mission = null
	var active = _get_active_missions()
	var completed = _get_completed_missions()
	view.display_mission_list(active, completed)
	view.show_missions()

	if not active.is_empty():
		_on_mission_selected(active[0])
		view.select_mission_at(0)
	else:
		view.clear_details()


func _on_mission_selected(mission: Mission) -> void:
	selected_mission = mission
	view.display_mission_details(mission)


func _on_closed() -> void:
	missions_closed.emit()


func _get_active_missions() -> Array[Mission]:
	var active: Array[Mission] = []
	for mission in all_missions:
		if mission.is_unlocked and not mission.is_completed and not mission.is_failed:
			active.append(mission)
	return active


func _get_completed_missions() -> Array[Mission]:
	var completed: Array[Mission] = []
	for mission in all_missions:
		if mission.is_completed:
			completed.append(mission)
	return completed
