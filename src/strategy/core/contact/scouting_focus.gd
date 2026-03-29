class_name ScoutingFocus extends RefCounted

var selected_roles: Array[StrategyTypes.SquadRole] = []
var selected_classes: Array[EntityClasses.Types] = []


func is_empty() -> bool:
	return selected_roles.is_empty() and selected_classes.is_empty()


func matches(squad: SquadData) -> bool:
	if is_empty():
		return false

	for role in selected_roles:
		if squad.squad_role == role:
			return true

	for cls in selected_classes:
		for warrior in squad.get_living_warriors():
			if warrior.class_id == cls:
				return true

	return false


func toggle_role(role: StrategyTypes.SquadRole) -> void:
	var idx = selected_roles.find(role)
	if idx >= 0:
		selected_roles.remove_at(idx)
	else:
		selected_roles.append(role)


func toggle_class(cls: EntityClasses.Types) -> void:
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
	selected_classes.append(EntityClasses.Types.Landsknecht)
	selected_classes.append(EntityClasses.Types.Crossbowman)
	selected_classes.append(EntityClasses.Types.Arquebusier)
	selected_classes.append(EntityClasses.Types.Pikeman)
	selected_classes.append(EntityClasses.Types.Gelehrter)


func set_preset_support() -> void:
	selected_classes.clear()
	selected_classes.append(EntityClasses.Types.Healer)
	selected_classes.append(EntityClasses.Types.Feldprediger)


func get_summary_text() -> String:
	if is_empty():
		return "General Sweep (no focus)"

	var parts: Array[String] = []
	for role in selected_roles:
		parts.append(StrategyTypes.SquadRole.keys()[role])
	for cls in selected_classes:
		parts.append(EntityClasses.Types.keys()[cls])

	return "Focused on: %s" % ", ".join(parts)
