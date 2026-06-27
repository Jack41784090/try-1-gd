class_name ScoutingFocus extends RefCounted

var selected_roles: Array[StrategyTypes.SquadRole] = []
var selected_classes: Array[String] = []


func is_empty() -> bool:
	return selected_roles.is_empty() and selected_classes.is_empty()


func matches(squad: StrategySquad) -> bool:
	if is_empty():
		return false

	for role in selected_roles:
		if squad.squad_role == role:
			return true

	for cls in selected_classes:
		for warrior in squad.get_living_warriors():
			if warrior.identification == cls:
				return true

	return false


func toggle_role(role: StrategyTypes.SquadRole) -> void:
	var idx = selected_roles.find(role)
	if idx >= 0:
		selected_roles.remove_at(idx)
	else:
		selected_roles.append(role)


func toggle_class(cls: String) -> void:
	var idx = selected_classes.find(cls)
	if idx >= 0:
		selected_classes.remove_at(idx)
	else:
		selected_classes.append(cls)


func clear() -> void:
	selected_roles.clear()
	selected_classes.clear()


func set_preset_aggressive() -> void:
	selected_classes.clear()
	selected_classes.append("landsknecht")
	selected_classes.append("crossbowman")
	selected_classes.append("arquebusier")
	selected_classes.append("pikeman")
	selected_classes.append("gelehrter")


func set_preset_support() -> void:
	selected_classes.clear()
	selected_classes.append("healer")
	selected_classes.append("feldprediger")


func get_summary_text() -> String:
	if is_empty():
		return "General Sweep (no focus)"

	var parts: Array[String] = []
	for role in selected_roles:
		parts.append(StrategyTypes.SquadRole.keys()[role])
	for cls in selected_classes:
		parts.append(cls)

	return "Focused on: %s" % ", ".join(parts)
