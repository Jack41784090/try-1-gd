class_name NotificationCollector
extends RefCounted

var _notifications: Array[NotificationData] = []


func collect_contact_notifications(before_states: Dictionary, after_states: Dictionary, world, player_squad_id: String, turn: int, squad_names: Dictionary = {}) -> void:
	for key in after_states:
		var after_state: int = after_states[key]
		var before_state: int = before_states.get(key, StrategyTypes.ContactState.NONE)

		var parts: PackedStringArray = key.split("::")
		if parts.size() != 2:
			continue
		var observer_id: String = parts[0]
		var target_id: String = parts[1]

		if observer_id != player_squad_id:
			continue

		var target_name := _get_squad_name(world, target_id, squad_names)

		if before_state == StrategyTypes.ContactState.NONE and after_state >= StrategyTypes.ContactState.SUSPECTED:
			_notifications.append(NotificationData.create(
				NotificationData.NotificationType.CONTACT_DETECTED,
				"Contact Detected",
				"%s spotted nearby" % target_name,
				turn,
			))

		elif before_state > after_state and after_state > StrategyTypes.ContactState.NONE:
			_notifications.append(NotificationData.create(
				NotificationData.NotificationType.CONTACT_DECAYING,
				"Contact Stalling",
				"%s may have moved — contact fading" % target_name,
				turn,
			))

	for key in before_states:
		if key not in after_states or after_states[key] == StrategyTypes.ContactState.NONE:
			var before_state: int = before_states[key]
			if before_state <= StrategyTypes.ContactState.NONE:
				continue
			var parts: PackedStringArray = key.split("::")
			if parts.size() != 2:
				continue
			var observer_id: String = parts[0]
			if observer_id != player_squad_id:
				continue
			var target_id: String = parts[1]
			var target_name := _get_squad_name(world, target_id, squad_names)
			_notifications.append(NotificationData.create(
				NotificationData.NotificationType.CONTACT_LOST,
				"Contact Lost",
				"Lost track of %s" % target_name,
				turn,
			))


func _get_squad_name(world, squad_id: String, squad_names: Dictionary = {}) -> String:
	if squad_names.has(squad_id):
		return squad_names[squad_id]
	for sq in world.roaming_squads:
		if sq.squad_id == squad_id:
			return sq.squad_name
	return squad_id
