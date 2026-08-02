class_name NotificationData
extends RefCounted

enum NotificationType {
	CONTACT_DETECTED,
	CONTACT_LOST,
	CONTACT_DECAYING,
	LOW_FOOD,
	MISSION_UNLOCKED,
	MISSION_COMPLETED,
}

var id: String
var type: NotificationType
var title: String
var description: String
var action: Callable
var action_label: String
var turn_created: int


static func create(p_type: NotificationType, p_title: String, p_desc: String, p_turn: int) -> NotificationData:
	var n := NotificationData.new()
	n.id = "%d_%s_%d" % [p_turn, NotificationType.keys()[p_type], randi()]
	n.type = p_type
	n.title = p_title
	n.description = p_desc
	n.turn_created = p_turn
	return n


static func create_with_action(p_type: NotificationType, p_title: String, p_desc: String, p_turn: int, p_action: Callable, p_action_label: String) -> NotificationData:
	var n := create(p_type, p_title, p_desc, p_turn)
	n.action = p_action
	n.action_label = p_action_label
	return n
