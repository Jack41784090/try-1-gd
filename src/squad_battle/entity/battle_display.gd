class_name BattleEntityDisplay
extends Node2D

signal change_received(update: EntityUpdate, role: int)

var squad_entity: CombatEntity
var rig: WarriorRig
var effects: Array[FeedbackEffect] = []


func setup(entity: CombatEntity) -> void:
	squad_entity = entity

	rig = WarriorRigFactory.create_rig_for_entity(entity)
	add_child(rig)
	rig.position = Vector2.ZERO
	rig.play_behavior(AnimTypes.Behavior.IDLE)

	effects = [
		HpBarFeedback.new(),
		OrgIconsFeedback.new(),
		RigBehaviorFeedback.new(),
		AttackLungeFeedback.new(),
		DodgeTextFeedback.new(),
		BlockTextFeedback.new(),
		ProcPopupFeedback.new(),
		DeathFeedback.new(),
		CapitulateFeedback.new(),
		CombatSfxFeedback.new(),
	]
	for fx in effects:
		fx.setup(self)


func _on_update_fired(update: EntityUpdate) -> void:
	if not squad_entity:
		return
	var id := squad_entity.player_id
	if update.source == id:
		change_received.emit(update, FeedbackEffect.Role.SOURCE)
	if update.affected == id:
		change_received.emit(update, FeedbackEffect.Role.TARGET)


func refresh_display() -> void:
	if not squad_entity:
		return
	for fx in effects:
		if fx.has_method("refresh"):
			fx.refresh()


func play_behavior(behavior: AnimTypes.Behavior) -> void:
	if rig:
		rig.play_behavior(behavior)



