class_name NotificationCollector
extends RefCounted

var _notifications: Array[NotificationData] = []


func clear() -> void:
	_notifications.clear()


func get_notifications() -> Array[NotificationData]:
	return _notifications.duplicate()


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


func collect_resource_notifications(squad, turn: int) -> void:
	var food: float = squad.food
	var warrior_count: int = squad.get_living_warriors().size()
	if warrior_count == 0:
		return
	var consumption := _estimate_food_consumption(squad)
	if consumption > 0:
		var turns_remaining := int(food / consumption)
		if turns_remaining <= 2:
			_notifications.append(NotificationData.create(
				NotificationData.NotificationType.LOW_FOOD,
				"Low Food",
				"Food critically low (%d turns remaining)" % turns_remaining,
				turn,
			))


func collect_mission_notifications(completed_missions: Array, turn: int) -> void:
	for result in completed_missions:
		_notifications.append(NotificationData.create(
			NotificationData.NotificationType.MISSION_COMPLETED,
			"Mission Complete",
			result.mission_id.replace("_", " ").capitalize() if result.mission_id else "A mission was completed",
			turn,
		))


func collect_mission_unlocked_notifications(unlocked_names: Array[String], turn: int) -> void:
	for mission_name in unlocked_names:
		_notifications.append(NotificationData.create(
			NotificationData.NotificationType.MISSION_UNLOCKED,
			"New Mission",
			"%s" % mission_name,
			turn,
		))


func _get_squad_name(world, squad_id: String, squad_names: Dictionary = {}) -> String:
	if squad_names.has(squad_id):
		return squad_names[squad_id]
	for sq in world.roaming_squads:
		if sq.squad_id == squad_id:
			return sq.squad_name
	return squad_id


func _estimate_food_consumption(squad) -> float:
	var total := 0.0
	for w in squad.get_living_warriors():
		total += StrategyTypes.get_social_class_food_demand(w.social_class)
	return total
