class_name DodgeTextFeedback
extends FeedbackEffect


func wants(change: EntityChange, role: int) -> bool:
	return role == Role.TARGET and change.property == SquadBattleTypes.EntityChangeable.DODGE


func play(_update: EntityUpdate, _role: int) -> void:
	FeedbackEffect.spawn_floating_text(_host, _host.rig, "DODGE", Color(0.9, 0.9, 0.5), 14)

	var hop := _host.create_tween()
	hop.tween_property(_host, "position:y", _host.position.y - 15.0, 0.1)
	hop.tween_property(_host, "position:y", _host.position.y, 0.1)
