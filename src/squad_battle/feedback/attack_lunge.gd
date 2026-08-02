class_name AttackLungeFeedback
extends FeedbackEffect

const LUNGE_DISTANCE: float = 40.0
const DURATION: float = 0.3


func wants(change: EntityChange, role: int) -> bool:
	return role == Role.SOURCE and change.property in [
		SquadBattleTypes.EntityChangeable.HP,
		SquadBattleTypes.EntityChangeable.CLINK,
	]


func play(_update: EntityUpdate, _role: int) -> void:
	if not is_instance_valid(_host):
		return

	var parent := _host.get_parent()
	var attack_dir := Vector2(1, 0)
	if parent:
		var grandparent := parent.get_parent()
		if not (grandparent and grandparent.name == "AttackerSide"):
			attack_dir = Vector2(-1, 0)

	var lunge_pos := _host.position + attack_dir.normalized() * LUNGE_DISTANCE
	var tween := _host.create_tween()
	tween.tween_property(_host, "position", lunge_pos, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
