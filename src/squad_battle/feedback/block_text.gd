class_name BlockTextFeedback
extends FeedbackEffect


func wants(change: EntityChange, role: int) -> bool:
	return role == Role.TARGET and change.property == SquadBattleTypes.EntityChangeable.CLINK


func play(_update: EntityUpdate, _role: int) -> void:
	FeedbackEffect.spawn_floating_text(_host, _host.rig, "BLOCK", Color(0.6, 0.8, 1.0), 14)

	if _host.rig:
		_host.rig.modulate = Color.WHITE * 1.5
		var flash := _host.create_tween()
		flash.tween_property(_host.rig, "modulate", Color.WHITE, 0.15)
