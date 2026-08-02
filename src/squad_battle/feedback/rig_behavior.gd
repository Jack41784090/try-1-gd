class_name RigBehaviorFeedback
extends FeedbackEffect


func wants(change: EntityChange, _role: int) -> bool:
	return change.property in [
		SquadBattleTypes.EntityChangeable.HP,
		SquadBattleTypes.EntityChangeable.CLINK,
	]


func play(_update: EntityUpdate, role: int) -> void:
	if not _host.rig:
		return
	if role == Role.SOURCE:
		_host.rig.play_behavior(AnimTypes.Behavior.ATTACKING)
	elif role == Role.TARGET:
		_host.rig.play_behavior(AnimTypes.Behavior.DEFENDING)
