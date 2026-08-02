class_name DeathFeedback
extends FeedbackEffect

const DURATION: float = 0.5


func wants(change: EntityChange, role: int) -> bool:
	return role == Role.TARGET and change.property == SquadBattleTypes.EntityChangeable.DIE


func play(_update: EntityUpdate, _role: int) -> void:
	if _host.rig:
		_host.rig.play_behavior(AnimTypes.Behavior.DYING)

	var tween := _host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(_host, "modulate:a", 0.0, DURATION)
	tween.tween_property(_host, "scale", Vector2(0.5, 0.5), DURATION)
