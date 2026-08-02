class_name CapitulateFeedback
extends FeedbackEffect


func wants(change: EntityChange, role: int) -> bool:
	return role == Role.TARGET and change.property == SquadBattleTypes.EntityChangeable.CAPITULATE


func play(_update: EntityUpdate, _role: int) -> void:
	_host.modulate = Color(0.5, 0.5, 0.5, 0.5)
