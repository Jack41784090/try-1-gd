class_name ProcPopupFeedback
extends FeedbackEffect


func wants(change: EntityChange, role: int) -> bool:
	return role == Role.SOURCE and change.property == SquadBattleTypes.EntityChangeable.PROC


func play(update: EntityUpdate, _role: int) -> void:
	var skill_name: String = update.change.metadata.get("skill_name", "")
	if skill_name != "":
		FeedbackEffect.spawn_floating_text(_host, _host.rig, skill_name, Color(1.0, 0.75, 0.2), 16)

	if _host.rig:
		var original: Color = _host.rig.modulate
		var glow := _host.create_tween()
		glow.tween_property(_host.rig, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		glow.tween_property(_host.rig, "modulate", original, 0.1)
